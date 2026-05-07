# dotfiles

Personal config mirror — Claude Code, zsh, terminal — across WSL2 and macOS.

One script (`./dot`), one zshrc, one repo. OS branches happen at runtime.

## Layout

```
dot                              # single entry point: bootstrap/sync/restore/menu
shared/                          # cross-platform — runs on both Mac and WSL
  zshrc.common                   → ~/.zshrc.common     (cross-OS additions; sourced from ~/.zshrc)
  ccstatusline/settings.json     → ~/.config/ccstatusline/settings.json
                                   (uses __HOME__ placeholder; bootstrap subs in $HOME)
  claude/
    CLAUDE.md                    → ~/.claude/CLAUDE.md
    codex-review.schema.json     → ~/.claude/codex-review.schema.json
    settings.json                → ~/.claude/settings.json   (uses $HOME, shell-evaluated)
    bin/                         → ~/.claude/bin/<*.sh>
    skills/<name>/               → ~/.claude/skills/<name>   (or ~/.agents/skills/ on Mac)
  codex/config.toml              → ~/.codex/config.toml
  hermes/config.yaml             → ~/.hermes/config.yaml   (WSL-only; Mac skips)
  bin/csess                      → ~/.local/bin/csess
wsl/                             # WSL-only
  wezterm.lua                    → /mnt/c/Users/<you>/.wezterm.lua
  claude-bin/notify-attention.sh → ~/.claude/bin/notify-attention.sh   (PowerShell toast)
mac/                             # macOS-only (currently empty — cmux ships native CC notifications)
```

## `./dot` — one script, three actions

```bash
cd ~/code/dotfiles

./dot              # interactive menu
./dot bootstrap    # repo → live  (one-time setup; clones+builds deps)
./dot sync         # live → repo  (run before commit)
./dot restore      # .bak.<ts> → live  (roll back the most recent bootstrap)
./dot help
```

Mental model:
- **bootstrap** is "apply" — writes your dotfiles into `~/...`. Backs up
  what was there to `<file>.bak.<ts>`. Also installs missing deps end-to-end
  on a fresh machine: apt/brew packages, `bun`, `starship`, `zinit`, `codex`
  (Mac), RTK, and ccstatusline. The only thing it can't install for you is
  `claude` itself — first-run auth is interactive — so install Claude Code
  first (<https://docs.claude.com/en/docs/claude-code/setup>), then run
  bootstrap once.
- **sync** is "capture" — pulls `~/.zshrc.common`, `~/.claude/...`, etc.
  back into `shared/...` so your edits get committed and propagated to your
  other machine on its next `git pull`. Run before every commit.
- **restore** is "rollback" — for each tracked file, find the most recent
  `.bak.<ts>` and copy it back. Useful if a bootstrap broke something.

`./dot` figures out the OS itself (`$OSTYPE` → `mac` / `linux`) and branches
internally. No `bootstrap-mac.sh` / `bootstrap-wsl.sh` to maintain in
parallel anymore.

## How OS-aware gating works

zsh and bash both expose `$OSTYPE` automatically: `darwin23.x` on Mac,
`linux-gnu` on WSL/Ubuntu. We capture it once at the top of `shared/zshrc.common`
(and inside `./dot`) into a normalized `DOTFILES_OS=mac|linux|other`, then
branch on it for the small set of things that legitimately differ:

- `ls -G` (BSD) vs `ls --color=auto` (GNU) — same alias name, different body.
- `du -d 1` (BSD) vs `du --max-depth=1` (GNU) — `bigdirs` alias picks per OS.
- `lsof` (Mac) vs `ss` (Linux) for the claude-mem worker port probe.
- Package manager: `brew install` (Mac) vs `sudo apt-get install` (Linux)
  for the apt/brew prereqs that bootstrap fetches. zsh plugins themselves
  are loaded via zinit from upstream on both OSes — no system copies.
- Skills layout: Mac uses the `~/.agents/skills` + symlink convention
  (cross-tool with Cursor / Copilot / OpenCode), WSL writes directly into
  `~/.claude/skills/`.
- Notification hook: WSL ships a PowerShell toast at `~/.claude/bin/notify-attention.sh`;
  Mac doesn't ship one (cmux handles it). The shared `Notification` hook is
  wrapped `[ -x ... ] && ...` so it silently no-ops without the script.

The same `~/.zshrc` runs on both Mac and WSL — at runtime it picks the
right paths. There is no `mac/zshrc` and no `wsl/zshrc`.

## Cross-OS vs per-machine: the zshrc model

The repo never owns `~/.zshrc`. That file stays owned by the user and the
tool installers that append to it — `brew shellenv`, `nvm install`,
`pyenv init`, `rustup-init`, `bun`, `gcloud install`, `rbenv init`, etc.
That's the only sane way to keep installer-generated lines out of git AND
out of the *other* OS's zshrc.

What the repo does own:

- `shared/zshrc.common` (in repo) → `~/.zshrc.common` (live).
  Cross-OS additions: HISTFILE/setopts, aliases, **zinit + plugin list,
  starship init, fzf keybindings, brew shellenv (Mac-guarded)**, claude-mem
  worker check. These run last so common is the effective configuration
  even if `~/.zshrc` had legacy duplicates. After bootstrap, delete those
  duplicates from `~/.zshrc` to keep one source of truth. Toolchain init
  (pyenv/nvm/bun/rbenv/cargo) and machine-specific PATHs (JDK/Android/
  Flutter/gcloud) stay in `~/.zshrc`.
- A single marker-guarded stub line appended once to `~/.zshrc`:
  ```
  # >>> dotfiles common <<<
  [ -f "$HOME/.zshrc.common" ] && . "$HOME/.zshrc.common"
  ```
  `./dot bootstrap` greps for the marker and only appends if absent.
  Re-running bootstrap is a no-op for `~/.zshrc`.

So `brew install <something>` writing to `~/.zshrc` is fine — those lines
stay machine-local and never leak into the repo.

## Bootstrap prerequisites

Just `claude` — install it first
(<https://docs.claude.com/en/docs/claude-code/setup>) so its initial
interactive auth is out of the way. On Mac you also need `brew`
(<https://brew.sh>) since it's the package manager bootstrap hands work to.

Everything else is auto-installed by `./dot bootstrap` on first run:

- **macOS (brew).** `jq`, `fzf`, `starship`, `git`, `bun` (oven-sh tap),
  `codex`.
- **Linux (apt).** `curl`, `jq`, `fzf`, `git`.
- **Linux (curl-pipe-sh).** `starship` and `bun` — neither ships in stock
  Ubuntu repos, so bootstrap runs their official installers.
- **Cross-OS from source / git.** `zinit`, RTK (`rtk-ai/rtk`), `ccstatusline`
  (built from `main` HEAD).

zsh plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`, `fzf-tab`)
are loaded by zinit directly from upstream on both OSes — bootstrap does
**not** install the apt/brew copies. They were redundant.

## Auto-upgrade ccstatusline

`shared/claude/bin/upgrade-ccstatusline.sh` runs on every `SessionStart`.
It does a quiet `git fetch origin main`; if HEAD is already current, it
exits in a few hundred ms with no rebuild. If upstream advanced, it
ff-merges + rebuilds via `bun install && bun run build`. Build failures
hard-reset to the previous commit so a broken upstream commit never ships
into your live statusline. Logs at `~/.local/state/dotfiles/upgrade-ccstatusline.log`.

To pin ccstatusline (skip auto-upgrade), `touch ~/.config/ccstatusline/upgrade-disabled`.

Claude Code itself updates via its own native auto-updater
(`autoUpdatesChannel: "latest"` in `shared/claude/settings.json`); the repo
no longer pins or patches the CC binary.

## Notes

- **Path placeholder discipline.** Anything read by a non-shell consumer
  (e.g. ccstatusline parsing JSON and feeding `commandPath` straight to
  spawn) MUST use `__HOME__` in `shared/`. Anything Claude Code itself
  evaluates as a shell command (hooks, statusLine.command) can use
  `$HOME` literally. `./dot sync` and `./dot bootstrap` reverse the
  substitution at the boundary.
- **Codex review section** in `shared/claude/CLAUDE.md` is wrapped in
  `<!-- ... -->` until you run `codex login`. Re-enable by removing the
  HTML comment markers.
- **RTK has a known regression** ([issue #582](https://github.com/rtk-ai/rtk/issues/582))
  where over-compression can paradoxically increase token spend. Watch
  your usage in the first day after enabling; revert if it regresses.
- **Codex trusted-projects** are not committed — add per-machine via `codex`
  itself so the repo file stays portable.
- **Mac skills layout** — `~/.agents/skills/<name>` source-of-truth +
  `~/.claude/skills/<name>` symlinks. Community pattern documented at
  <https://www.ssw.com.au/rules/symlink-agents-to-claude/>. Survives switching
  between AI editors that read different roots.
- **hackingtool** (Z4nzu/hackingtool) is **not** auto-installed — install
  manually for authorized pentest engagements only:
  `curl -sSL https://raw.githubusercontent.com/Z4nzu/hackingtool/master/install.sh | sudo bash`.
