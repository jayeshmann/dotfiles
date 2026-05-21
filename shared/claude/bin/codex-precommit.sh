#!/usr/bin/env bash
# Pre-commit codex review. Bundles the active Claude Code session
# transcript (recent only, tail-capped) + the staged diff, pipes to
# codex, writes verdict JSON to /tmp/codex-review.json and stdout.
#
# Sizing:
# - 450KB cap (~180k tokens at observed ~2.4 chars/token JSONL density)
#   sized to gpt-5.5's 272k context window (~258k effective at 95%) so
#   the bundle leaves room for codex's base prompt (~6k), AGENTS.md
#   auto-load (~5-10k), the diff (up to ~20k), reasoning CoT (~30k),
#   and the JSON verdict (~5k). Most recent context wins.
# - If no recent session is found, codex falls back to diff-only review.
#
# Constraints (per ~/.claude/CLAUDE.md "External code review (Codex)"):
# - Use `codex exec`, not `codex review`; only exec supports --output-schema.
# - Never --dangerously-bypass-approvals-and-sandbox for review; read-only.
# - Codex auto-loads AGENTS.md from cwd; do not cat it into the prompt.
set -euo pipefail

project_dir="$HOME/.claude/projects/$(pwd | sed 's|[/.]|-|g')"
session_jsonl=$(find "$project_dir" -maxdepth 1 -name '*.jsonl' -mmin -60 \
  -exec ls -t {} + 2>/dev/null | head -1 || true)

{
  echo "=== CONVERSATION ==="
  if [[ -f "$session_jsonl" ]]; then
    bytes=$(wc -c < "$session_jsonl")
    if (( bytes > 450000 )); then
      echo "(truncated: showing tail ~450KB of ${bytes}-byte transcript)"
      tail -c 450000 "$session_jsonl" | tail -n +2
    else
      cat "$session_jsonl"
    fi
  else
    echo "(no Claude Code session transcript at $project_dir)"
  fi
  echo ""
  echo "=== DIFF ==="
  git diff --cached
} | codex exec \
  --sandbox read-only \
  --output-schema "$HOME/.claude/codex-review.schema.json" \
  -o /tmp/codex-review.json \
  "Review the staged change against this repo's AGENTS.md
   (auto-loaded from cwd). The <stdin> bundle has two blocks:
   === CONVERSATION === (full Claude Code session transcript so
   you can see the original ask, the reasoning, and any prior
   corrections; judge intent vs. implementation) and === DIFF ===
   (the staged changes).

   Beyond the diff itself, scan the broader codebase for:
     - codebase-mismatch: callers/imports/refs of renamed or
       removed symbols that weren't updated, signature changes
       whose call sites still pass the old shape, schema/contract
       drift between producer and consumer.
     - dead-code-introduced: functions / imports / files / config
       keys / feature flags this diff has just made unused.
     - related-issue: pre-existing bugs or smells in code adjacent
       to the diff that the diff brushes against and should
       arguably fix or flag.

   Apply the project's stated review priorities. Return JSON per
   schema: verdict APPROVED|REVISE, plus critical findings (use
   the new categories where appropriate) and nits."

cat /tmp/codex-review.json
