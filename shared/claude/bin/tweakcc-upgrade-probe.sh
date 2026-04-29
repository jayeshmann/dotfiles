#!/usr/bin/env bash
# Periodically (~every 3 days) check for newer Claude Code versions and
# tweakcc commits. Probe whether the latest CC is compatible with the current
# tweakcc; if yes, upgrade and switch. If no, keep the pinned CC version but
# still pull and rebuild tweakcc so prompt-only fixes ship.
#
# Strategy:
#   1. Stamp-gate: skip if last successful run was less than INTERVAL_DAYS ago.
#   2. Pull tweakcc origin/main; rebuild dist if any new commits.
#   3. Walk CC versions newest -> current; for each candidate above current,
#      install (if not already on disk), then probe in an isolated temp env
#      (TWEAKCC_CONFIG_DIR + temp PATH) by running tweakcc --apply against a
#      mocked "claude on PATH" pointing at the candidate binary. Compatibility
#      is decided by whether `Patches applied indication` reports ✓ in the
#      probe log — that's the patch family that breaks first when CC's React
#      output reshapes.
#   4. On a hit: switch the symlink, bump minimumVersion in settings.json,
#      force tweakcc-reapply against the live target.
#   5. On no hit: if tweakcc itself was updated, reapply against the existing
#      CC version anyway.
#
# Concurrency: flocks against parallel SessionStart hooks. The probe runs
# tweakcc against an isolated config dir so it does not perturb the user's
# real ~/.tweakcc state.

set -uo pipefail

INTERVAL_DAYS=3
TWEAKCC_REPO="${HOME}/.local/share/tweakcc"
TWEAKCC_DIST="${TWEAKCC_REPO}/dist/index.mjs"
TWEAKCC_HOME="${HOME}/.tweakcc"
MARKER="${TWEAKCC_HOME}/.last-applied-cc-version"
STAMP="${TWEAKCC_HOME}/.upgrade-probe-stamp"
LOCK="${TWEAKCC_HOME}/upgrade-probe.lock"
LOG="${TWEAKCC_HOME}/upgrade-probe.log"
SETTINGS="${HOME}/.claude/settings.json"
CLAUDE_BIN="${HOME}/.local/bin/claude"
CLAUDE_VERSIONS_DIR="${HOME}/.local/share/claude/versions"
REAPPLY_SCRIPT="${HOME}/.claude/bin/tweakcc-reapply.sh"

force=false
[[ "${1:-}" == "--force" ]] && force=true

[[ -f "$TWEAKCC_DIST" ]] || exit 0
mkdir -p "$TWEAKCC_HOME"

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG"; }

reapply() {
  if [[ -x "$REAPPLY_SCRIPT" ]]; then
    "$REAPPLY_SCRIPT" || log "reapply hook returned non-zero"
  fi
}
export -f log reapply

(
  exec 9>"$LOCK"
  if ! flock -n 9; then
    exit 0
  fi

  # Stamp gate
  if ! $force && [[ -f "$STAMP" ]]; then
    age=$(( $(date +%s) - $(date -r "$STAMP" +%s) ))
    if (( age < INTERVAL_DAYS * 86400 )); then
      exit 0
    fi
  fi

  log "=== probe start (force=$force) ==="

  # 1. Update tweakcc from origin/main
  tweakcc_changed=false
  old_sha=$(git -C "$TWEAKCC_REPO" rev-parse HEAD 2>/dev/null || echo none)
  if git -C "$TWEAKCC_REPO" fetch --quiet origin main >>"$LOG" 2>&1; then
    new_sha=$(git -C "$TWEAKCC_REPO" rev-parse origin/main)
    if [[ "$old_sha" != "$new_sha" ]]; then
      log "tweakcc: $old_sha -> $new_sha"
      if git -C "$TWEAKCC_REPO" merge --ff-only origin/main >>"$LOG" 2>&1; then
        build_ok=false
        if command -v bun >/dev/null 2>&1; then
          ( cd "$TWEAKCC_REPO" && bun install && bun run build ) >>"$LOG" 2>&1 && build_ok=true
        fi
        if ! $build_ok; then
          ( cd "$TWEAKCC_REPO" && npm install && npm run build ) >>"$LOG" 2>&1 && build_ok=true
        fi
        if $build_ok; then
          tweakcc_changed=true
          log "tweakcc rebuilt"
        else
          log "tweakcc rebuild FAILED, dist may be stale"
        fi
      else
        log "tweakcc ff-merge failed (local commits?); skipping rebuild"
      fi
    fi
  else
    log "tweakcc fetch failed (network?)"
  fi

  # 2. Detect candidate CC versions newer than current
  current_cc=$(claude --version 2>/dev/null | head -1 | awk '{print $1}')
  if [[ -z "$current_cc" ]]; then
    log "could not read current CC version"
    date +%s > "$STAMP"
    exit 0
  fi

  versions_json=$(npm view @anthropic-ai/claude-code versions --json 2>/dev/null || echo '')
  if [[ -z "$versions_json" ]]; then
    log "npm view failed; cannot enumerate CC versions"
    $tweakcc_changed && reapply
    date +%s > "$STAMP"
    exit 0
  fi

  # Newest-first list of versions strictly greater than current_cc
  candidates=$(jq -r '.[]' <<<"$versions_json" \
    | sort -V \
    | awk -v cur="$current_cc" '
        function vgt(a,b,   pa,pb,i,n) {
          n=split(a,pa,"."); split(b,pb,".")
          for(i=1;i<=n;i++) {
            if((pa[i]+0) > (pb[i]+0)) return 1
            if((pa[i]+0) < (pb[i]+0)) return 0
          }
          return 0
        }
        vgt($0, cur) {print}
      ' \
    | tac)

  if [[ -z "$candidates" ]]; then
    log "no CC versions newer than $current_cc"
    $tweakcc_changed && reapply
    date +%s > "$STAMP"
    log "=== probe done (no upgrade candidates) ==="
    exit 0
  fi

  # 3. Probe candidates newest-first; cap at 5 to bound work per run
  upgrade_target=""
  attempts=0
  for v in $candidates; do
    (( attempts++ ))
    (( attempts > 5 )) && break

    log "probing CC $v"
    candidate_bin="${CLAUDE_VERSIONS_DIR}/${v}"

    # Install if not on disk. claude install moves the symlink — we capture
    # and restore it so the probe never destabilises the live env.
    if [[ ! -f "$candidate_bin" ]]; then
      saved_link=$(readlink "$CLAUDE_BIN")
      log "installing CC $v"
      if ! DISABLE_AUTOUPDATER=0 claude install "$v" >>"$LOG" 2>&1; then
        log "install failed for $v"
        ln -sf "$saved_link" "$CLAUDE_BIN"
        continue
      fi
      ln -sf "$saved_link" "$CLAUDE_BIN"
      log "restored symlink to $saved_link"
    fi

    # Probe in isolation
    probe_dir=$(mktemp -d)
    ln -s "$candidate_bin" "$probe_dir/claude"
    mkdir "$probe_dir/tcc"
    cp "$TWEAKCC_HOME/config.json" "$probe_dir/tcc/config.json"

    PATH="$probe_dir:$PATH" TWEAKCC_CONFIG_DIR="$probe_dir/tcc" \
      node "$TWEAKCC_DIST" --apply >"$probe_dir/probe.log" 2>&1 || true

    if grep -qE '✓ Patches applied indication' "$probe_dir/probe.log"; then
      log "compatible: CC $v"
      upgrade_target="$v"
      rm -rf "$probe_dir"
      break
    else
      log "incompatible: CC $v"
      grep -E '✗|patch:.*failed' "$probe_dir/probe.log" | head -10 >>"$LOG" || true
    fi
    rm -rf "$probe_dir"
  done

  # 4. Apply outcome
  if [[ -n "$upgrade_target" ]]; then
    log "upgrading CC: $current_cc -> $upgrade_target"
    ln -sf "${CLAUDE_VERSIONS_DIR}/${upgrade_target}" "$CLAUDE_BIN"

    if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null; then
      tmp=$(mktemp)
      if jq --arg v "$upgrade_target" '.minimumVersion = $v' "$SETTINGS" > "$tmp"; then
        mv "$tmp" "$SETTINGS"
        log "bumped settings.json minimumVersion to $upgrade_target"
      else
        rm -f "$tmp"
        log "failed to update settings.json"
      fi
    fi

    rm -f "$MARKER"
    reapply
  elif $tweakcc_changed; then
    log "no compatible CC upgrade; reapplying updated tweakcc against current $current_cc"
    rm -f "$MARKER"
    reapply
  else
    log "nothing to do (CC $current_cc unchanged, no newer compatible version)"
  fi

  date +%s > "$STAMP"
  log "=== probe done ==="
)
