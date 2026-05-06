#!/usr/bin/env bash
# Stop hook: auto-sync Claude Code config into the dotfiles repo.
#
# Cross-machine coordination model:
#   1. Hold a flock so concurrent Stop hooks don't race.
#   2. Refuse to run if the index already has staged changes — those are
#      the user's in-flight work and must not get bundled into an
#      auto-sync commit.
#   3. `git pull --rebase`. If pull moved HEAD, the OTHER machine has
#      pushed since we last synced. Refuse to run ./dot sync (which
#      would clobber the freshly-pulled state with stale local files).
#      Skip silently; the user reconciles via ./dot bootstrap.
#   4. `git fetch origin` immediately before commit. If the remote has
#      advanced between our pull and now, abort BEFORE committing — we
#      don't create a stale commit at all.
#   5. Commit ONLY the mirrored allowlist via pathspec, then push.
#
# Known limitation: if `git push` itself fails (network, hook reject,
# remote advanced in the gap between fetch and push), the local commit
# stays on the branch. The next run's pull-then-HEAD-comparison guard
# (step 3) refuses to add another stale commit on top, so the failure
# is contained — the branch sits one auto-sync commit ahead of remote
# until manually reconciled. We do not auto-rollback because that
# requires `git reset`, which CLAUDE.md disallows in unattended scripts.
#
# Logs live OUTSIDE the repo so they never enter a commit.
# All failures are logged, never block CC.

set -euo pipefail

DOTFILES="${HOME}/code/dotfiles"
STATE_DIR="${HOME}/.local/state/dotfiles"
LOG="${STATE_DIR}/autosync.log"
LOCK="${STATE_DIR}/autosync.lock"

[[ -d "$DOTFILES/.git" ]] || exit 0
mkdir -p "$STATE_DIR"

(
  exec 9>"$LOCK"
  if ! flock -n 9; then
    exit 0
  fi

  cd "$DOTFILES"

  # Refuse if user has staged work — don't bundle it into an auto-sync.
  if ! git diff --cached --quiet; then
    echo "[$(date -Iseconds)] index already has staged changes; skipping auto-sync (user is mid-commit)." >>"$LOG"
    exit 0
  fi

  HEAD_BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")

  if ! git pull --rebase --autostash origin main >>"$LOG" 2>&1; then
    echo "[$(date -Iseconds)] pull failed, aborting" >>"$LOG"
    exit 0
  fi

  HEAD_AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
  if [[ "$HEAD_BEFORE" != "$HEAD_AFTER" ]]; then
    echo "[$(date -Iseconds)] pull moved HEAD ${HEAD_BEFORE:0:7} -> ${HEAD_AFTER:0:7}; skipping sync to avoid clobbering remote changes. Reconcile manually via ./dot bootstrap." >>"$LOG"
    exit 0
  fi

  if [[ ! -x ./dot ]]; then
    echo "[$(date -Iseconds)] ./dot not found or not executable; skipping." >>"$LOG"
    exit 0
  fi
  if ! ./dot sync >>"$LOG" 2>&1; then
    echo "[$(date -Iseconds)] ./dot sync failed" >>"$LOG"
    exit 0
  fi

  TRACKED_PATHS=(
    shared/zshrc
    shared/claude
    shared/ccstatusline
    shared/tweakcc
    shared/codex
    shared/hermes
    shared/bin
    wsl
    mac
  )

  git add -- "${TRACKED_PATHS[@]}" 2>>"$LOG" || true
  if git diff --cached --quiet; then
    exit 0
  fi

  # Final freshness check before committing — if remote moved between
  # our pull and now, abort before creating a commit at all.
  if ! git fetch origin main >>"$LOG" 2>&1; then
    echo "[$(date -Iseconds)] pre-commit fetch failed; aborting." >>"$LOG"
    exit 0
  fi
  REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null || echo "")
  if [[ -n "$REMOTE_HEAD" && "$REMOTE_HEAD" != "$HEAD_AFTER" ]]; then
    echo "[$(date -Iseconds)] remote advanced after pull (origin/main=${REMOTE_HEAD:0:7}, local=${HEAD_AFTER:0:7}); aborting before commit." >>"$LOG"
    exit 0
  fi

  HOST=$(hostname -s 2>/dev/null || hostname)
  if ! git commit -m "auto-sync from ${HOST} @ $(date -Iseconds)" -- "${TRACKED_PATHS[@]}" >>"$LOG" 2>&1; then
    echo "[$(date -Iseconds)] commit failed" >>"$LOG"
    exit 0
  fi

  if ! git push origin main >>"$LOG" 2>&1; then
    echo "[$(date -Iseconds)] push failed; local branch is one commit ahead of origin until manually reconciled." >>"$LOG"
  fi
) &

exit 0
