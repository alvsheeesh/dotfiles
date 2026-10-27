#!/usr/bin/env bash
# Instala la estética de terminal (zsh + oh-my-zsh + starship Catppuccin + eza/bat/fzf/zoxide…)
# en cualquier Linux, sin necesidad de sudo. Todo va a ~/.local/bin y ~/.dotfiles.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/alvsheeesh/dotfiles/main/install.sh)"
#
# Opciones:
#   --bash         usar bash aunque haya zsh (no toca la shell por defecto)
#   --minimal      no instalar los extras de animación (uv + tte, pipes.sh, btop)
#   --no-greeting  desactivar el saludo animado en esta máquina
#   --no-claude    no tocar Claude Code (tema y mods de la toolbox)
#   --yes          no preguntar nada (útil sin terminal)
#
# Volver a ejecutarlo es seguro: solo instala lo que falte.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/alvsheeesh/dotfiles.git}"
BIN="$HOME/.local/bin"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

CLAUDE_TOOLBOX_REPO="${CLAUDE_TOOLBOX_REPO:-alvsheeesh/claude-toolbox}"

USE_BASH=0 MINIMAL=0 NO_GREETING=0 NO_CLAUDE=0 ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --bash) USE_BASH=1 ;;
    --minimal) MINIMAL=1 ;;
    --no-greeting) NO_GREETING=1 ;;
    --no-claude) NO_CLAUDE=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,15p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "Opción desconocida: $arg" >&2; exit 1 ;;
  esac
done

# ───────── utilidades ─────────
c_mauve=$'\e[38;2;203;166;247m' c_green=$'\e[38;2;166;227;161m' c_yellow=$'\e[38;2;249;226;175m' c_red=$'\e[38;2;243;139;168m' c_off=$'\e[0m'
step() { printf '\n%s==>%s %s\n' "$c_mauve" "$c_off" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$c_green" "$c_off" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '%s✗ %s%s\n' "$c_red" "$*" "$c_off" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }
short() { echo "${1/#"$HOME"/"~"}"; }

ask() {  # ask "¿pregunta?"  → 0 si responde que sí
  [ "$ASSUME_YES" = 1 ] && return 1
  [ -r /dev/tty ] || return 1
  local r; printf '  %s?%s %s [s/N] ' "$c_yellow" "$c_off" "$1"; read -r r </dev/tty || return 1
  case "$r" in [sSyY]*) return 0 ;; *) return 1 ;; esac
}

fetch() {  # fetch URL DESTINO
  if has curl; then curl -fsSL --retry 2 -o "$2" "$1"
  elif has wget; then wget -q -O "$2" "$1"
  else die "Hace falta curl o wget"; fi
}

latest_tag() {  # latest_tag owner/repo → etiqueta de la última versión (sin usar la API)
  local url="https://github.com/$1/releases/latest" loc
  if has curl; then loc=$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$url")
  else loc=$(wget -q -S --spider "$url" 2>&1 | sed -n 's/^ *[Ll]ocation: *//p' | tail -1); fi
  loc="${loc%$'\r'}"; echo "${loc##*/}"
}

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

install_bin() {  # install_bin NOMBRE URL  → descarga el .tar.gz y copia el binario NOMBRE a ~/.local/bin
  local name="$1" url="$2" d="$TMP/$1" f
  mkdir -p "$d"
  if ! fetch "$url" "$d/pkg.tgz" 2>/dev/null; then warn "$name: no se pudo descargar"; return 0; fi
  tar -xzf "$d/pkg.tgz" -C "$d" || { warn "$name: archivo dañado"; return 0; }
  f=$(find "$d" -type f -name "$name" | head -1)
  [ -n "$f" ] || { warn "$name: binario no encontrado en el paquete"; return 0; }
  install -m 755 "$f" "$BIN/$name" && ok "$name $("$BIN/$name" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
}

get_repo() {  # get_repo owner/repo DESTINO → clona (o descarga el zip si no hay git)
  [ -d "$2" ] && return 0
  if has git; then git clone -q --depth 1 "https://github.com/$1.git" "$2"
  else
    mkdir -p "$2"; fetch "https://github.com/$1/archive/HEAD.tar.gz" "$TMP/repo.tgz"
    tar -xzf "$TMP/repo.tgz" -C "$2" --strip-components=1
  fi
}

link() {  # link ORIGEN DESTINO → enlace simbólico, guardando copia de lo que hubiera
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then ok "$(short "$dst") ya enlazado"; return; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/"; warn "copia de $(short "$dst") en $(short "$BACKUP")"; fi
  mkdir -p "$(dirname "$dst")"; ln -s "$src" "$dst"; ok "$(short "$dst") → $(short "$src")"
}

set_block() {  # set_block FICHERO CONTENIDO → escribe/reemplaza el bloque marcado de dotfiles
  local file="$1" body="$2"
  touch "$file"
  if grep -q '^# >>> dotfiles >>>' "$file"; then
    awk '/^# >>> dotfiles >>>/{skip=1} !skip{print} /^# <<< dotfiles <<</{skip=0}' "$file" > "$TMP/blk" && cat "$TMP/blk" > "$file"
  fi
  printf '\n# >>> dotfiles >>>\n%s\n# <<< dotfiles <<<\n' "$body" >> "$file"
}

# ───────── 1. sistema ─────────
step "Comprobando el sistema"
case "$(uname -m)" in
  x86_64|amd64)  ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  *) ARCH=""; warn "arquitectura $(uname -m) sin binarios precompilados: solo se instalará la configuración" ;;
esac
[ "$(uname -s)" = Linux ] || die "Este instalador es para Linux"
has tar || die "Hace falta tar"
mkdir -p "$BIN"; export PATH="$BIN:$PATH"
ok "Linux $ARCH${ARCH:+ · }usuario $(id -un)"

# ───────── 2. el repo ─────────
step "Descargando la configuración"
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$here" ] && [ -f "$here/shell/common.sh" ]; then
  DOTFILES="$here"; ok "usando $DOTFILES"
elif [ -d "$DOTFILES/.git" ] && has git; then
  git -C "$DOTFILES" pull -q --ff-only && ok "actualizado $DOTFILES"
elif [ -f "$DOTFILES/shell/common.sh" ]; then
  ok "usando $DOTFILES"
else
  if has git; then git clone -q --depth 1 "$DOTFILES_REPO" "$DOTFILES"
  else
    mkdir -p "$DOTFILES"; fetch "${DOTFILES_REPO%.git}/archive/HEAD.tar.gz" "$TMP/dot.tgz"
    tar -xzf "$TMP/dot.tgz" -C "$DOTFILES" --strip-components=1
    warn "sin git: no funcionará dotfiles-update (vuelve a ejecutar el instalador para actualizar)"
  fi
  ok "descargado en $DOTFILES"
fi

# ───────── 3. herramientas ─────────
step "Instalando herramientas en ~/.local/bin"
if [ -n "$ARCH" ]; then
  [ $ARCH = x86_64 ] && GOARCH=amd64 || GOARCH=arm64
  [ $ARCH = x86_64 ] && EZA_T=x86_64-unknown-linux-musl || EZA_T=aarch64-unknown-linux-gnu

  need() { if has "$1"; then ok "$1 ya instalado"; return 1; fi; }

  need starship && install_bin starship "https://github.com/starship/starship/releases/latest/download/starship-$ARCH-unknown-linux-musl.tar.gz"
  need eza      && install_bin eza "https://github.com/eza-community/eza/releases/latest/download/eza_$EZA_T.tar.gz"
  if has bat || has batcat; then ok "bat ya instalado"; else
    t=$(latest_tag sharkdp/bat); install_bin bat "https://github.com/sharkdp/bat/releases/download/$t/bat-$t-$ARCH-unknown-linux-musl.tar.gz"; fi
  need zoxide   && { t=$(latest_tag ajeetdsouza/zoxide); install_bin zoxide "https://github.com/ajeetdsouza/zoxide/releases/download/$t/zoxide-${t#v}-$ARCH-unknown-linux-musl.tar.gz"; }
  if has fzf && fzf --zsh >/dev/null 2>&1; then ok "fzf ya instalado"; else  # las versiones viejas no traen --zsh
    t=$(latest_tag junegunn/fzf); install_bin fzf "https://github.com/junegunn/fzf/releases/download/$t/fzf-${t#v}-linux_$GOARCH.tar.gz"; fi
  need fastfetch && install_bin fastfetch "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$GOARCH-polyfilled.tar.gz"
  need pokeget  && install_bin pokeget "https://github.com/talwat/pokeget-rs/releases/latest/download/pokeget-Linux-$ARCH.tar.gz"

  if [ "$MINIMAL" = 0 ]; then
    need btop && install_bin btop "https://github.com/aristocratos/btop/releases/latest/download/btop-$ARCH-unknown-linux-musl.tar.gz"
    if need pipes.sh; then fetch https://raw.githubusercontent.com/pipeseroni/pipes.sh/master/pipes.sh "$BIN/pipes.sh" && chmod +x "$BIN/pipes.sh" && ok "pipes.sh"; fi
    if need tte; then
      has uv || { fetch https://astral.sh/uv/install.sh "$TMP/uv.sh" && env UV_NO_MODIFY_PATH=1 sh "$TMP/uv.sh" >/dev/null 2>&1 || warn "uv: no se pudo instalar"; }
      if has uv; then uv tool install -q terminaltexteffects >/dev/null 2>&1 && ok "tte (animaciones)" || warn "tte: no se pudo instalar"; fi
    fi
  fi
fi

# ───────── 4. shell ─────────
step "Configurando la shell"
SHELL_KIND=bash
if [ "$USE_BASH" = 0 ]; then
  if ! has zsh; then
    pm=""; for p in apt-get dnf pacman apk zypper; do has $p && { pm=$p; break; }; done
    sudo=""; [ "$(id -u)" = 0 ] || sudo=sudo
    if [ -n "$pm" ] && { [ -z "$sudo" ] || has sudo; } && ask "zsh no está instalado. ¿Instalarlo con $pm (pedirá contraseña)?"; then
      case $pm in
        apt-get) $sudo apt-get update -qq && $sudo apt-get install -y -qq zsh ;;
        dnf)     $sudo dnf install -y -q zsh ;;
        pacman)  $sudo pacman -S --noconfirm --needed zsh ;;
        apk)     $sudo apk add -q zsh ;;
        zypper)  $sudo zypper -q install -y zsh ;;
      esac || warn "no se pudo instalar zsh"
    fi
  fi
  has zsh && SHELL_KIND=zsh || warn "sin zsh: se usará bash con el mismo prompt y alias"
fi

if [ "$SHELL_KIND" = zsh ]; then
  get_repo ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh" && ok "oh-my-zsh"
  plug="$HOME/.oh-my-zsh/custom/plugins"
  get_repo zsh-users/zsh-autosuggestions "$plug/zsh-autosuggestions" && ok "zsh-autosuggestions"
  get_repo zdharma-continuum/fast-syntax-highlighting "$plug/fast-syntax-highlighting" && ok "fast-syntax-highlighting"
  get_repo zsh-users/zsh-completions "$plug/zsh-completions" && ok "zsh-completions"
fi

# ───────── 5. enlaces ─────────
step "Enlazando la configuración"
mkdir -p "$HOME/.config"
link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
[ "$SHELL_KIND" = zsh ] && link "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"

if [ "$NO_GREETING" = 1 ] && ! grep -qs '^FUN_GREETING=' "$HOME/.shellrc.local"; then
  echo 'FUN_GREETING=0' >> "$HOME/.shellrc.local"; ok "saludo desactivado en ~/.shellrc.local"
fi

# ───────── 6. shell por defecto ─────────
step "Shell por defecto"
login_shell=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7); login_shell="${login_shell:-${SHELL:-}}"
hook=""
if [ "$SHELL_KIND" = zsh ]; then
  if [ "$(basename "$login_shell")" = zsh ]; then ok "zsh ya es tu shell"
  elif has chsh && ask "¿Poner zsh como shell por defecto (chsh, pedirá contraseña)?" && chsh -s "$(command -v zsh)" </dev/tty; then
    ok "zsh será tu shell en el próximo inicio de sesión"
  else
    # sin chsh (p. ej. NAS): las sesiones interactivas saltan a zsh desde bash/sh
    hook='case $- in *i*) [ -t 0 ] && [ -z "$ZSH_VERSION$BASH_EXECUTION_STRING$DOTFILES_NO_EXEC" ] && command -v zsh >/dev/null 2>&1 && exec zsh -l ;; esac'
    ok "las sesiones interactivas abrirán zsh automáticamente (DOTFILES_NO_EXEC=1 lo evita)"
  fi
else
  hook='case $- in *i*) [ -n "$BASH_VERSION" ] && [ -f "$HOME/.dotfiles/shell/common.sh" ] && . "$HOME/.dotfiles/shell/common.sh" ;; esac'
  [ "$DOTFILES" = "$HOME/.dotfiles" ] || hook="${hook//\$HOME\/.dotfiles/$DOTFILES}"
  ok "bash cargará la configuración"
fi
if [ -n "$hook" ]; then
  # .bashrc para bash interactivo; .profile para sesiones SSH de login (sh/ash/bash)
  set_block "$HOME/.bashrc" "$hook"
  set_block "$HOME/.profile" "$hook"
fi

# ───────── 7. Claude Code ─────────
if [ "$NO_CLAUDE" = 0 ] && has claude; then
  step "Claude Code: tema y mods"
  if claude plugin marketplace list 2>/dev/null | grep -q claude-toolbox; then
    claude plugin marketplace update claude-toolbox >/dev/null 2>&1 || true
  else
    claude plugin marketplace add "$CLAUDE_TOOLBOX_REPO" >/dev/null 2>&1 || warn "no se pudo añadir la toolbox ($CLAUDE_TOOLBOX_REPO)"
  fi
  for p in $(grep -oE '"[a-z0-9-]+@claude-toolbox"' "$DOTFILES/claude/settings.json" | tr -d '"'); do
    if claude plugin list 2>/dev/null | grep -q "$p"; then ok "${p%@*} ya instalado"
    elif claude plugin install "$p" >/dev/null 2>&1; then ok "${p%@*}"
    else warn "${p%@*}: no se pudo instalar"; fi
  done

  # Solo se mezclan las claves del repo (tema y mods activos); el resto de ajustes de la máquina se respeta
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; mkdir -p "$(dirname "$cfg")"
  if [ ! -s "$cfg" ]; then cp "$DOTFILES/claude/settings.json" "$cfg"; ok "ajustes copiados"
  elif has python3; then
    python3 -I - "$cfg" "$DOTFILES/claude/settings.json" <<'PY' && ok "tema y mods aplicados"
import json, sys
dst, src = sys.argv[1], sys.argv[2]
cur, new = json.load(open(dst)), json.load(open(src))
for k, v in new.items():
    cur[k] = {**cur.get(k, {}), **v} if isinstance(v, dict) and isinstance(cur.get(k), dict) else v
json.dump(cur, open(dst, "w"), indent=2, ensure_ascii=False)
PY
  elif has jq; then
    jq -s '.[0] * .[1]' "$cfg" "$DOTFILES/claude/settings.json" > "$TMP/cc.json" && cat "$TMP/cc.json" > "$cfg" && ok "tema y mods aplicados"
  else warn "sin python3 ni jq: copia a mano lo de $DOTFILES/claude/settings.json en $cfg"; fi
fi

printf '\n%s✨ Listo.%s Abre una sesión nueva (o ejecuta %sexec %s%s) para verlo.\n' "$c_green" "$c_off" "$c_mauve" "$SHELL_KIND" "$c_off"
printf '   Los iconos necesitan una Nerd Font en la terminal desde la que te conectas (p. ej. JetBrainsMono Nerd Font).\n'
