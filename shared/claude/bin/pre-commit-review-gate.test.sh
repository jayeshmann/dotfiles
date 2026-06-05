#!/usr/bin/env bash
# Regression tests for pre-commit-review-gate.sh
# (PreToolUse:Bash hook: codex pre-commit review gate on `git commit`).
#
# Run:  bash pre-commit-review-gate.test.sh   (exit 0 = all pass, 1 = a failure)
#
# Covers: only `git commit` is gated; --amend and fmt/lockfile/doc subjects are
# skipped; the gate is satisfied once codex pre-commit ran in recent turns.
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pre-commit-review-gate.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

no_codex_tx="$tmp/nocodex.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"staged the diff"}]}}' > "$no_codex_tx"
with_codex_tx="$tmp/withcodex.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bash ~/.claude/bin/codex-precommit.sh"}}]}}' > "$with_codex_tx"

# Run the hook for a Bash command + transcript; echo BLOCK or ALLOW.
verdict() { # command transcript
  local input out
  input=$(jq -nc --arg c "$1" --arg t "$2" '{tool_name:"Bash",tool_input:{command:$c},transcript_path:$t}')
  out=$(printf '%s' "$input" | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"decision": "block"'; then echo BLOCK; else echo ALLOW; fi
}

pass=0 fail=0
check() { # name expected command transcript
  local got; got=$(verdict "$3" "$4")
  if [[ "$got" == "$2" ]]; then pass=$((pass + 1)); printf 'ok   %-26s %s\n' "$1" "$got"
  else fail=$((fail + 1)); printf 'FAIL %-26s got=%s want=%s\n' "$1" "$got" "$2"; fi
}

check non_git_command      ALLOW 'ls -la'                         "$no_codex_tx"
check git_log_not_commit   ALLOW 'git log --oneline -5'           "$no_codex_tx"
check commit_no_codex      BLOCK 'git commit -m "feat: x"'        "$no_codex_tx"
check commit_with_codex    ALLOW 'git commit -m "feat: x"'        "$with_codex_tx"
check commit_amend_skip    ALLOW 'git commit --amend --no-edit'   "$no_codex_tx"
check commit_fmt_skip      ALLOW 'git commit -m "fmt: reformat"'  "$no_codex_tx"
check commit_dashC_nocodex BLOCK 'git -C /repo commit -m "x"'     "$no_codex_tx"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
