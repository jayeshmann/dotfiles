# dotfiles

Personal config mirror — Claude Code, zsh, terminal — across WSL2 and macOS.

## Layout

```
shared/                          # cross-platform base
  zshrc                          → ~/.zshrc
  ccstatusline/settings.json     → ~/.config/ccstatusline/settings.json
  tweakcc/config.json            → ~/.tweakcc/config.json
  claude/
    CLAUDE.md                    → ~/.claude/CLAUDE.md
    codex-review.schema.json     → ~/.claude/codex-review.schema.json
    settings.json                → ~/.claude/settings.json
    bin/
      ctx-pct-colored.sh         → ~/.claude/bin/ctx-pct-colored.sh
      log-session.sh             → ~/.claude/bin/log-session.sh
      tweakcc-reapply.sh         → ~/.claude/bin/tweakcc-reapply.sh   (SessionStart hook)
      dotfiles-autosync.sh       → ~/.claude/bin/dotfiles-autosync.sh (Stop hook)
  codex/config.toml              → ~/.codex/config.toml
  hermes/config.yaml             → ~/.hermes/config.yaml
  bin/csess                      → ~/.local/bin/csess
wsl/                             # WSL-only
  wezterm.lua                    → /mnt/c/Users/jay/.wezterm.lua
  claude-bin/notify-attention.sh → ~/.claude/bin/notify-attention.sh   (PowerShell toast)
mac/                             # macOS-only (placeholder)
```

## Hosts

| Host | Terminal | Multiplexer | Shell |
|---|---|---|---|
| WSL2 Ubuntu | WezTerm (Windows) | — | zsh + Starship |
| macOS | iTerm2 / Ghostty | tmux or cmux | zsh + Starship |

## Bootstrap (WSL)

```bash
cd ~/code/dotfiles
./bootstrap-wsl.sh
```

What bootstrap does:
1. Backs up existing live configs to `*.bak.<ts>`.
2. Pushes tracked configs to live paths.
3. Clones+builds **ccstatusline** from main HEAD into `~/.local/share/ccstatusline`. The live `statusLine.command` in `~/.claude/settings.json` runs the built `dist/ccstatusline.js` directly — no remote refetch per status tick.
4. Clones+builds **tweakcc** from main HEAD into `~/.local/share/tweakcc` and runs `--apply` to patch Claude Code with the preset in `shared/tweakcc/config.json`.
5. Installs **mattpocock/skills** main HEAD into `~/.claude/skills/` (replaces existing entries so deprecations propagate).

## Sync after local changes

Manual:
```bash
cd ~/code/dotfiles
./sync-wsl.sh
git add -A && git commit -m "sync" && git push
```

Automatic: `dotfiles-autosync.sh` runs on Claude Code's `Stop` hook — every time a session ends it pulls, runs `sync-wsl.sh`, commits any changes (allowlisted pathspec) with `auto-sync from <hostname>`, and pushes. The hook holds a `flock` so concurrent sessions can't race, refuses to run if the index already has staged work, refuses to sync if `git pull` brought in remote changes (forces manual reconciliation), and rolls back its own commit if the push fails. Logs at `~/.local/state/dotfiles/autosync.log` (outside the repo so they never enter a commit). Failures never block CC; check the log if changes seem to drift between machines.

## Auto-reapply tweakcc on Claude Code update

`tweakcc-reapply.sh` runs on `SessionStart`. It compares `claude --version` to `~/.tweakcc/.last-applied-cc-version` and re-runs `tweakcc --apply` only when CC has been upgraded — keeping the patch set in sync with whatever CC version got pulled in by Anthropic's auto-updater.

## Notes

- **ccstatusline native widgets used:** `thinking-effort` (handles xhigh natively on main HEAD via PRs #314 + #252), `context-percentage-usable`, `session-usage`, `reset-timer`, `weekly-usage`, `weekly-reset-timer`, `git-branch`, `git-changes`, `git-pr`, `worktree-name`, `version`, `session-clock`, `model`, `claude-session-id`. The remaining custom-command widget is `ctx-pct-colored.sh` because no native widget does threshold-based coloring on context %.
- **Mac differences:** zsh paths (homebrew, fzf, java) will diverge; plan to templatize `zshrc` or split per-host once Mac entries land. The PowerShell-based `notify-attention.sh` will be replaced by an `osascript` equivalent under `mac/`.
- **hackingtool** (Z4nzu/hackingtool) is **not** auto-installed — install manually for authorized pentest engagements only: `curl -sSL https://raw.githubusercontent.com/Z4nzu/hackingtool/master/install.sh | sudo bash`.
