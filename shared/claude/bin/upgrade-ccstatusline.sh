#!/usr/bin/env bash
# SessionStart hook: keep ccstatusline at upstream main HEAD.
#
# On each session start: git fetch (cheap), exit immediately if HEAD already
# matches origin/main, otherwise ff-merge + `bun install && bun run build`.
# Build failures roll back to the previous commit so we don't ship a broken
# dist/ccstatusline.js into a live statusline tick.
#
# Concurrency: flocks against parallel SessionStart hooks.
# Failure handling: every error path exits 0 — never block CC.
# Logs: ~/.local/state/dotfiles/upgrade-ccstatusline.log (outside the repo).

set -uo pipefail

REPO_DIR="$HOME/.local/share/ccstatusline"
DIST="$REPO_DIR/dist/ccstatusline.js"
STATE_DIR="$HOME/.local/state/dotfiles"
LOG="$STATE_DIR/upgrade-ccstatusline.log"
LOCK="$STATE_DIR/upgrade-ccstatusline.lock"

# Disable knob — match the tweakcc convention.
[[ -e "$HOME/.config/ccstatusline/upgrade-disabled" ]] && exit 0

[[ -d "$REPO_DIR/.git" ]] || exit 0
mkdir -p "$STATE_DIR"

(
  exec 9>"$LOCK"
  flock -n 9 || exit 0

  cd "$REPO_DIR"

  old_sha=$(git rev-parse HEAD 2>/dev/null) || exit 0

  # Fetch quietly; tolerate offline.
  if ! git fetch --quiet origin main 2>>"$LOG"; then
    echo "[$(date -Iseconds)] fetch failed (offline?); skipping" >>"$LOG"
    exit 0
  fi

  new_sha=$(git rev-parse origin/main 2>/dev/null)
  [[ -z "$new_sha" ]] && exit 0

  # Already current — fast path, no build.
  if [[ "$old_sha" == "$new_sha" ]]; then
    exit 0
  fi

  echo "[$(date -Iseconds)] upgrade: $old_sha -> $new_sha" >>"$LOG"

  if ! git merge --ff-only origin/main >>"$LOG" 2>&1; then
    echo "[$(date -Iseconds)] ff-merge failed (local commits?); skipping" >>"$LOG"
    exit 0
  fi

  # Rebuild. If it fails, hard-reset to the previous commit so the live
  # statusline keeps working with the previous dist.
  if (bun install && bun run build) >>"$LOG" 2>&1 && [[ -f "$DIST" ]]; then
    echo "[$(date -Iseconds)] rebuilt OK" >>"$LOG"
  else
    echo "[$(date -Iseconds)] build failed — rolling back to $old_sha" >>"$LOG"
    git reset --hard "$old_sha" >>"$LOG" 2>&1 || true
    # Re-run build from old_sha so dist matches the rolled-back source.
    (bun install && bun run build) >>"$LOG" 2>&1 || \
      echo "[$(date -Iseconds)] post-rollback rebuild also failed; dist may be stale" >>"$LOG"
  fi
) &

exit 0
