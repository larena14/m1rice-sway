#!/usr/bin/env bash
set -euo pipefail

entries="$(cliphist list 2>/dev/null || true)"

if [[ -z "$entries" ]]; then
    entries="Clear history"
fi

choice="$(printf '%s\nClear history\n' "$entries" |
    fzf \
        --height=100% \
        --layout=reverse \
        --border=rounded \
        --info=inline \
        --prompt='Clipboard > ' \
        --preview='cliphist list | grep -F -- {} | cut -f1 | xargs -r cliphist decode 2>/dev/null | head -n 100' \
        --preview-window='right,55%,border-left,wrap')"

if [[ "$choice" == "Clear history" ]]; then
    confirm="$(printf 'Cancel\nConfirm\n' |
        fzf --height=100% --layout=reverse --border=rounded --prompt='Clear all history? > ')"

    if [[ "$confirm" == "Confirm" ]]; then
        cliphist wipe
        wl-copy --clear
    fi

    exit 0
fi

if [[ -n "$choice" ]]; then
    printf '%s\n' "$choice" | cliphist decode | wl-copy
fi
