#!/usr/bin/env bash
# ccstatusline custom-command: render a tweakcc patches-applied badge.
# Green when the marker version matches `claude --version`, yellow on drift,
# red when the marker is missing.

set -u

MARKER="${HOME}/.tweakcc/.last-applied-cc-version"
TWEAKCC_DIST="${HOME}/.local/share/tweakcc/dist/index.mjs"

# Tracking origin/main, so identify the build by commit short-sha + commit date.
# Fall back to package.json if the repo isn't a git checkout.
TWEAKCC_VER="?"
if [[ -d "${HOME}/.local/share/tweakcc/.git" ]]; then
  TWEAKCC_VER=$(git -C "${HOME}/.local/share/tweakcc" log -1 --format='%h@%cs' 2>/dev/null || echo '?')
elif [[ -f "${HOME}/.local/share/tweakcc/package.json" ]]; then
  TWEAKCC_VER=$(awk -F'"' '/"version":/{print $4; exit}' "${HOME}/.local/share/tweakcc/package.json")
fi

CC_VER=$(claude --version 2>/dev/null | head -1 | awk '{print $1}')
[[ -z "$CC_VER" ]] && exit 0

if [[ ! -f "$MARKER" ]]; then
  printf '\033[31m○ tweakcc unapplied\033[0m'
  exit 0
fi

LAST=$(cat "$MARKER" 2>/dev/null)

if [[ "$LAST" == "$CC_VER" ]]; then
  printf '\033[32m● tweakcc %s\033[0m' "$TWEAKCC_VER"
else
  printf '\033[33m○ tweakcc drift (%s≠%s)\033[0m' "$LAST" "$CC_VER"
fi
