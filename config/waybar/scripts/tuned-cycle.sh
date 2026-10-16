#!/usr/bin/env bash

current=$(tuned-adm active | sed 's/Current active profile: //')

case "$current" in
  powersave)
    next="balanced"
    ;;
  balanced)
    next="throughput-performance"
    ;;
  *)
    next="powersave"
    ;;
esac

sudo tuned-adm profile "$next"