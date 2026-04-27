#!/usr/bin/env bash
# Pull live WSL configs back into this repo. Run from repo root.
set -euo pipefail
cd "$(dirname "$0")"

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
# from upstream@v5.0.7 + deletions, NOT tracked in this repo. Validate the live
# fork looks sane before syncing the manifest, so we don't capture a manifest
# that doesn't match a healthy install.
sp_live=~/.claude/local-marketplaces/superpowers-pinned
if [[ ! -f "$sp_live/.claude-plugin/marketplace.json" ]]; then
    echo "ERR: $sp_live/.claude-plugin/marketplace.json missing — run ./bootstrap-wsl.sh first." >&2
    exit 1
fi
if [[ ! -f "$sp_live/superpowers/.claude-plugin/plugin.json" ]]; then
    echo "ERR: $sp_live/superpowers is missing .claude-plugin/plugin.json — pinned fork incomplete, run ./bootstrap-wsl.sh." >&2
    exit 1
fi
sp_origin=$(git -C "$sp_live/superpowers" config --get remote.origin.url 2>/dev/null || echo "")
if [[ "$sp_origin" != "https://github.com/obra/superpowers" && "$sp_origin" != "https://github.com/obra/superpowers.git" ]]; then
    echo "ERR: live pinned fork origin is '$sp_origin' (expected obra/superpowers) — refusing to sync manifest." >&2
    exit 1
fi
sp_violations=0
for forbidden in skills/writing-plans skills/subagent-driven-development skills/test-driven-development commands/write-plan.md; do
    if [[ -e "$sp_live/superpowers/$forbidden" ]]; then
        echo "ERR: live pinned fork still contains $forbidden — pinned-fork invariant broken." >&2
        sp_violations=$((sp_violations + 1))
    fi
done
if (( sp_violations > 0 )); then
    echo "ERR: refusing to sync $sp_violations forbidden path(s) above. Re-prune the live fork or re-run ./bootstrap-wsl.sh." >&2
    exit 1
fi
cp "$sp_live/.claude-plugin/marketplace.json" \
   shared/claude/local-marketplaces/superpowers-pinned/.claude-plugin/marketplace.json
cp /mnt/c/Users/jay/.wezterm.lua         wsl/wezterm.lua
cp ~/.claude/bin/notify-attention.sh     wsl/claude-bin/notify-attention.sh

echo "synced. git status:"
git status -sb
