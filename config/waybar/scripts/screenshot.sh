#!/usr/bin/env bash
set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"

FILE="$DIR/screenshot-$(date +%Y-%m-%d-%H-%M-%S).png"

# Select an area; Esc cancels
geometry="$(slurp)" || exit 0

# Capture the selected area and open it in swappy
grim -g "$geometry" - | swappy -f -

