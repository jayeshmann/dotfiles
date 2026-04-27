#!/usr/bin/env bash
# Pull live WSL configs back into this repo. Run from repo root.
set -euo pipefail
cd "$(dirname "$0")"
. ./lib.sh

cp ~/.zshrc                              shared/zshrc
cp ~/.claude/settings.json               shared/claude/settings.json
cp ~/.claude/CLAUDE.md                   shared/claude/CLAUDE.md
cp ~/.claude/codex-review.schema.json    shared/claude/codex-review.schema.json
cp ~/.claude/bin/ctx-pct-colored.sh      shared/claude/bin/
cp ~/.claude/bin/effort-level.sh         shared/claude/bin/
cp ~/.claude/bin/log-session.sh          shared/claude/bin/
cp ~/.config/ccstatusline/settings.json  shared/ccstatusline/settings.json
cp ~/.codex/config.toml                  shared/codex/config.toml
cp ~/.hermes/config.yaml                 shared/hermes/config.yaml
cp ~/.local/bin/csess                    shared/bin/csess

# Pinned superpowers manifest only — plugin source is reproduced by bootstrap
# from $SP_REMOTE@$SP_TAG + $SP_REMOVED_PATHS, NOT tracked in this repo.
# sp_pin_is_healthy (lib.sh) checks the same conditions bootstrap relies on
# (presence, .git, origin, tag, expected deletions); refusing to sync when
# unhealthy avoids capturing a manifest that doesn't match a real install.
if ! sp_pin_is_healthy; then
    echo "ERR: live pinned fork at $SP_TARGET is not healthy — one of: missing/malformed clone, wrong origin, missing/stale $SP_PIN_MARKER (expected '$SP_TAG'), or required deletions still present." >&2
    echo "     Run ./bootstrap-wsl.sh to repair before retrying sync." >&2
    exit 1
fi
cp "$SP_PIN/.claude-plugin/marketplace.json" \
   shared/claude/local-marketplaces/superpowers-pinned/.claude-plugin/marketplace.json
cp /mnt/c/Users/jay/.wezterm.lua         wsl/wezterm.lua
cp ~/.claude/bin/notify-attention.sh     wsl/claude-bin/notify-attention.sh

echo "synced. git status:"
git status -sb
