#!/usr/bin/env bash
# PreToolUse:Bash hook: gate `git commit` behind codex pre-commit review.
#
# Intercepts Bash tool calls before they run. If the command is a `git commit`
# and no codex pre-commit review ran in recent turns, blocks the tool and
# instructs Claude to run codex first.
#
# Per ~/.claude/CLAUDE.md "External code review (Codex)" / "Per-commit workflow".
#
# Fails open on any unexpected error — never accidentally blocks.

set -uo pipefail

input=$(cat || true)

tool_name=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null || true)
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

command_str=$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null || true)
if [[ -z "$command_str" ]]; then
  exit 0
fi

# Match `git commit` (also `git -c ... commit`, `git -C dir commit`).
# Not: `git log`, `git diff`, `git show`, `git revert`, `git cherry-pick`.
if ! printf '%s' "$command_str" | grep -qE '(^|[[:space:]&|;])git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Skip only when --amend is present: per ~/.claude/CLAUDE.md "Workflow", amends
# are only used when the user has explicitly authorized them, so the user has
# already accepted the bypass. All other variants of `git commit` (including
# --no-edit alone, --allow-empty with staged content) still need codex review.
if printf '%s' "$command_str" | grep -qE '\-\-amend\b'; then
  exit 0
fi

# Skip pure-formatter / lockfile / doc-typo commits per CLAUDE.md "Skip codex for"
# Heuristic: subject line starts with "fmt:" / "format:" / "docs(typo):" / "chore(lockfile):"
subject=$(printf '%s' "$command_str" | grep -oE '\-m[[:space:]]+["'\'']?[^"'\'']+' | head -1 || true)
if printf '%s' "$subject" | grep -qiE '^\-m[[:space:]]+["'\'']?(fmt|format|docs\(typo\)|chore\(lockfile\))'; then
  exit 0
fi

transcript_path=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null || true)
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
  exit 0
fi

# Look for a codex pre-commit invocation in the last several assistant turns.
codex_called=$(jq -rs '
  map(select(.type=="assistant"))
  | reverse
  | .[0:30]
  | map(.message.content // [])
  | flatten
  | map(select(.type=="tool_use" and .name=="Bash"))
  | map(.input.command // "")
  | map(select(
      (test("codex[ \\\\\\n]+exec"; "s") and contains("codex-review.schema.json"))
      or contains("codex-precommit.sh")
    ))
  | length
' "$transcript_path" 2>/dev/null || echo 0)

if [[ "$codex_called" -gt 0 ]]; then
  exit 0
fi

# Block the commit and explain.
jq -n '{
  decision: "block",
  reason: "Pre-commit codex review gate: you are about to run `git commit` without having run codex pre-commit review in recent turns. Per ~/.claude/CLAUDE.md (External code review (Codex) > Per-commit workflow): self-review the staged diff, then run `~/.claude/bin/codex-precommit.sh` (it bundles the session transcript + git diff --cached, calls codex with the schema, and writes the verdict to /tmp/codex-review.json). Triage the JSON verdict (APPROVED commits; REVISE means fix real issues). Hard cap of 2 round-trips. Skip ONLY for: pure-formatter commits (make fmt-only), lockfile bumps with no code changes, non-runbook doc typo fixes, or generated-file-only commits whose source change you already pushed through review. If skip applies, say so in your retry and commit again."
}'
