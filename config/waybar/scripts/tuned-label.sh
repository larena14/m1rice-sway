#!/usr/bin/env bash

current=$(tuned-adm active | sed 's/Current active profile: //')

case "$current" in
  powersave)
    printf "<span foreground='#a6e3a1'>󰌪</span>"
    ;;
  balanced)
    printf '󰾅'
    ;;
  throughput-performance)
    printf "<span foreground='#f38ba8'>󰓅</span>"
    ;;
  *)
    printf '󰚈'
    ;;
esac