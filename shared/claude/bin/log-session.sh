#!/usr/bin/env bash
# SessionStart hook: append JSONL line to ~/.claude/sessions.log
set -euo pipefail
log="$HOME/.claude/sessions.log"
input=$(cat)
ts=$(date +%s)
jq -c --arg ts "$ts" '{
  ts: ($ts | tonumber),
  sid: .session_id,
  cwd: .cwd,
  source: .source,
  transcript_path: .transcript_path
}' <<<"$input" >> "$log"
