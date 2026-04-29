#!/usr/bin/env bash
# Push repo configs to live WSL paths. Order is deliberate:
#   1. Validate prerequisites (bun, git, claude).
#   2. Clone+build ccstatusline and tweakcc into staging paths.
#   3. Apply tweakcc patches to the live Claude install.
#   4. Only after the above succeeds, back up and replace live config.
#   5. Refresh mattpocock skills last (idempotent + recoverable).
#
# This ordering means a failure in step 1-3 leaves the live Claude
# config untouched. Existing files replaced in step 4 are backed up to
# `*.bak.<ts>` so each individual swap can be hand-rolled back.
set -euo pipefail
cd "$(dirname "$0")"

ts=$(date +%s)
backup() { [[ -e "$1" ]] && cp "$1" "$1.bak.$ts" || true; }

# ─── 1. Prerequisites ─────────────────────────────────────────────────────────
for cmd in bun git claude; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERR: $cmd not installed — install before running bootstrap." >&2
        exit 1
    fi
done

mkdir -p ~/.claude/bin ~/.config/ccstatusline ~/.codex ~/.hermes ~/.local/bin \
         ~/.tweakcc ~/.local/share ~/.local/state/dotfiles

# ─── 2. Build ccstatusline (main HEAD) ────────────────────────────────────────
# Built locally because main HEAD ships features ahead of the npm release
# (native xhigh thinking-effort support, jj VCS widgets, compaction-counter,
# Context Window widget). Pinning to a built artifact also avoids a remote
# refetch on every statusline tick.
ccs=~/.local/share/ccstatusline
if [[ ! -d "$ccs/.git" ]]; then
    git clone https://github.com/sirmalloc/ccstatusline "$ccs"
else
    git -C "$ccs" pull --ff-only
fi
(cd "$ccs" && bun install && bun run build)
[[ -f "$ccs/dist/ccstatusline.js" ]] || {
    echo "ERR: ccstatusline build did not produce dist/ccstatusline.js — aborting." >&2
    exit 1
}

# ─── 3. Build tweakcc (main HEAD) ─────────────────────────────────────────────
# Same rationale: main HEAD has CC 2.1.122-era prompt patches not yet in v4.0.11.
tcc=~/.local/share/tweakcc
if [[ ! -d "$tcc/.git" ]]; then
    git clone https://github.com/Piebald-AI/tweakcc "$tcc"
else
    git -C "$tcc" pull --ff-only
fi
(cd "$tcc" && bun install && bun run build)
[[ -f "$tcc/dist/index.mjs" ]] || {
    echo "ERR: tweakcc build did not produce dist/index.mjs — aborting." >&2
    exit 1
}

# tweakcc config must exist before --apply; ship it before patching CC.
backup ~/.tweakcc/config.json && cp shared/tweakcc/config.json ~/.tweakcc/config.json

# Apply tweakcc to live Claude under the SAME flock the SessionStart
# reapply hook uses, so a hook firing mid-bootstrap can't race two
# concurrent --apply processes against the same Claude install.
# Marker is written via temp+mv only on success, matching the hook.
(
    exec 9>~/.tweakcc/reapply.lock
    flock 9
    if node "$tcc/dist/index.mjs" --apply; then
        cc_ver=$(claude --version | awk '{print $1}')
        tmp=$(mktemp ~/.tweakcc/.last-applied-cc-version.XXXXXX)
        printf '%s' "$cc_ver" > "$tmp"
        mv "$tmp" ~/.tweakcc/.last-applied-cc-version
    else
        echo "WARN: tweakcc --apply had failures — marker NOT advanced; SessionStart hook will retry." >&2
    fi
)

# ─── 4. Replace live Claude/zsh/codex/hermes config ───────────────────────────
backup ~/.zshrc                              && cp shared/zshrc                              ~/.zshrc
backup ~/.claude/settings.json               && cp shared/claude/settings.json               ~/.claude/settings.json
backup ~/.claude/CLAUDE.md                   && cp shared/claude/CLAUDE.md                   ~/.claude/CLAUDE.md
backup ~/.claude/codex-review.schema.json    && cp shared/claude/codex-review.schema.json    ~/.claude/codex-review.schema.json
backup ~/.claude/bin/ctx-pct-colored.sh      && cp shared/claude/bin/ctx-pct-colored.sh      ~/.claude/bin/
backup ~/.claude/bin/log-session.sh          && cp shared/claude/bin/log-session.sh          ~/.claude/bin/
backup ~/.claude/bin/tweakcc-reapply.sh      && cp shared/claude/bin/tweakcc-reapply.sh      ~/.claude/bin/
backup ~/.claude/bin/dotfiles-autosync.sh    && cp shared/claude/bin/dotfiles-autosync.sh    ~/.claude/bin/
backup ~/.config/ccstatusline/settings.json  && cp shared/ccstatusline/settings.json         ~/.config/ccstatusline/settings.json
backup ~/.codex/config.toml                  && cp shared/codex/config.toml                  ~/.codex/config.toml
backup ~/.hermes/config.yaml                 && cp shared/hermes/config.yaml                 ~/.hermes/config.yaml
backup ~/.local/bin/csess                    && cp shared/bin/csess                          ~/.local/bin/csess
backup /mnt/c/Users/jay/.wezterm.lua         && cp wsl/wezterm.lua                           /mnt/c/Users/jay/.wezterm.lua
backup ~/.claude/bin/notify-attention.sh     && cp wsl/claude-bin/notify-attention.sh        ~/.claude/bin/notify-attention.sh

chmod +x ~/.claude/bin/*.sh ~/.local/bin/csess

# ─── 5. mattpocock skills (idempotent refresh) ────────────────────────────────
# Pulls every directory under skills/{engineering,productivity,misc} from
# mattpocock/skills main. Existing entries are overwritten so deprecations
# upstream propagate. graphify and gocomet-fs-ai-part1-reviewer are managed
# separately and not touched here.
mkdir -p ~/.claude/skills
mp_tmp=$(mktemp -d)
if git clone --depth 1 https://github.com/mattpocock/skills "$mp_tmp"; then
    for category in engineering productivity misc; do
        for d in "$mp_tmp/skills/$category"/*/; do
            [[ -d "$d" ]] || continue
            name=$(basename "$d")
            rm -rf ~/.claude/skills/"$name"
            cp -r "$d" ~/.claude/skills/"$name"
        done
    done
else
    echo "WARN: mattpocock/skills clone failed — skills not refreshed. Re-run bootstrap to retry." >&2
fi
rm -rf "$mp_tmp"

echo "bootstrap complete. Existing files backed up with .bak.$ts suffix."
echo
echo "Manual follow-ups (not auto-installed; require sudo or interactive):"
echo "  - hackingtool (pentest engagements only):"
echo "      curl -sSL https://raw.githubusercontent.com/Z4nzu/hackingtool/master/install.sh | sudo bash"
