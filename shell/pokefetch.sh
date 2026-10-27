#!/usr/bin/env bash
# pokefetch — fastfetch con un Pokémon al azar como logo.
# Basado en https://github.com/Discomanfulanito/pokefetch (GPL-3.0, por discomanfulanito).
# Necesita pokeget (https://github.com/talwat/pokeget-rs) y fastfetch.

# Pokémon entre los que elige (nombres y opciones como en `pokeget --help`).
# "random" saca cualquiera de todas las generaciones.
POKEMON_LIST=(
  random
)
SHINY_CHANCE=20  # 1 de cada N sale shiny (0 = nunca)

FETCHER="fastfetch --logo none"
FETCHER_HEIGHT=$($FETCHER | wc -l)

# Ajustes de espacio
EXTRA_PADDING_H=2
EXTRA_PADDING_W=0
WIDTH=38  # hueco reservado para el sprite

shiny=""
(( SHINY_CHANCE > 0 && RANDOM % SHINY_CHANCE == 0 )) && shiny="--shiny"

sprite=$(pokeget ${POKEMON_LIST[RANDOM % ${#POKEMON_LIST[@]}]} $shiny --hide-name)
height=$(echo "$sprite" | wc -l)

# Centrado vertical
pad_top=$(( (FETCHER_HEIGHT - height) / 2 + EXTRA_PADDING_H ))
(( pad_top < 0 )) && pad_top=0

# Ancho real del sprite (sin los códigos de color)
sprite_width=$(
  printf '%s\n' "$sprite" \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | awk '{ if (length > max) max = length } END { print max }'
)

# Centrado horizontal (+1 a la derecha para anchos impares)
pad_left=$(( (WIDTH - sprite_width) / 2 + EXTRA_PADDING_W ))
pad_right=$(( (WIDTH - sprite_width + 1) / 2 + EXTRA_PADDING_W ))
(( pad_left < 0 )) && pad_left=0
(( pad_right < 0 )) && pad_right=0

echo "$sprite" | fastfetch --file-raw - --logo-padding-top $pad_top --logo-padding-left $pad_left --logo-padding-right $pad_right
