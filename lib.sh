#!/usr/bin/env bash
# Shared helpers for dotfiles bootstrap-wsl.sh and sync-wsl.sh.
# Source from sibling scripts: . "$(dirname "$0")/lib.sh"

# Pinned superpowers fork — auto-update-proof. Both bootstrap (which builds it)
# and sync (which captures the manifest) reference these constants and the
# health check below, so they stay in lockstep.
SP_PIN=~/.claude/local-marketplaces/superpowers-pinned
SP_TARGET="$SP_PIN/superpowers"
SP_REMOTE="https://github.com/obra/superpowers"
SP_TAG="v5.0.7"
SP_REMOVED_PATHS=(
    "skills/writing-plans"
    "skills/subagent-driven-development"
    "skills/test-driven-development"
    "commands/write-plan.md"
)

# Path of the marker file bootstrap writes after a successful pinned install.
# Stored inside $SP_TARGET so it disappears if the directory is deleted, and
# named with a `dotfiles-` prefix to avoid colliding with anything upstream.
SP_PIN_MARKER=".dotfiles-pinned-tag"

# Returns 0 if the live pinned fork looks healthy: present, correct origin,
# bootstrap-written tag-marker file matches $SP_TAG, all intentionally-removed
# paths absent. The marker is install provenance — anyone with write access to
# $SP_TARGET could spoof it — not cryptographic verification of the checked-out
# commit. That trade-off is acceptable here vs the shallow-clone tag-ref
# problem (see below). Silent on failure — caller decides whether to repair
# (bootstrap) or fail (sync). The marker file (rather than
# `git describe --tags`) is checked because shallow `--branch <tag>` clones
# don't materialize tag refs.
sp_pin_is_healthy() {
    [[ -d "$SP_TARGET/.claude-plugin" ]] || return 1
    [[ -d "$SP_TARGET/.git" ]] || return 1
    local origin pinned p
    origin=$(git -C "$SP_TARGET" config --get remote.origin.url 2>/dev/null || echo "")
    [[ "$origin" == "$SP_REMOTE" || "$origin" == "$SP_REMOTE.git" ]] || return 1
    pinned=$(cat "$SP_TARGET/$SP_PIN_MARKER" 2>/dev/null || echo "")
    [[ "$pinned" == "$SP_TAG" ]] || return 1
    for p in "${SP_REMOVED_PATHS[@]}"; do
        [[ ! -e "$SP_TARGET/$p" ]] || return 1
    done
    return 0
}
