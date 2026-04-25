#!/usr/bin/env bash
# Reads ccstatusline JSON from stdin, prints current effort level.
# Prefers live `.effort.level` (reflects mid-session /effort changes),
# falls back to settings.json effortLevel, then "medium".
INPUT=$(cat)
EFFORT=$(jq -r '.effort.level // empty' <<<"$INPUT" 2>/dev/null)
[[ -z "$EFFORT" ]] && EFFORT=$(jq -r '.effortLevel // "medium"' ~/.claude/settings.json 2>/dev/null)
[[ -z "$EFFORT" ]] && EFFORT="medium"

case "$EFFORT" in
  max)    COLOR=$'\033[1;35m' ;;  # bold magenta
  xhigh)  COLOR=$'\033[1;31m' ;;  # bold red
  high)   COLOR=$'\033[1;33m' ;;  # bold yellow
  medium) COLOR=$'\033[1;32m' ;;  # bold green
  low)    COLOR=$'\033[1;36m' ;;  # bold cyan
  *)      COLOR=$'\033[0m'    ;;
esac
RESET=$'\033[0m'

printf "%s%s%s" "$COLOR" "$EFFORT" "$RESET"
