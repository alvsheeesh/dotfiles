# Configuración compartida por zsh y bash. Se carga desde ~/.zshrc o ~/.bashrc.
# Todo va protegido con `command -v` para que no rompa en máquinas sin alguna herramienta.

[ -n "$__DOTFILES_LOADED" ] && return
__DOTFILES_LOADED=1

export DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
if [ -n "$ZSH_VERSION" ]; then __sh=zsh; else __sh=bash; fi

# ───────── PATH ─────────
[ -d /snap/bin ] && PATH="$PATH:/snap/bin"
[ -d "$HOME/.fzf/bin" ] && PATH="$HOME/.fzf/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
export PATH

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# ───────── Prompt, saltos inteligentes y búsqueda difusa ─────────
# (Ctrl+R historial, Ctrl+T archivos)
command -v starship >/dev/null && eval "$(starship init $__sh)"
command -v zoxide >/dev/null && eval "$(zoxide init $__sh --cmd cd)"
if command -v fzf >/dev/null; then
  eval "$(fzf --$__sh 2>/dev/null)"
  export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border=rounded \
  --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,prompt:#cba6f7,hl+:#f38ba8"
fi

# ───────── Alias con colores e iconos ─────────
if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --git --group-directories-first'
  alias la='eza -lah --icons --git --group-directories-first'
  alias tree='eza --tree --icons'
fi
command -v bat >/dev/null || { command -v batcat >/dev/null && alias bat='batcat'; }
if command -v bat >/dev/null || command -v batcat >/dev/null; then
  alias cat='bat --paging=never'
  export BAT_THEME="ansi"
fi
command -v btop >/dev/null && alias top='btop'

# Animaciones
command -v tte >/dev/null && command -v fastfetch >/dev/null && alias matrix='fastfetch --pipe -l none | tte matrix'
command -v pipes.sh >/dev/null && alias pipes='pipes.sh -t 1 -R -r 4000'

# Actualiza la configuración desde GitHub y recarga la shell
dotfiles-update() {
  git -C "$DOTFILES" pull --ff-only && exec "$__sh"
}

# Ajustes propios de esta máquina (no se suben al repo)
[ -f "$HOME/.shellrc.local" ] && . "$HOME/.shellrc.local"

# ───────── Saludo animado (FUN_GREETING=0 en ~/.shellrc.local lo desactiva) ─────────
case $- in *i*)
  if [ "${FUN_GREETING:-1}" = 1 ] && [ -z "$CLAUDECODE" ]; then
    __hello="  Hola, ${USER:-$(id -un)}  ·  $(date '+%A %d %B, %H:%M')"
    if command -v tte >/dev/null; then
      echo "$__hello" | tte --frame-rate 120 beams --final-gradient-stops cba6f7 89b4fa 94e2d5
    else
      echo "$__hello"
    fi
    if command -v fastfetch >/dev/null; then
      if command -v pokeget >/dev/null; then bash "$DOTFILES/shell/pokefetch.sh"; else fastfetch; fi
    fi
    unset __hello
  fi
;; esac
