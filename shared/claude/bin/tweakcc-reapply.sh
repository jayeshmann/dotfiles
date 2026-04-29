#!/usr/bin/env bash
# SessionStart hook: re-apply tweakcc patches when Claude Code's version
# changes. Compares `claude --version` to the persisted last-applied marker
# and runs `tweakcc --apply` only on drift.
#
# Concurrency: flocks the apply window so parallel SessionStart hooks don't
# race against the same Claude installation. Marker is written via temp+mv
# only after a successful apply, so a failed apply leaves the marker untouched
# and the next session will retry.

set -euo pipefail

TWEAKCC_DIST="${HOME}/.local/share/tweakcc/dist/index.mjs"
MARKER="${HOME}/.tweakcc/.last-applied-cc-version"
LOG_DIR="${HOME}/.tweakcc"
LOG="${LOG_DIR}/reapply.log"
LOCK="${LOG_DIR}/reapply.lock"

[[ -f "$TWEAKCC_DIST" ]] || exit 0
mkdir -p "$LOG_DIR"

(
  exec 9>"$LOCK"
  if ! flock -n 9; then
    exit 0
  fi

  CURRENT_CC=$(claude --version 2>/dev/null | awk '{print $1}')
  [[ -z "$CURRENT_CC" ]] && exit 0

  LAST_APPLIED=""
  [[ -f "$MARKER" ]] && LAST_APPLIED=$(cat "$MARKER")

  [[ "$CURRENT_CC" == "$LAST_APPLIED" ]] && exit 0

  echo "[$(date -Iseconds)] CC version drift: '$LAST_APPLIED' -> '$CURRENT_CC', running tweakcc --apply" >>"$LOG"
  if node "$TWEAKCC_DIST" --apply >>"$LOG" 2>&1; then
    tmp=$(mktemp "${MARKER}.XXXXXX")
    printf '%s' "$CURRENT_CC" > "$tmp"
    mv "$tmp" "$MARKER"
    echo "[$(date -Iseconds)] tweakcc apply OK; marker -> $CURRENT_CC" >>"$LOG"
  else
    echo "[$(date -Iseconds)] tweakcc apply FAILED — marker untouched, will retry next session" >>"$LOG"
  fi
) &

exit 0
