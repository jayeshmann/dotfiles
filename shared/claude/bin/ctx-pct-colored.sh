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
  # Pick the most-recent main-chain usage entry by TIMESTAMP, not file order.
  # Claude Code writes entries non-monotonically (parallel tool calls, replayed
  # lines on resume), so `tail -n 1` can lock onto a stale historical row —
  # which is what makes the context % look "stuck" after `--resume`. Matches
  # upstream ccstatusline jsonl-metrics.ts:208-223.
  #
  # `inputs | try fromjson catch empty` reads each JSONL line as a raw string
  # and recovers from per-line parse errors — a single malformed row (we've
  # seen this in real transcripts) would otherwise abort jq and freeze the
  # widget on a stale entry. Mirrors upstream's parseJsonlLine try/catch.
  LATEST=$(jq -nRc '
    [inputs
     | try fromjson catch empty
     | select(.message.usage and (.isSidechain != true) and (.isApiErrorMessage != true) and .timestamp)
    ] | max_by(.timestamp) // empty
  ' "$TRANSCRIPT" 2>/dev/null)
  if [[ -n "$LATEST" ]]; then
    INPUT_T=$(jq -r '.message.usage.input_tokens // 0' <<<"$LATEST")
    CACHE_R=$(jq -r '.message.usage.cache_read_input_tokens // 0' <<<"$LATEST")
    CACHE_C=$(jq -r '.message.usage.cache_creation_input_tokens // 0' <<<"$LATEST")
    CTX=$((INPUT_T + CACHE_R + CACHE_C))
  fi
fi

PCT=$(awk "BEGIN { p=${CTX}/${USABLE}*100; if (p>100) p=100; printf \"%.1f\", p }")
PCT_INT=${PCT%.*}

if   (( PCT_INT >= 40 )); then COLOR=$'\033[1;31m'   # bold red
elif (( PCT_INT >= 30 )); then COLOR=$'\033[1;33m'   # bold yellow
else                            COLOR=$'\033[1;32m'  # bold green
fi
RESET=$'\033[0m'

printf "%s%s%%%s" "$COLOR" "$PCT" "$RESET"
