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
backup ~/.claude/codex-review.schema.json    && cp shared/claude/codex-review.schema.json    ~/.claude/codex-review.schema.json
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

# ─── User-level Claude skills (mattpocock pack + locals) ──────────────────────
# Standalone skills in ~/.claude/skills/. mattpocock skills come from upstream;
# graphify and gocomet-fs-ai-part1-reviewer are managed elsewhere and not
# clobbered here.
mkdir -p ~/.claude/skills
mp_tmp=$(mktemp -d)
if git clone --depth 1 https://github.com/mattpocock/skills "$mp_tmp"; then
    for d in "$mp_tmp"/*/; do
        name=$(basename "$d")
        if [[ -f "$d/SKILL.md" && ! -e ~/.claude/skills/"$name" ]]; then
            cp -r "$d" ~/.claude/skills/"$name"
        fi
    done
else
    echo "WARN: mattpocock/skills clone failed — skills not installed. Re-run bootstrap to retry." >&2
fi
rm -rf "$mp_tmp"

# ─── Pinned superpowers fork (auto-update-proof) ──────────────────────────────
# Clones obra/superpowers at v5.0.7 into a temp dir, applies our deletions
# (3 skills + 1 deprecated command), then atomically swaps into place. Skips
# the swap if a healthy clone is already present (origin matches, tag matches,
# expected paths absent). Refuses to nuke a directory it didn't create.
SP_PIN=~/.claude/local-marketplaces/superpowers-pinned
SP_TARGET="$SP_PIN/superpowers"
SP_REMOTE="https://github.com/obra/superpowers"
SP_TAG="v5.0.7"
mkdir -p "$SP_PIN/.claude-plugin"
backup "$SP_PIN/.claude-plugin/marketplace.json" \
    && cp shared/claude/local-marketplaces/superpowers-pinned/.claude-plugin/marketplace.json \
          "$SP_PIN/.claude-plugin/marketplace.json"

sp_pin_is_healthy() {
    [[ -d "$SP_TARGET/.claude-plugin" ]] || return 1
    [[ -d "$SP_TARGET/.git" ]] || return 1
    local origin tag
    origin=$(git -C "$SP_TARGET" config --get remote.origin.url 2>/dev/null || echo "")
    [[ "$origin" == "$SP_REMOTE" || "$origin" == "$SP_REMOTE.git" ]] || return 1
    tag=$(git -C "$SP_TARGET" describe --tags --exact-match 2>/dev/null || echo "")
    [[ "$tag" == "$SP_TAG" ]] || return 1
    [[ ! -e "$SP_TARGET/skills/writing-plans" ]] || return 1
    [[ ! -e "$SP_TARGET/skills/subagent-driven-development" ]] || return 1
    [[ ! -e "$SP_TARGET/skills/test-driven-development" ]] || return 1
    [[ ! -e "$SP_TARGET/commands/write-plan.md" ]] || return 1
    return 0
}

if sp_pin_is_healthy; then
    echo "superpowers-pinned: already healthy at $SP_TAG — skipping rebuild."
else
    sp_stage="$SP_PIN/.staging.$ts"
    rm -rf "$sp_stage"
    if git clone --depth 1 --branch "$SP_TAG" "$SP_REMOTE" "$sp_stage"; then
        rm -rf "$sp_stage/skills/writing-plans" \
               "$sp_stage/skills/subagent-driven-development" \
               "$sp_stage/skills/test-driven-development" \
               "$sp_stage/commands/write-plan.md"
        if [[ -f "$sp_stage/.claude-plugin/plugin.json" ]]; then
            # Atomic-ish swap: pre-stage to a sibling under $SP_PIN (same fs as
            # $SP_TARGET, so each mv is a single rename(2)). On failure of the
            # final move, roll the backup back so the live install never
            # disappears.
            sp_new="$SP_TARGET.new.$ts"
            mv "$sp_stage" "$sp_new"
            if [[ -e "$SP_TARGET" ]]; then
                mv "$SP_TARGET" "$SP_TARGET.bak.$ts"
                if mv "$sp_new" "$SP_TARGET"; then
                    echo "superpowers-pinned: installed $SP_TAG (prior preserved at $SP_TARGET.bak.$ts)."
                else
                    echo "ERR: final swap failed — restoring previous install." >&2
                    mv "$SP_TARGET.bak.$ts" "$SP_TARGET" || \
                        echo "FATAL: rollback also failed — manual recovery needed: $SP_TARGET.bak.$ts and $sp_new" >&2
                    rm -rf "$sp_new"
                    exit 1
                fi
            else
                mv "$sp_new" "$SP_TARGET"
                echo "superpowers-pinned: installed $SP_TAG."
            fi
        else
            echo "ERR: cloned superpowers tree missing .claude-plugin/plugin.json — aborting swap." >&2
            rm -rf "$sp_stage"
            exit 1
        fi
    else
        echo "ERR: superpowers clone failed — pinned plugin not updated." >&2
        rm -rf "$sp_stage"
        exit 1
    fi
fi

echo "bootstrap complete. Existing files backed up with .bak.$ts suffix."
echo
echo "Manual follow-ups (not auto-installed; require sudo or interactive):"
echo "  - hackingtool (pentest engagements only):"
echo "      curl -sSL https://raw.githubusercontent.com/Z4nzu/hackingtool/master/install.sh | sudo bash"
