#!/usr/bin/env bash
# Tests for shared/claude/bin/ctx-pct-colored.sh — the Claude Code context-%
# statusline widget. Runs inline fixtures through the script and asserts on
# the stripped-of-ANSI output. Each case captures a specific regression we
# hit while making the widget robust against resumed sessions and malformed
# JSONL transcripts.
#
# Run locally:  bash tests/ctx-pct-colored.test.sh
# CI:           see .github/workflows/test.yml

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/shared/claude/bin/ctx-pct-colored.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to run these tests" >&2
  exit 2
fi
if [[ ! -f "$SCRIPT" ]]; then
  echo "script under test not found: $SCRIPT" >&2
  exit 2
fi

TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

# Run the widget against a transcript path. $2 is the model id; default is
# the 1M-context Opus variant Jay runs (uses an 800k usable denominator).
# ANSI strip uses awk with octal \033 so the test runs on both GNU and BSD
# userlands (macOS sed doesn't recognise `\x1b` in BRE).
run_widget() {
  local transcript="$1"
  local model_id="${2:-claude-opus-4-7[1m]}"
  printf '{"transcript_path":"%s","model":{"id":"%s"}}' "$transcript" "$model_id" \
    | bash "$SCRIPT" \
    | awk '{ gsub(/\033\[[0-9;]*m/, ""); printf "%s", $0 }'
}

assert_eq() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf '  PASS  %-30s → %s\n' "$name" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %-30s → got %q, expected %q\n' "$name" "$actual" "$expected"
    FAILED_CASES+=("$name")
    FAIL=$((FAIL + 1))
  fi
}

# Emit a single assistant usage JSONL line. Args: ts, isSidechain, total_tokens.
# Total goes into cache_read_input_tokens so input_tokens=0 keeps the math
# clean (no off-by-one rounding noise in assertions).
entry() {
  local ts="$1" sc="$2" tokens="$3"
  printf '{"isSidechain":%s,"type":"assistant","timestamp":"%s","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":0,"cache_read_input_tokens":%d,"cache_creation_input_tokens":0,"output_tokens":50}}}\n' \
    "$sc" "$ts" "$tokens"
}

echo "== ctx-pct-colored.sh =="

# 1) Missing transcript file → 0.0% (graceful fallback, never errors out).
assert_eq "missing-transcript" \
  "$(run_widget "$TMP/does-not-exist.jsonl")" "0.0%"

# 2) Empty transcript file → 0.0%.
: > "$TMP/empty.jsonl"
assert_eq "empty-transcript" \
  "$(run_widget "$TMP/empty.jsonl")" "0.0%"

# 3) Single main-chain entry, 80000 tokens → 80000/800000 = 10.0%.
entry "2026-05-01T00:00:00.000Z" false 80000 > "$TMP/single.jsonl"
assert_eq "single-entry" \
  "$(run_widget "$TMP/single.jsonl")" "10.0%"

# 4) Out-of-order: newer entry appears EARLIER in file order than a stale
# row. max_by(.timestamp) must pick the newer row. Old tail-based logic
# picked the stale row (this was the original "stuck on resume" symptom).
{ entry "2026-05-13T11:30:00.000Z" false 40000;
  entry "2026-05-13T11:00:00.000Z" false 999999; } > "$TMP/out-of-order.jsonl"
assert_eq "out-of-order-tail" \
  "$(run_widget "$TMP/out-of-order.jsonl")" "5.0%"

# 5) Sidechain entries (subagent traffic) must NOT contribute to main-chain
# context, even when they have a later timestamp and far more tokens.
{ entry "2026-05-13T12:00:00.000Z" false 40000;
  entry "2026-05-13T13:00:00.000Z" true  700000; } > "$TMP/sidechain.jsonl"
assert_eq "sidechain-rejected" \
  "$(run_widget "$TMP/sidechain.jsonl")" "5.0%"

# 6) A malformed JSONL row must not abort the read — per-line try/fromjson
# must skip it so entries after the bad line still count. This is what
# caused the symfoamp transcript to "stick" at a stale value: jq -c aborts
# at the first parse error and silently drops every entry that follows.
{ entry "2026-05-13T11:00:00.000Z" false 100000;
  printf 'GARBAGE NOT JSON {{{ broken\n';
  entry "2026-05-13T11:30:00.000Z" false 480000; } > "$TMP/malformed.jsonl"
assert_eq "malformed-line-survives" \
  "$(run_widget "$TMP/malformed.jsonl")" "60.0%"

# 7) 200k-context model uses a 160k usable denominator (no [1m] suffix).
entry "2026-05-13T11:00:00.000Z" false 40000 > "$TMP/200k.jsonl"
assert_eq "200k-context-window" \
  "$(run_widget "$TMP/200k.jsonl" "claude-sonnet-4-5")" "25.0%"

echo
if (( FAIL > 0 )); then
  printf 'FAIL  %d passed, %d failed: %s\n' "$PASS" "$FAIL" "${FAILED_CASES[*]}"
  exit 1
fi
printf 'OK    %d passed\n' "$PASS"
