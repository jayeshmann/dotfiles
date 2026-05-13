#!/usr/bin/env bash
# Stop hook: gate options-presentation behind codex review.
#
# Fires when Claude finishes generating an assistant message. If that message
# presents labeled options (Option A/B/C ...) AND a recommendation, but the
# turn did NOT include a codex options-review invocation, the hook blocks the
# turn and forces Claude to run codex before presenting again.
#
# Per ~/.claude/CLAUDE.md "External code review (Codex)" / "Options review
# (pre-implementation)".
#
# Fails open on any unexpected error — never accidentally blocks.

set -uo pipefail

# Read hook input JSON from stdin
input=$(cat || true)

transcript_path=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null || true)
stop_hook_active=$(jq -r '.stop_hook_active // false' <<<"$input" 2>/dev/null || echo false)

# Avoid recursion: if a previous Stop hook already fired this turn, bail.
if [[ "$stop_hook_active" == "true" ]]; then
  exit 0
fi

# Bail if no transcript available
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
  exit 0
fi

# Pull the LAST assistant message's text content
last_text=$(jq -rs '
  map(select(.type=="assistant"))
  | last
  | (.message.content // [])
  | if type=="array"
    then map(select(.type=="text") | .text) | join("\n")
    else (. | tostring)
    end
' "$transcript_path" 2>/dev/null || true)

if [[ -z "$last_text" ]]; then
  exit 0
fi

# Detect options-presentation pattern.
# Conservative: needs at least 2 labeled options AND recommendation language.
# Matches: ### Option A: (CLAUDE.md doc format), **Option A**, **(A)**, - **(A)**,
# - **Option A**, leading "Option A " at line start.
options_count=$(printf '%s' "$last_text" | grep -cE '(^#{1,6}[[:space:]]+Option [A-Z]\b|\*\*Option [A-Z]\b|\*\*\([A-Z]\)\*\*|^- \*\*\([A-Z]\)|^- \*\*Option [A-Z]|^Option [A-Z]\b)' 2>/dev/null || echo 0)
# Matches: "My recommendation:", "Claude'"'"'s recommendation", "I'"'"'d pick/recommend/go with",
# heading forms like "## Recommendation" / "### Claude'"'"'s recommendation",
# and "Recommendation:" / "Recommended:" line starters.
recommend_hits=$(printf '%s' "$last_text" | grep -cE "(My recommendation\b|I.d (pick|recommend|go with)|Claude.s recommendation\b|^#{1,6}[[:space:]]+(Claude.s )?[Rr]ecommendation\b|^[Rr]ecommendation:|^[Rr]ecommended:)" 2>/dev/null || echo 0)

if [[ "$options_count" -lt 2 || "$recommend_hits" -lt 1 ]]; then
  exit 0
fi

# Check the last few assistant turns for a codex options-review Bash call.
codex_called=$(jq -rs '
  map(select(.type=="assistant"))
  | reverse
  | .[0:5]
  | map(.message.content // [])
  | flatten
  | map(select(.type=="tool_use" and .name=="Bash"))
  | map(.input.command // "")
  | map(select(test("codex.*--output-schema.*codex-options-review\\.schema\\.json")))
  | length
' "$transcript_path" 2>/dev/null || echo 0)

if [[ "$codex_called" -gt 0 ]]; then
  exit 0
fi

# Gate: block the turn and instruct Claude to run codex options-review first.
jq -n '{
  decision: "block",
  reason: "Options-review gate: your last message presents options and a recommendation, but no codex options-review ran in this turn. Per ~/.claude/CLAUDE.md (External code review (Codex) > Options review (pre-implementation)): write your options to /tmp/claude-options.md using the documented schema, run codex exec --sandbox read-only --skip-git-repo-check --output-schema ~/.claude/codex-options-review.schema.json -o /tmp/codex-options.json on it, then present BOTH analyses (yours and codex'"'"'s verdict / recommendation / missed-concerns) in the same response. Skip only when the user has already picked the option, or the choice is purely cosmetic (naming, formatter style). If you believe this trigger is a false positive (e.g., recap of a past comparison), say so explicitly in your retry."
}'
