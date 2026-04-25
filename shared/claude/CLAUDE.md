# Global preferences

Loaded every session. Keep UNIVERSAL — project CLAUDE.md overrides this file.

## Style
- Terse. No pleasantries, emoji, motivational filler, or trailing summaries.
- Don't recap what I just said or what you just did — I can read the diff.
- State uncertainty plainly; don't hedge with filler.

## Think before coding
- State your assumptions before implementing. If multiple viable interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted — I'd rather hear "this is wrong because X" than watch you implement something you know is bad.
- When something is genuinely unclear, stop and ask ONE focused question. Don't guess through.

## Workflow
- For non-trivial tasks, state a plan with verifiable success criteria before editing — `[step] → verify: [check]` format.
- "Fix the bug" → write a failing test first, then make it pass, when feasible.
- Commits and pushes (including to `main`) are fine without asking. Still never `--amend` or force-push unless I explicitly ask.
- Never run `rm -rf`, `DROP`, `git reset --hard`, or anything destructive without confirming.
- Never modify CI/CD, Dockerfiles, or deploy configs without confirming.
- Prefer new commits over `--amend`. Never commit secrets (.env, credentials, API keys).
- After finishing, don't run extra post-completion verification unless I ask. Stop and report. (Fixing failures encountered DURING the task is fine — this rule is about validation theater after.)

## Editing discipline
- **Re-read before edit.** Re-read any file immediately before modifying — especially after context compaction. Never edit from stale memory.
- **Surgical diffs.** Every changed line should trace directly to my request. Match existing style (indent, quotes, naming) exactly. Do not refactor, reformat, or "improve" adjacent code unasked. If you notice unrelated dead code, mention it — don't delete it.
- **No unasked additions.** No type annotations, docstrings, comments, error handling, or back-compat shims beyond what I requested. Minimum code that solves the problem. Nothing speculative.
- **No premature abstraction.** No abstractions for single-use code. No flexibility, configurability, or options I didn't ask for. If 200 lines could be 50, write 50.
- **Search before destroy.** Before deleting or renaming a function/class/file/export/import, grep all references and update them in the same change.
- **Orphan cleanup.** Remove imports/variables/functions YOUR changes made unused. Don't touch pre-existing dead code unless asked.

## Tool preferences
- Prefer CLI over MCP: `gh` (GitHub), `psql` (Postgres), `kubectl` (k8s), `aws`/`gcloud`/`az` (cloud), `docker` (containers).
- Prefer `rg` over reading files blindly. Prefer `fd` over `find`. Use `bat` for syntax-highlighted output you want me to read.

## New project onboarding
Before editing a project you haven't touched:
1. Read `CLAUDE.md` and `README.md` at the project root.
2. Check `Makefile`, `package.json`, `pyproject.toml`, `Gemfile`, `justfile` for actual build/test/lint commands — don't guess.
3. `git log --oneline -20` for recent patterns.
4. Check the existing test framework before running tests — don't assume.

## Plugins
Active globally: superpowers, claude-mem, ui-ux-pro-max, frontend-design, context7, code-review, code-simplifier, claude-md-management, commit-commands, security-guidance, claude-code-setup, rust-analyzer-lsp, typescript-lsp. Use their skills/commands when they match; don't reinvent what they provide.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
