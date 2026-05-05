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

<!-- ## External code review (Codex)

DISABLED 2026-05-04 — codex CLI not yet logged in on this Mac.
Re-enable by removing the surrounding HTML comment markers once
`codex login` has been run and `codex exec --help` works.

Run Codex as a **synchronous pre-commit reviewer** over every staged
diff. Fix every critical finding before committing or pushing — pushes
only carry already-passed commits. Codex catches what diff-reread plus
tests miss; the bar is shipping nothing it would flag.

**Per-commit workflow:**

1. **Self-review first** — codex is not a substitute:
   - **Implementation matches the ask and the spec.** Every change
     traces to what I asked for. No scope creep, no speculative
     additions, no violation of project CLAUDE.md / AGENTS.md
     invariants. If the ask was a bug fix, the diff fixes that bug
     and only that bug.
   - **TDD followed.** For features and bugfixes, a failing test
     landed first and now passes. The test exercises the behavior in
     the ask, not implementation incidentals. (Skip only when truly
     infeasible — UI-only changes, hardware-coupled paths I've
     explicitly waived.)
   - Re-read `git diff --cached` end-to-end. Every changed line traces
     to a stated intent — if you can't justify a line in one breath,
     drop it.
   - Run formatter + linter + the relevant tests. Green at every step,
     no exceptions.
   - No debug `print` / `dbg!` / `console.log`, no commented-out
     blocks, no "TODO: clean up later" — clean up now or open a
     backlog item.
   - No secrets, no logs of credentials, no PII in error messages.

2. **Run codex against the staged diff** (read-only, JSON verdict):
   ```bash
   git diff --cached | codex exec \
     --sandbox read-only \
     --output-schema ~/.claude/codex-review.schema.json \
     -o /tmp/codex-review.json \
     "Review the staged diff piped on <stdin> against this repo's
      AGENTS.md (auto-loaded from cwd). Apply the project's stated
      review priorities. Return JSON per schema: verdict
      APPROVED|REVISE, plus critical findings and nits."
   ```
   - Codex auto-loads `AGENTS.md` from cwd — **do not cat it into the
     prompt**. If a project section deserves focus (e.g. realtime
     audio rules, append-only migrations), name it in the prompt by
     section number — that's cheaper than re-passing the file. The
     `<stdin>` block carries the diff; `codex exec --help` confirms
     "If stdin is piped and a prompt is also provided, stdin is
     appended as a `<stdin>` block."
   - `~/.claude/codex-review.schema.json` defines the
     verdict/critical/nits contract — must exist (it ships in this
     config). OpenAI strict-mode requires `required` to enumerate
     every property in each object; nullable optional fields use
     `["type", "null"]`.
   - Use `codex exec`, not `codex review` — only `exec` supports
     `--output-schema` for deterministic gating.
   - Never `--dangerously-bypass-approvals-and-sandbox` for review.
     Review is read-only.

3. **Triage `/tmp/codex-review.json`:**
   - `APPROVED` → commit.
   - `REVISE` → fix real issues. For false positives, justify them in
     your reply to me — don't blindly accept or blindly dismiss. Nits:
     ignore unless trivial and clearly improving.

4. **Re-run after fixes. Hard cap: 2 rounds.** If codex still flags
   things after round 2, stop and surface the disagreement with your
   reasoning instead of looping.

5. Commit only after `APPROVED`, or after I OK shipping with the
   remaining findings explicitly documented in your message.

**Skip codex for:** pure-formatter commits (`make fmt`-only), lockfile
bumps with no code changes, **non-runbook** doc typo fixes (do NOT
skip for changes to CLAUDE.md / AGENTS.md / hook scripts / executable
examples — those are operational), generated-file-only commits whose
source change you already pushed through review.

Small, well-scoped, individually-revertable commits with green tests at
each step. Don't bundle steps into a mega-commit just because codex is
fast. The discipline is for me, not for codex.

-->

## Monitor mode (background log/event watching)
Monitor is the single most useful debugging tool I have. **Use it as much as possible**, especially when:

- Debugging an intermittent failure — the monitor gathers Phase-1 evidence live instead of re-running the failure repeatedly.
- Running an app locally (`flutter run`, `cargo run`, `npm run dev`, `make run-…`) — start a Monitor on the relevant log stream BEFORE you trigger the action you want to observe. State transitions you would otherwise miss (`reqwest::connect: starting new connection` followed by silence, a TLS handshake that completes but a stream that never reads, etc.) become visible.
- Watching for a specific failure signature while the user reproduces something — far better than asking them to copy-paste log dumps.

Filter discipline:
- **Match exact tag strings and known marker substrings** from the very first iteration. A loose filter (`grep -E "search"`) drowns the signal in unrelated app noise (vulkan, AppSearch, Subsonic responses with the word "search" in them) and triggers the `output rate too high` cap, which kills the monitor mid-investigation.
- Cover BOTH the success and failure markers in the same alternation. Silence is not success — a monitor that emits only on the happy path stays quiet through a crashloop.
- Use the persistent flag for session-long watches (live debugging the user's repro). Restart with a tighter filter the moment you see noise — don't tolerate it.

If the work is "tell me when X is ready" (one notification, then done), use Bash `run_in_background` with an `until` condition instead — Monitor is for ongoing event streams, not single-shot waits.

## Plugins
Active globally: claude-mem, ui-ux-pro-max, frontend-design, context7, code-review, code-simplifier, claude-md-management, commit-commands, security-guidance, claude-code-setup, rust-analyzer-lsp, typescript-lsp. Use their skills/commands when they match; don't reinvent what they provide. (Superpowers was removed — do NOT try to invoke any `superpowers:*` skill.)

**Direct-ask triggers — when I ask for the task on the left, use the skill/command on the right. Do not roll your own.**
- "review this PR / review my diff" → `/code-review` (interactive, ad hoc; distinct from the pre-commit `codex exec` gate above which is automated and JSON-schema-driven)
- "commit" / "commit and push" / "open PR" / "clean gone branches" → `commit-commands:commit` / `:commit-push-pr` / `:clean_gone`
- "audit / improve / fix CLAUDE.md" → `claude-md-management:claude-md-improver` (or `:revise-claude-md` for session-learning updates)
- "simplify this code" / "clean this up" → spawn Agent with `subagent_type: code-simplifier:code-simplifier`
- "audit my Claude Code setup" / "what automations should I have" → `claude-code-setup:claude-automation-recommender`
- TDD / "red-green-refactor" / "test-first" → user skill `tdd` (mattpocock).

**Frontend skill routing — both are installed; pick based on the project:**
- `frontend-design:frontend-design` (Anthropic) → distinctive aesthetic, marketing/landing/portfolio/consumer/creative work. Forces deliberate visual identity before code.
- `ui-ux-pro-max:ui-ux-pro-max` (community) → enterprise dashboards, SaaS, design-system-heavy work, multi-stack consistency. Reasoning engine that picks coherent style/palette/typography for a stated product type.
- For ambiguous/general "make this look better" asks, invoke **both** in sequence: `frontend-design` for the aesthetic decision, then `ui-ux-pro-max` to enforce coherence and accessibility.

## User-level skills (`~/.claude/skills/`)
Standalone skills (not plugin-namespaced — invoke via Skill tool by bare name). Match my ask to each skill's `description` field; if it fits, use it.
- **graphify** — any input → knowledge graph. Trigger: `/graphify`
- **gocomet-fs-ai-part1-reviewer** — score GoComet Nova FS AI Part 1 submissions
- **mattpocock pack** (current upstream — github.com/mattpocock/skills):
  - engineering: `diagnose`, `grill-with-docs`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `tdd`, `to-issues`, `to-prd`, `triage`, `zoom-out`
  - productivity: `caveman`, `grill-me`, `write-a-skill`
  - misc: `git-guardrails-claude-code`, `migrate-to-shoehorn`, `scaffold-exercises`, `setup-pre-commit`

When I type `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

## Pentest tooling
`hackingtool` (Z4nzu/hackingtool) installs to `/usr/share/hackingtool` with launcher `/usr/bin/hackingtool` and user config in `~/.hackingtool/`. Use **only** during authorized pentest engagements I have explicitly scoped. Never run any included tool against a target I have not named as in-scope. Treat output as sensitive — do not paste credentials, hashes, or scan results into chat platforms or commits.

**When to invoke `hackingtool`:** reach for the `/usr/bin/hackingtool` launcher (or its sub-tools) whenever the task context calls for it on an in-scope engagement — recon, scanning, exploitation, post-exploitation, forensics, wireless, payload generation, etc. — and **always** when I explicitly ask ("use hackingtool", "run it through hackingtool", "fire up hackingtool"). Don't reinvent what it bundles. Still bound by the scope and sensitivity rules above.

@RTK.md
