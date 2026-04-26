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
- **Diagnose native/FFI bugs from both sides.** When something works in `curl` from your dev box but hangs in the running app, also test the same URL from inside the target environment (e.g. `adb shell curl` on the device). Localizing TCP-vs-TLS-vs-app-runtime takes minutes and saves hours of guessing.

## Editing discipline
- **Re-read before edit.** Re-read any file immediately before modifying — especially after context compaction. Never edit from stale memory.
- **Surgical diffs.** Every changed line should trace directly to my request. Match existing style (indent, quotes, naming) exactly. Do not refactor, reformat, or "improve" adjacent code unasked. If you notice unrelated dead code, mention it — don't delete it.
- **No unasked additions.** No type annotations, docstrings, comments, error handling, or back-compat shims beyond what I requested. Minimum code that solves the problem. Nothing speculative.
- **No premature abstraction.** No abstractions for single-use code. No flexibility, configurability, or options I didn't ask for. If 200 lines could be 50, write 50.
- **Search before destroy.** Before deleting or renaming a function/class/file/export/import, grep all references and update them in the same change.
- **Orphan cleanup.** Remove imports/variables/functions YOUR changes made unused. Don't touch pre-existing dead code unless asked.
- **Defensive parsing at API boundaries.** When parsing JSON from an external/undocumented API, never use a bare `value as String?` cast. Write `value is String ? value as String : null` (or the equivalent in the target language). The same field can ship as a String today and a `List<int>` next quarter; an `as` cast crashes the parser and silently empties the surrounding container.

## Tool preferences
- Prefer CLI over MCP: `gh` (GitHub), `psql` (Postgres), `kubectl` (k8s), `aws`/`gcloud`/`az` (cloud), `docker` (containers).
- Prefer `rg` over reading files blindly. Prefer `fd` over `find`. Use `bat` for syntax-highlighted output you want me to read.

## New project onboarding
Before editing a project you haven't touched:
1. Read `CLAUDE.md` and `README.md` at the project root.
2. Check `Makefile`, `package.json`, `pyproject.toml`, `Gemfile`, `justfile` for actual build/test/lint commands — don't guess.
3. `git log --oneline -20` for recent patterns.
4. Check the existing test framework before running tests — don't assume.

## External code review (Codex)

I run Codex as an asynchronous parallel reviewer over every commit and
PR you ship. **Do not pause between commits to wait for it** — its
review fires automatically and runs in parallel with your next step.
Treat its feedback the same as any other course correction I might
surface: incorporate it via a follow-up commit, never an `--amend`.

**The rule that makes async review work: self-review is the bar.**
Codex is smart enough to catch sloppy work; the goal is to ship
nothing it would flag in the first place. Before every commit:

- Re-read the diff (`git diff --cached`) end-to-end. Every changed
  line should trace to a stated intent — if you can't justify a line
  in one breath, drop it.
- Run the relevant tests AND `<formatter> + <linter>` for the
  language. Green at every step, no exceptions.
- No debug `print` / `dbg!` / `console.log` / commented-out blocks
  left in. No "TODO: clean up later" — clean up now or open a
  backlog item.
- No secrets, no logs of credentials, no PII in error messages.
- If the change is non-trivial, ask yourself: "what would I question
  if I were reviewing this?" Then either fix it or write a one-line
  comment explaining why it's that way.

Small, well-scoped, individually-revertable commits with green tests
at each step. Don't collapse multiple steps into one mega-commit
just because codex is fast. The discipline is for me, not for codex.

## Monitor mode (background log/event watching)
Monitor is the single most useful debugging tool I have. **Use it as much as possible**, especially when:

- Running `superpowers:systematic-debugging` — the monitor is how Phase 1 evidence gets gathered live instead of by re-running the failure repeatedly.
- Running an app locally (`flutter run`, `cargo run`, `npm run dev`, `make run-…`) — start a Monitor on the relevant log stream BEFORE you trigger the action you want to observe. State transitions you would otherwise miss (`reqwest::connect: starting new connection` followed by silence, a TLS handshake that completes but a stream that never reads, etc.) become visible.
- Watching for a specific failure signature while the user reproduces something — far better than asking them to copy-paste log dumps.

Filter discipline:
- **Match exact tag strings and known marker substrings** from the very first iteration. A loose filter (`grep -E "search"`) drowns the signal in unrelated app noise (vulkan, AppSearch, Subsonic responses with the word "search" in them) and triggers the `output rate too high` cap, which kills the monitor mid-investigation.
- Cover BOTH the success and failure markers in the same alternation. Silence is not success — a monitor that emits only on the happy path stays quiet through a crashloop.
- Use the persistent flag for session-long watches (live debugging the user's repro). Restart with a tighter filter the moment you see noise — don't tolerate it.

If the work is "tell me when X is ready" (one notification, then done), use Bash `run_in_background` with an `until` condition instead — Monitor is for ongoing event streams, not single-shot waits.

## Plugins
Active globally: superpowers, claude-mem, ui-ux-pro-max, frontend-design, context7, code-review, code-simplifier, claude-md-management, commit-commands, security-guidance, claude-code-setup, rust-analyzer-lsp, typescript-lsp. Use their skills/commands when they match; don't reinvent what they provide.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
