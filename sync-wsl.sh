#!/usr/bin/env bash
# Pull live WSL configs back into this repo. Run from repo root.
set -euo pipefail
cd "$(dirname "$0")"

cp ~/.zshrc                              shared/zshrc
cp ~/.claude/settings.json               shared/claude/settings.json
cp ~/.claude/CLAUDE.md                   shared/claude/CLAUDE.md
cp ~/.claude/bin/ctx-pct-colored.sh      shared/claude/bin/
cp ~/.claude/bin/effort-level.sh         shared/claude/bin/
cp ~/.claude/bin/log-session.sh          shared/claude/bin/
cp ~/.config/ccstatusline/settings.json  shared/ccstatusline/settings.json
cp ~/.codex/config.toml                  shared/codex/config.toml
cp ~/.hermes/config.yaml                 shared/hermes/config.yaml
cp ~/.local/bin/csess                    shared/bin/csess
cp /mnt/c/Users/jay/.wezterm.lua         wsl/wezterm.lua
cp ~/.claude/bin/notify-attention.sh     wsl/claude-bin/notify-attention.sh

echo "synced. git status:"
git status -sb
