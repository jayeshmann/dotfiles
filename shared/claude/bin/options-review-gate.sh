#!/usr/bin/env bash
# Stop hook: gate options-presentation behind codex second-opinion review.
#
# Fires when Claude finishes generating an assistant message. If that message
# presents labeled options (Option/Approach/Path/Plan/Strategy A/B/1/2 ...)
# AND a recommendation, but the turn did NOT include a codex second-opinion
# invocation, the hook blocks the turn and forces Claude to run codex before
# presenting again.
#
# Conservative by design: only catches the labeled-options-plus-pick pattern,
# the case most often forgotten. Broader cases (single recommendation,
# design judgment, technical answer) are Claude's responsibility under
# CLAUDE.md but not auto-gated here — auto-gating every recommendation
# would be too noisy.
#
# Per ~/.claude/CLAUDE.md "External code review (Codex)" /
# "Second-opinion review (pre-action)".
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
# Labels: Option|Approach|Path|Plan|Strategy followed by [A-Z] or [0-9]+
# (e.g. "Option A", "Approach 1", "Path B", "Plan 2").
# Forms: ### <Label> X: (heading), **<Label> X**, **(X)**, - **(X)**,
# - **<Label> X**, leading "<Label> X " at line start.
options_count=$(printf '%s' "$last_text" | grep -cE '(^#{1,6}[[:space:]]+(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)\b|\*\*(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)\b|\*\*\(([A-Z]|[0-9]+)\)\*\*|^- \*\*\(([A-Z]|[0-9]+)\)|^- \*\*(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)|^(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)\b)' 2>/dev/null || echo 0)
# Matches: "My recommendation:", "Claude'"'"'s recommendation", "I'"'"'d pick/recommend/go with",
# heading forms like "## Recommendation" / "### Claude'"'"'s recommendation",
# and "Recommendation:" / "Recommended:" line starters.
recommend_hits=$(printf '%s' "$last_text" | grep -cE "(My recommendation\b|I.d (pick|recommend|go with)|Claude.s recommendation\b|^#{1,6}[[:space:]]+(Claude.s )?[Rr]ecommendation\b|^[Rr]ecommendation:|^[Rr]ecommended:)" 2>/dev/null || echo 0)

if [[ "$options_count" -lt 2 || "$recommend_hits" -lt 1 ]]; then
  exit 0
fi

# Check the last few assistant turns for a codex second-opinion Bash call.
codex_called=$(jq -rs '
  map(select(.type=="assistant"))
  | reverse
  | .[0:20]
  | map(.message.content // [])
  | flatten
  | map(select(.type=="tool_use" and .name=="Bash"))
  | map(.input.command // "")
  | map(select(
      (test("codex[ \\\\\\n]+exec"; "s") and contains("codex-options-review.schema.json"))
      or contains("codex-second-opinion.sh")
    ))
  | length
' "$transcript_path" 2>/dev/null || echo 0)

if [[ "$codex_called" -gt 0 ]]; then
  exit 0
fi

# Gate: block the turn and instruct Claude to run codex second-opinion first.
jq -n '{
  decision: "block",
  reason: "Second-opinion gate: your last message presents labeled options and a recommendation, but no codex second-opinion ran in this turn. Per ~/.claude/CLAUDE.md (External code review (Codex) > Second-opinion review (pre-action)): pipe the analysis bundle into `~/.claude/bin/codex-second-opinion.sh` via a quoted heredoc, e.g. `~/.claude/bin/codex-second-opinion.sh <<'"'"'EOF'"'"'\n## Question / problem\n...\n## Claude'"'"'s analysis\n...\n## Claude'"'"'s position\n...\nEOF`. Then present BOTH analyses (yours and codex'"'"'s verdict / position / missed-concerns) in the same response. Skip only when I have already picked, the choice is purely cosmetic, it is a pure fact lookup, or the work is mechanical. If you believe this trigger is a false positive (e.g., recap of a past comparison), say so explicitly in your retry."
}'
