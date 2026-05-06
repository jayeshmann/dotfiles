#!/usr/bin/env bash
# Threshold-colored context % matching ccstatusline's context-percentage-usable widget logic.
# Reads CC's statusline JSON from stdin, outputs ANSI-colored "N.N%" string.

INPUT=$(cat)
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null)
MODEL_ID=$(jq -r '.model.id // ""' <<<"$INPUT" 2>/dev/null)

WINDOW=200000
[[ "$MODEL_ID" == *1m* ]] && WINDOW=1000000
USABLE=$((WINDOW * 80 / 100))

CTX=0
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  LATEST=$(tac "$TRANSCRIPT" 2>/dev/null | jq -c 'select(.message.usage and (.isSidechain != true) and (.isApiErrorMessage != true))' 2>/dev/null | head -1)
  if [[ -n "$LATEST" ]]; then
    INPUT_T=$(jq -r '.message.usage.input_tokens // 0' <<<"$LATEST")
    CACHE_R=$(jq -r '.message.usage.cache_read_input_tokens // 0' <<<"$LATEST")
    CACHE_C=$(jq -r '.message.usage.cache_creation_input_tokens // 0' <<<"$LATEST")
    CTX=$((INPUT_T + CACHE_R + CACHE_C))
  fi
fi

PCT=$(awk "BEGIN { p=${CTX}/${USABLE}*100; if (p>100) p=100; printf \"%.1f\", p }")
PCT_INT=${PCT%.*}

if   (( PCT_INT >= 70 )); then COLOR=$'\033[1;31m'   # bold red
elif (( PCT_INT >= 50 )); then COLOR=$'\033[1;33m'   # bold yellow
else                            COLOR=$'\033[1;32m'  # bold green
fi
RESET=$'\033[0m'

printf "%s%s%%%s" "$COLOR" "$PCT" "$RESET"
