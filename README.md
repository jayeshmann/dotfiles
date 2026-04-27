# dotfiles

Personal config mirror — Claude Code, zsh, terminal — across WSL2 and (future) macOS.

## Layout

```
shared/                          # cross-platform base
  zshrc                          → ~/.zshrc
  ccstatusline/settings.json     → ~/.config/ccstatusline/settings.json
  claude/
    CLAUDE.md                    → ~/.claude/CLAUDE.md
    codex-review.schema.json     → ~/.claude/codex-review.schema.json
    settings.json                → ~/.claude/settings.json
    bin/
      ctx-pct-colored.sh         → ~/.claude/bin/ctx-pct-colored.sh
      effort-level.sh            → ~/.claude/bin/effort-level.sh
      log-session.sh             → ~/.claude/bin/log-session.sh
  codex/
    config.toml                  → ~/.codex/config.toml
  hermes/
    config.yaml                  → ~/.hermes/config.yaml
  bin/
    csess                        → ~/.local/bin/csess
  claude/local-marketplaces/superpowers-pinned/.claude-plugin/marketplace.json
                                 → ~/.claude/local-marketplaces/superpowers-pinned/.claude-plugin/marketplace.json
                                   (pinned superpowers fork manifest; plugin source is cloned by bootstrap, not tracked)
wsl/                             # WSL-only
  wezterm.lua                    → /mnt/c/Users/jay/.wezterm.lua
  claude-bin/
    notify-attention.sh          → ~/.claude/bin/notify-attention.sh   (PowerShell toast)
mac/                             # macOS-only (placeholder — to be filled when used on Mac)
```

## Hosts

| Host | Terminal | Multiplexer | Shell |
|---|---|---|---|
| WSL2 Ubuntu | WezTerm (Windows) | — | zsh + Starship |
| macOS (future) | iTerm2 / Ghostty | tmux or cmux | zsh + Starship |

Goal: keep `shared/` truly shared. Differences live in `wsl/` and `mac/`. The Claude Code config (`shared/claude/`, `shared/ccstatusline/`) and the bulk of `zshrc` should work as-is on both; only platform-specific bits diverge (terminal, notification script, distro-specific paths in zshrc).

## Bootstrap (WSL)

```bash
cd ~/code/dotfiles
./bootstrap-wsl.sh
```

## Sync after local changes

```bash
cd ~/code/dotfiles
./sync-wsl.sh           # pull live configs back into the repo
git add -A && git commit -m "sync" && git push
```

## Notes

- `effortLevel: xhigh` works on Opus 4.7. ccstatusline 2.2.8 doesn't recognize it natively (PR #314 merged on main, awaiting 2.2.9 release) — that's why `effort` uses a custom-command script.
- `ctx-pct-colored.sh` exists because ccstatusline 2.2.8 has no native threshold coloring for context %.
- `notify-attention.sh` uses `powershell.exe` and is WSL-only. macOS equivalent will use `osascript` once added.
- Mac zsh paths (homebrew, fzf, java) will differ — plan to either templatize `zshrc` or split per-host once Mac is wired up.
- `bootstrap-wsl.sh` also installs **mattpocock/skills** into `~/.claude/skills/` (skipping any already present) and reconstructs the **superpowers-pinned** local marketplace (`obra/superpowers@v5.0.7` minus three intentionally-removed skills + the deprecated `/write-plan` command). Auto-update can't reach the pinned copy because it lives outside `~/.claude/plugins/cache/`.
- **hackingtool** (Z4nzu/hackingtool) is **not** auto-installed — it requires `sudo`. Install manually for authorized pentest engagements: `curl -sSL https://raw.githubusercontent.com/Z4nzu/hackingtool/master/install.sh | sudo bash`.
