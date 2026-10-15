# dotfiles

Mi terminal: **zsh + oh-my-zsh**, prompt **starship** (Catppuccin Powerline), y herramientas con colores e iconos
(eza, bat, fzf, zoxide, btop, fastfetch) con un saludo animado al abrir la sesión.

## Instalar en cualquier Linux (una línea)

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/__GH_USER__/dotfiles/main/install.sh)"
```

Sin `curl`: `bash -c "$(wget -qO- https://raw.githubusercontent.com/__GH_USER__/dotfiles/main/install.sh)"`

- **No necesita sudo**: los programas van a `~/.local/bin` y la configuración se enlaza desde `~/.dotfiles`.
- Si ya existía un `~/.zshrc` o `~/.config/starship.toml`, se guarda una copia en `~/.dotfiles-backup/`.
- Si no hay zsh, ofrece instalarlo; si no se puede, usa **bash** con el mismo prompt y alias.
- Si no se puede cambiar la shell por defecto (típico en un NAS), las sesiones SSH interactivas saltan a zsh solas
  (`DOTFILES_NO_EXEC=1 ssh …` lo evita; `scp`/`rsync` no se ven afectados).
- Funciona en x86_64 y aarch64. Volver a ejecutarlo es seguro.

Opciones (van al final: `bash -c "$(curl …)" -- --minimal`):

| Opción | Qué hace |
| --- | --- |
| `--bash` | usar bash aunque haya zsh |
| `--minimal` | sin extras de animación (uv + tte, pipes.sh, btop) |
| `--no-greeting` | sin saludo animado en esa máquina |
| `--yes` | no preguntar nada |

## Actualizar

Edita los ficheros en `~/.dotfiles`, haz commit y push. En las demás máquinas:

```sh
dotfiles-update
```

## Ajustes por máquina

`~/.shellrc.local` se carga al final y no se sube al repo. Por ejemplo `FUN_GREETING=0` para quitar el saludo.

## La terminal (lado cliente)

Los colores del fondo y los iconos los pone la terminal **desde la que te conectas**, no el servidor:

- Fuente: [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads)
- Windows Terminal: copia lo de [`windows-terminal/catppuccin-mocha.json`](windows-terminal/catppuccin-mocha.json)
  (`schemes`, `themes` y los ajustes del perfil) a tu `settings.json`.

## Qué hay

| Ruta | Para qué |
| --- | --- |
| `install.sh` | instalador |
| `zsh/zshrc` | enlazado como `~/.zshrc` (oh-my-zsh + plugins) |
| `shell/common.sh` | prompt, alias, fzf, zoxide y saludo (compartido zsh/bash) |
| `starship/starship.toml` | enlazado como `~/.config/starship.toml` |
| `windows-terminal/` | tema Catppuccin Mocha para Windows Terminal |

Alias: `ls`/`ll`/`la`/`tree` (eza), `cat` (bat), `top` (btop), `cd` (zoxide, salta por nombre), `matrix`, `pipes`.
Atajos: <kbd>Ctrl</kbd>+<kbd>R</kbd> historial difuso, <kbd>Ctrl</kbd>+<kbd>T</kbd> buscar archivos,
<kbd>Esc</kbd> <kbd>Esc</kbd> antepone `sudo`.
