#!/usr/bin/env bash
# Push repo configs out to live WSL paths. Backs up existing files to *.bak.<ts>.
set -euo pipefail
cd "$(dirname "$0")"

ts=$(date +%s)
backup() { [[ -e "$1" ]] && cp "$1" "$1.bak.$ts" || true; }

mkdir -p ~/.claude/bin ~/.config/ccstatusline ~/.codex ~/.hermes ~/.local/bin

backup ~/.zshrc                              && cp shared/zshrc                              ~/.zshrc
backup ~/.claude/settings.json               && cp shared/claude/settings.json               ~/.claude/settings.json
backup ~/.claude/CLAUDE.md                   && cp shared/claude/CLAUDE.md                   ~/.claude/CLAUDE.md
backup ~/.claude/bin/ctx-pct-colored.sh      && cp shared/claude/bin/ctx-pct-colored.sh      ~/.claude/bin/
backup ~/.claude/bin/effort-level.sh         && cp shared/claude/bin/effort-level.sh         ~/.claude/bin/
backup ~/.claude/bin/log-session.sh          && cp shared/claude/bin/log-session.sh          ~/.claude/bin/
backup ~/.config/ccstatusline/settings.json  && cp shared/ccstatusline/settings.json         ~/.config/ccstatusline/settings.json
backup ~/.codex/config.toml                  && cp shared/codex/config.toml                  ~/.codex/config.toml
backup ~/.hermes/config.yaml                 && cp shared/hermes/config.yaml                 ~/.hermes/config.yaml
backup ~/.local/bin/csess                    && cp shared/bin/csess                          ~/.local/bin/csess
backup /mnt/c/Users/jay/.wezterm.lua         && cp wsl/wezterm.lua                           /mnt/c/Users/jay/.wezterm.lua
backup ~/.claude/bin/notify-attention.sh     && cp wsl/claude-bin/notify-attention.sh        ~/.claude/bin/notify-attention.sh

chmod +x ~/.claude/bin/*.sh ~/.local/bin/csess

echo "bootstrap complete. Existing files backed up with .bak.$ts suffix."
