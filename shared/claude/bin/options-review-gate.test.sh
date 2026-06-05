#!/usr/bin/env bash
# Regression tests for options-review-gate.sh (Stop hook: codex second-opinion gate).
#
# Run:  bash options-review-gate.test.sh   (exit 0 = all pass, 1 = a failure)
#
# Guards against:
#   - the `grep -c` "0\n0" count bug that made the guard raise a [[ ]] syntax
#     error and spuriously BLOCK ordinary turns (fixed via count_matches).
#   - regressions in the gate trigger: (>=2 labeled options AND a pick) OR a
#     strong standalone recommendation, with casual inline recs excluded.
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/options-review-gate.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# An assistant text message as one JSONL record. Literal \n in $1 become JSON
# string escapes, which jq turns into real newlines so ^ anchors can match.
asst() { printf '{"type":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}' "$1"; }
# A prior assistant turn that invoked codex second-opinion (simulates "already
# reviewed this turn" -> the gate must NOT block).
codex_call='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bash ~/.claude/bin/codex-second-opinion.sh"}}]}}'

# Run the hook against a transcript string; echo BLOCK or ALLOW.
verdict() {
  local f="$tmp/tx.jsonl" out
  printf '%s\n' "$1" > "$f"
  out=$(printf '{"transcript_path":"%s","stop_hook_active":false}' "$f" | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"decision": "block"'; then echo BLOCK; else echo ALLOW; fi
}

pass=0 fail=0
check() { # name expected transcript
  local got; got=$(verdict "$3")
  if [[ "$got" == "$2" ]]; then pass=$((pass + 1)); printf 'ok   %-24s %s\n' "$1" "$got"
  else fail=$((fail + 1)); printf 'FAIL %-24s got=%s want=%s\n' "$1" "$got" "$2"; fi
}

# Plain message, nothing to gate -> ALLOW. (The count bug used to BLOCK this.)
check plain               ALLOW "$(asst 'Here is a normal answer. No options, no recommendation.')"
# >=2 labeled options + a pick, no codex -> BLOCK.
check options_nocodex     BLOCK "$(asst '## Option A\nDo X.\n## Option B\nDo Y.\n\nMy recommendation: Option A.')"
# Same, but codex already ran this turn -> ALLOW (downstream check preserved).
check options_withcodex   ALLOW "$(printf '%s\n%s' "$codex_call" "$(asst '## Option A\nDo X.\n## Option B\nDo Y.\n\nMy recommendation: Option A.')")"
# Standalone recommendation heading, no options, no codex -> BLOCK (new coverage).
check standalone_heading  BLOCK "$(asst 'I weighed the two schemas.\n\n## Recommendation\nUse the normalized schema.')"
# Bold standalone recommendation label, no codex -> BLOCK.
check standalone_bold     BLOCK "$(asst 'Analysis above.\n\n**Recommendation:** ship the smaller migration first.')"
# Plain "My take:" line-start label, no codex -> BLOCK.
check mytake_label        BLOCK "$(asst 'Compared both.\n\nMy take: ship the smaller migration first.')"
# Casual inline recommendation, no structure -> ALLOW (high precision).
check inline_casual       ALLOW "$(asst 'Tests pass. I recommend committing now and moving on.')"
# Casual "My take" mid-sentence (no colon label) -> ALLOW.
check take_casual         ALLOW "$(asst 'My take on lunch is we should take a break. No strong view.')"
# Standalone recommendation WITH codex already run -> ALLOW.
check standalone_withcodex ALLOW "$(printf '%s\n%s' "$codex_call" "$(asst 'Analysis.\n\n## Recommendation\nUse the normalized schema.')")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
