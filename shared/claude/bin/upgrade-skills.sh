#!/usr/bin/env bash
# SessionStart hook: keep `skills` CLI installs (mattpocock/skills etc.)
# current via `skills update -g -y`.
#
# Cadence: at most one successful update per 24h. Stamp only on exit 0
# so failed runs retry next session.
# Concurrency: flock on Linux/WSL, mkdir-based lock fallback on macOS.
# Failure handling: every path exits 0 — never block CC startup.
# Logs: ~/.local/state/dotfiles/upgrade-skills.log (outside the repo).
# Disable: `touch ~/.config/skills/upgrade-disabled`.

set -uo pipefail

STATE_DIR="$HOME/.local/state/dotfiles"
LOG="$STATE_DIR/upgrade-skills.log"
LOCK="$STATE_DIR/upgrade-skills.lock"
STAMP="$STATE_DIR/upgrade-skills.stamp"
THROTTLE_SECONDS=86400  # 24h
TIMEOUT_SECONDS=120

# Portable ISO-ish timestamp; macOS/BSD `date` lacks `-Iseconds`.
now() { date '+%Y-%m-%dT%H:%M:%S%z'; }

[[ -e "$HOME/.config/skills/upgrade-disabled" ]] && exit 0

mkdir -p "$STATE_DIR"

# Throttle: skip if last successful run was <24h ago.
# stat flags differ across GNU (Linux/WSL) and BSD (macOS); try both.
if [[ -f "$STAMP" ]]; then
  stamp_mtime=$(stat -c %Y "$STAMP" 2>/dev/null \
    || stat -f %m "$STAMP" 2>/dev/null \
    || echo 0)
  age=$(( $(date +%s) - stamp_mtime ))
  [[ $age -lt $THROTTLE_SECONDS ]] && exit 0
fi

# Resolve `npx` — hook env may lack interactive PATH. Source nvm if present.
if ! command -v npx >/dev/null 2>&1; then
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    \. "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
  fi
fi
command -v npx >/dev/null 2>&1 || exit 0

# Portable timeout: GNU coreutils (Linux/WSL) ships `timeout`; macOS without
# coreutils ships neither, in which case we run untimed rather than 127-fail
# every session.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout "$TIMEOUT_SECONDS")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout "$TIMEOUT_SECONDS")
else
  TIMEOUT_CMD=()
fi

run_update() {
  echo "[$(now)] check start" >>"$LOG"

  # Guarded expansion: `"${arr[@]}"` on an empty array errors under
  # `set -u` on bash 3.2 (stock macOS). The `+` form expands to nothing
  # when unset/empty and is portable.
  if ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} npx -y skills@latest update -g -y >>"$LOG" 2>&1; then
    touch "$STAMP"
    echo "[$(now)] check ok" >>"$LOG"
  else
    rc=$?
    echo "[$(now)] check failed (exit $rc); will retry next session" >>"$LOG"
  fi
}

# Concurrency: prefer flock (Linux/WSL); fall back to atomic mkdir on macOS
# without util-linux. Either way, only one updater runs at a time and
# overlapping sessions skip cleanly.
if command -v flock >/dev/null 2>&1; then
  (
    exec 9>"$LOCK"
    flock -n 9 || exit 0
    run_update
  ) &
else
  LOCK_DIR="$LOCK.d"
  (
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      exit 0
    fi
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
    run_update
  ) &
fi

exit 0
