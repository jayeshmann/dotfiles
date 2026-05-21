#!/usr/bin/env bash
# Second-opinion codex review. Reads analysis bundle from stdin,
# prints codex verdict JSON to stdout (also saved to /tmp/codex-options.json).
#
# Expected stdin format (3 sections, all required):
#   ## Question / problem
#   <what's being decided, answered, or recommended>
#
#   ## Claude's analysis
#   <reasoning, options if any, trade-offs, evidence>
#
#   ## Claude's position
#   <recommendation, picked option, answer, or "no position; listing only">
#
# Notes:
# - --skip-git-repo-check lets this run from any cwd, including non-repo dirs.
# - Caller should pass the bundle via a quoted heredoc (<<'EOF') so $vars and
#   backticks in the body don't expand; the heredoc content is verbatim.
# - One bash call, no tmp file beyond the codex output sink.
set -euo pipefail

# Read the analysis bundle from our own stdin, then forward it to
# codex exec via a pipe. Doing this explicitly so the bundle reaches
# codex even if a future bash version or wrapper changes stdin
# inheritance semantics; safer than relying on implicit fd 0 passthrough.
bundle=$(cat)
printf '%s' "$bundle" | codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  --output-schema "$HOME/.claude/codex-options-review.schema.json" \
  -o /tmp/codex-options.json \
  "Independently evaluate the analysis in <stdin>. Apply this repo's
   AGENTS.md (auto-loaded from cwd) if present. Return JSON per
   schema: verdict AGREE|PARTIAL|DISAGREE, your own position (use
   'none-of-the-above' if a better path was missed), and any
   concerns Claude's analysis missed. Populate option_assessments
   only when Claude presented discrete labeled options; null
   otherwise."

cat /tmp/codex-options.json
