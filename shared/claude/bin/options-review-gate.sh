#!/usr/bin/env bash
# Stop hook: gate options-presentation behind codex second-opinion review.
#
# Fires when Claude finishes generating an assistant message. The hook blocks
# the turn (forcing a codex second-opinion first) when that message either:
#   - presents >=2 labeled options (Option/Approach/Path/Plan/Strategy A/B/1/2)
#     together with a recommendation, OR
#   - presents a strong STANDALONE recommendation: a deliberately-structured
#     recommendation/verdict section (heading, bold line-start label, or
#     line-start "Recommendation:" / "My take/verdict/call:"). This is how a
#     single-recommendation design judgment is surfaced when it carries no
#     labeled options.
# ...and the turn did NOT already include a codex second-opinion invocation.
#
# High-precision by design: casual inline "I recommend X" is NOT a trigger
# (too noisy for a blocking gate; noise trains the gate to be dismissed as a
# false positive). The judgment-heavy long tail stays Claude's responsibility
# under CLAUDE.md.
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

# Count regex matches in a string; ALWAYS emits a single clean integer (0 on
# no match or error). `grep -c` prints the count but exits 1 on zero matches;
# a naive `... || echo 0` then appends a second "0", yielding "0\n0", which
# makes downstream `[[ -lt ]]` arithmetic raise a syntax error and the guard
# fail open into a spurious block. Sanitize to leading digits, default to 0.
count_matches() {
  local n
  n=$(printf '%s' "$1" | grep -cE "$2" 2>/dev/null || true)
  n=${n%%[!0-9]*}
  printf '%s' "${n:-0}"
}

# >=2 labeled options? Labels: Option|Approach|Path|Plan|Strategy + [A-Z]|[0-9]+
# (e.g. "Option A", "Approach 1"). Forms: ### <Label> X (heading), **<Label> X**,
# **(X)**, - **(X)**, - **<Label> X**, or "<Label> X" at line start.
options_count=$(count_matches "$last_text" '(^#{1,6}[[:space:]]+(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)\b|\*\*(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)\b|\*\*\(([A-Z]|[0-9]+)\)\*\*|^- \*\*\(([A-Z]|[0-9]+)\)|^- \*\*(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)|^(Option|Approach|Path|Plan|Strategy) ([A-Z]|[0-9]+)\b)')

# Any recommendation language (inline or structured): "My recommendation:",
# "I'd pick/recommend/go with", "Claude's recommendation", a "## Recommendation"
# heading, or "Recommendation:" / "Recommended:" line starters.
recommend_hits=$(count_matches "$last_text" "(My recommendation\b|I.d (pick|recommend|go with)|Claude.s recommendation\b|^#{1,6}[[:space:]]+(Claude.s )?[Rr]ecommendation\b|^[Rr]ecommendation:|^[Rr]ecommended:)")

# Strong STANDALONE recommendation/verdict section: a deliberately-structured
# pick that may carry NO labeled options (the single-recommendation design
# judgment). High precision: a heading, a bold line-start label, or a line-start
# "Recommendation:" / "My take|verdict|call:". Casual inline "I recommend X" is
# intentionally excluded so trivial/mechanical recommendations don't gate.
strong_recommend=$(count_matches "$last_text" "(^#{1,6}[[:space:]]+(My |Claude.s )?[Rr]ecommendation\b|^[[:space:]]*\*\*(My |Claude.s )?[Rr]ecommendation\b|^(My |Claude.s )?[Rr]ecommendation:|^[[:space:]]*\*\*My (take|verdict|call)\b|^My (take|verdict|call):)")

# Gate trigger: (>=2 labeled options AND a recommendation) OR a strong
# standalone recommendation. Otherwise allow the turn.
if ! { [[ "$options_count" -ge 2 && "$recommend_hits" -ge 1 ]] || [[ "$strong_recommend" -ge 1 ]]; }; then
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
  reason: "Second-opinion gate: your last message presents labeled options with a recommendation, or a standalone recommendation / design judgment, but no codex second-opinion ran in this turn. Per ~/.claude/CLAUDE.md (External code review (Codex) > Second-opinion review (pre-action)): pipe the analysis bundle into `~/.claude/bin/codex-second-opinion.sh` via a quoted heredoc, e.g. `~/.claude/bin/codex-second-opinion.sh <<'"'"'EOF'"'"'\n## Question / problem\n...\n## Claude'"'"'s analysis\n...\n## Claude'"'"'s position\n...\nEOF`. Then present BOTH analyses (yours and codex'"'"'s verdict / position / missed-concerns) in the same response. Skip only when I have already picked, the choice is purely cosmetic, it is a pure fact lookup, or the work is mechanical. If you believe this trigger is a false positive (e.g., recap of a past comparison), say so explicitly in your retry."
}'
