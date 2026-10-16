#!/usr/bin/env bash
set -euo pipefail

APP_ID="waybar-clipboard"

if swaymsg -t get_tree | grep -q "\"app_id\": \"$APP_ID\""; then
    swaymsg "[app_id=\"$APP_ID\"] focus"
    exit 0
fi

alacritty \
    --class "$APP_ID" \
    --title "Clipboard" \
    -e "$HOME/.config/waybar/scripts/clipboard-menu.sh"

