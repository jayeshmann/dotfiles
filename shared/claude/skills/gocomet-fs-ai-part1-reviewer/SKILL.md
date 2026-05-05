---
name: gocomet-fs-ai-part1-reviewer
description: Review and score candidate submissions for the GoComet Nova Full-Stack AI Engineer Part 1 assignment (Multi-Agent Trade Document Pipeline). Use this skill whenever the user shares a candidate's repo, zip, GitHub link, PRD, technical write-up, or demo video for the GoComet Full-Stack AI Engineer role, or asks to "review a Nova submission", "score the trade document agent", "evaluate the Extractor/Validator/Router pipeline", "check this candidate for the FDE role", or mentions reviewing the multi-agent foundation. Also trigger when the user wants to apply the 100-point rubric (20% Architecture, 20% AI Craft, 20% End-to-End Demo, 20% PRD/Nova Understanding, 15% Outcome Thinking, 5% Communication) to a Nova candidate. Produces a structured scored review report covering all three deliverables (PRD, POC, Technical Write-up) with auto-fail detection, Nova-concept checks, and specific file/line findings.
---

# GoComet Nova Full-Stack AI Engineer Part 1 Review Skill

Use this skill to review candidate Part 1 submissions for the **Nova Full-Stack AI Engineer (FDE)** role. Part 1 is the 8-16 hour build of a multi-agent trade document pipeline (Extractor → Validator → Router) with storage, query, and a minimal UI. **Part 1 is a gate**: clearing the bar unlocks Part 2.

## How to Use This Skill

1. **Review code and documents only, do not execute the POC.** Analyze repo structure, agent boundaries, prompt configs, data store, README, PRD content, technical write-up, sample docs, demo video script.
2. Walk the six scoring dimensions in order (matching the assignment's own weights).
3. Verify all three deliverables are present (PRD + POC + Technical Write-up).
4. Check auto-fail conditions before finalizing.
5. Produce the final report using the Output Format template.
6. Cite specific file paths, line numbers, page references for every finding.

## Verification Discipline

**Grep before you assert.** Every negative finding ("X is missing", "Y is not implemented", "Z is incorrect") must be verified by searching the codebase or extracting text from documents. Do not rely on visual reads alone.

- **Missing deliverable?** Search the repo for file types (`.mp4`, `.mov`), links (`loom`, `youtube`, `drive.google`), and README references. Deliverables like demo videos are often hosted externally (Loom, Google Drive, YouTube) and linked rather than committed. **If not found in repo, ask the reviewer before triggering auto-fail** — the video may exist separately.
- **Missing code feature?** `rg` or `grep` for the relevant function/variable/keyword before claiming it doesn't exist.
- **PDF content claims?** Extract text programmatically (PyMuPDF/pdftotext) to verify exact wording — visual PDF reads can miss or misread content.
- **"Sample documents" vs "sample queries" are different deliverables.** Sample documents are the trade doc inputs (PDFs/images fed into the pipeline). Sample queries are NL questions run against stored output with their results documented. Don't conflate them.

## Role Context

- Role: **Nova Full-Stack AI Engineer (FDE)**, 0 to 4 years experience (2024/2025/2026 graduates)
- Half engineer, half consultant. Tech leads at 60%, product/outcome at 40%.
- Part 1 scope only. Part 2 reviewed separately after Part 1 passes.
- Time budget: 8 to 16 hours

## Assignment Spec at a Glance

**Three required deliverables** (in order):
1. **PRD** (3-5 pages): Nova understanding + problem + users + agent architecture + LLM choices + trust/evals + metrics + what's next
2. **Working POC** (5 behaviors A-E, partial does not pass)
3. **Technical Write-up** (1-2 pages): architecture diagram + 3 failure modes + observability + cost + latency + week-instead-of-day plans

**Five required POC behaviors:**
- A: Extractor Agent (vision LLM, structured JSON, per-field confidence)
- B: Validator Agent (rule comparison against a candidate-defined customer rule set, match/mismatch/uncertain, never silent approve)
- C: Router/Decision Agent (auto-approve **and store**, flag, or draft amendment **listing each discrepancy**, with reasoning)
- D: Storage + Query (queryable store + NL question support including time-based/aggregation queries)
- E: Minimal UI (shows real run state)

**Submission must include two sample documents** — one clean, one messy/low-quality. The POC must handle both; check that extraction degrades gracefully on the messy doc (confidence drops, fields marked uncertain, not silently hallucinated).

**Nova concepts the PRD must demonstrate understanding of (per assignment Section 1):**
- What Nova is and what problem it solves that traditional SaaS cannot
- FDE (Forward Deployed Engineer) model and why GoComet uses it for Nova
- "System of Outcomes" vs "System of Record" vs "System of Engagement"

The assignment caps each answer at 200 words and explicitly says "We can spot a copy-paste from a mile." Read this section for original thinking, not buzzword bingo.

**PRD must be execution-oriented** — "Not a vision doc. An engineer should be able to read this and start building." Score down PRDs that read like strategy decks or marketing docs.

**AI-generated content detection applies to ALL deliverables** — not just the Nova section. Check the PRD, technical write-up, and code comments/docstrings for signs of unedited LLM output (generic hedging, "it's important to note", "in conclusion", suspiciously uniform structure across all sections). Flag but don't auto-fail unless the Nova section specifically is LLM boilerplate.

## Scoring Model (100 Points)

Weights map directly to the assignment's evaluation table.

| Dimension | Weight |
|---|---|
| Architecture & Code Quality | 20 |
| AI Craft | 20 |
| End-to-End Demo (5 behaviors live) | 20 |
| PRD Depth & Nova Understanding | 20 |
| Outcome & Product Thinking | 15 |
| Communication | 5 |

**Thresholds**
- Strong Pass: 85/100 and above (clear gate, unlock Part 2 immediately)
- Pass: 70/100 (unlock with written feedback on weak spots)
- Fail: below 70/100 (do not unlock Part 2)

---

# Scoring Rubric

## 1. Architecture & Code Quality (20 points)

**Sharp Agent Boundaries (6 pts)**
- 6: Three agents with distinct, defensible responsibilities. PRD argues "why three, not one or five."
- 4: Three agents but one is anemic (thin wrapper around another)
- 2: Agents exist but boundaries blur in code (validator does extraction logic, etc.)
- 0: Single monolithic agent with internal branches. **Violates assignment intent.**

**Clean Handoffs (5 pts)**
- 5: Structured handoff (typed schema, Pydantic/JSON schema, or message contract). State documented.
- 3: Dict passing without schema enforcement
- 1: Implicit shared state, no contract
- 0: Direct function calls with mutated globals

**Defensible Tech Choices (5 pts)**
- 5: PRD justifies LLM/framework/store picks with cost/latency/quality tradeoffs
- 3: Choices made but justification thin
- 1: No justification, picks feel arbitrary
- 0: Inappropriate choices (e.g., text-only model for vision extraction)

**Code That Doesn't Make Us Cry (4 pts)**
- 4: Clear folder structure, consistent naming, no dead code, prompts externalized
- 3: Mostly clean, one or two rough spots
- 2: Inconsistent style, some duplication
- 0: Spaghetti, prompts inline, no module boundaries

## 2. AI Craft (20 points)

**Hallucination Handling (5 pts)**
- 5: Schema-bound output + grounding check (field must trace to doc region) + explicit "not found" handling
- 3: Schema validation only, no grounding
- 1: Trusts LLM blindly with caveats in prompt
- 0: No anti-hallucination measures. **Violates explicit assignment requirement.**

**Confidence Surfacing (5 pts)**
- 5: Per-field confidence on every extracted field, surfaced to UI and storage, used by validator/router
- 3: Per-field confidence present but not consumed downstream
- 1: Single overall confidence only
- 0: No confidence anywhere. **Violates explicit Behavior A requirement.**

**Eval Thinking (4 pts)**
- 4: PRD defines at least one offline eval (e.g., golden set field accuracy) AND one online metric (e.g., human-override rate). Evidence of having actually tried evals.
- 2: Defines metrics but no implementation or sample dataset
- 1: Generic mention without specifics
- 0: Not addressed

**Cost & Latency Awareness (3 pts)**
- 3: Tech write-up shows back-of-envelope cost per doc, identifies slowest hop, names mitigation
- 2: One of cost or latency addressed
- 0: Not addressed

**Observability Story (3 pts)**
- 3: Tech write-up explains tracing one shipment end-to-end (Langfuse, OpenTelemetry, structured logs, or equivalent). Names what the dashboard shows.
- 2: Generic logging mentioned
- 0: Not addressed

## 3. End-to-End Demo (20 points)

All five behaviors must run on real input. Partial does not pass per assignment.

**Behavior A: Extractor Agent (4 pts)**
- 4: Vision LLM, accepts PDF and image, extracts all 8 required fields (consignee, HS code, POL, POD, Incoterms, description, gross weight, invoice number), per-field confidence
- 3: All fields but one document type missing or one field absent
- 2: Works but missing 2+ required fields
- 0: Does not run, or text-only extraction. **AUTO-FAIL on Behavior A.**

Required fields checklist:
- [ ] Consignee name
- [ ] HS code
- [ ] Port of Loading (POL)
- [ ] Port of Discharge (POD)
- [ ] Incoterms
- [ ] Description of goods
- [ ] Gross weight
- [ ] Invoice number

**Behavior B: Validator Agent (4 pts)**
- 4: Field-by-field result (match/mismatch/uncertain), mismatches show found-vs-expected, uncertain fields surfaced (never silent approve). Candidate-defined rule set is realistic and non-trivial (covers multiple fields for at least one customer, not just a 2-field stub).
- 3: All three statuses but found-vs-expected weak, or rule set is minimal/trivial
- 1: Binary pass/fail only
- 0: Silent approval on uncertain fields. **AUTO-FAIL.**

**Behavior C: Router/Decision Agent (4 pts)**
- 4: Three outcomes implemented: (1) auto-approve **and store** (verify the store actually happens on auto-approve path), (2) flag for human review with reasoning, (3) draft amendment **listing each discrepancy with field name, found value, and expected value**. Each decision includes explicit reasoning.
- 3: Three outcomes but reasoning thin/templated, or amendment doesn't list per-field discrepancies, or auto-approve doesn't trigger storage
- 1: Two outcomes only, or no reasoning
- 0: No decision agent, or emits decision without reasoning. **AUTO-FAIL on reasoning.**

**Behavior D: Storage + Query (4 pts)**
- 4: Verified output in queryable store + NL question support returning grounded answer with the query/logic shown
- 3: Stored but query layer thin (only structured queries, no NL)
- 1: Stored in non-queryable form (raw JSON files, no index)
- 0: Not stored

**Behavior E: Minimal UI (4 pts)**
- 4: Shows real state from real run: extracted fields + confidence + validation result + decision + reasoning, all on screen
- 3: Shows most of the above, missing one element
- 1: Hardcoded/dummy data, or only shows extraction
- 0: No UI. **AUTO-FAIL.**

## 4. PRD Depth & Nova Understanding (20 points)

The PRD has 8 required sections. Score each.

**Section 1: Nova Understanding (5 pts)** — the differentiator
- 5: Explains in own words (a) what Nova is and the SaaS gap it fills, (b) FDE model and why GoComet uses it, (c) System of Outcomes vs Record vs Engagement. Shows actual comprehension, not paraphrase. Each answer stays within the 200-word cap.
- 3: All three covered but one is shallow or paraphrased from JD. Or one answer significantly exceeds 200-word cap (communication discipline issue).
- 1: Two of three covered, or all three are clearly copy-paste-with-synonyms
- 0: Section missing, or clearly LLM-generated boilerplate. **Critical signal.**

**Section 2: Problem Statement (2 pts)**
- 2: Names specific failure modes in the current trade-doc validation flow (not generic "things break"). Describes what success looks like for a CG operator in their first 5 minutes. Both questions from the assignment addressed.
- 1: One of the two addressed, or both are vague/generic
- 0: Section missing

**Section 3: Users + JTBDs (2 pts)**
- 2: 2+ personas including CG and SU with distinct needs. 5+ JTBDs in proper "When ___, I want ___, so that ___" form. JTBDs are specific to trade-doc validation, not generic.
- 1: Personas present but JTBDs missing, generic, or wrong format. Fewer than 5 JTBDs.
- 0: Section missing

**Section 4: Agent Architecture (3 pts)**
- 3: Defends "why three agents not one or five", clear input/output per agent, planner/executor/verifier framing OR equivalent, addresses crash recovery and inter-agent communication pattern (shared memory / message passing / structured handoff)
- 2: Three of four sub-questions answered well
- 1: Architecture described but boundary defense weak
- 0: No architecture section, or just a diagram with no reasoning

**Section 5: LLM & Tooling Choices (3 pts)**
- 3: Per-agent model choice with cost/latency/quality tradeoff, vision model + fallback for bad-quality docs, framework justification, explicit choice on where to use AND where to avoid structured output/function calling (the "avoid" reasoning tests design maturity)
- 2: Most addressed but one weak
- 1: Choices listed without tradeoff reasoning
- 0: Section missing

**Section 6: Trust, Failure Handling, Evals (3 pts)**
- 3: Explicit anti-hallucination strategy + low-confidence handling + loop/cost/infinite-retry prevention + offline eval AND online metric
- 2: Three of four covered well
- 1: Generic mentions
- 0: Section missing or hand-waved

**Section 7: Metrics + Go/No-Go (1 pt)**
- 1: One specific testable north-star + 5-8 supporting metrics (mix of agent quality, system health, business outcome) + concrete pilot Go/No-Go criteria for a 2-week pilot
- 0: North-star vague ("improve accuracy"), supporting metrics missing, or no Go/No-Go criteria

**Section 8: What's Next (1 pt)**
- 1: Names what to build next with explicit prioritization reasoning ("why this and not something else"). Shows product instinct — builds on Part 1, not a random feature wishlist.
- 0: Section missing, or lists features without prioritization reasoning

## 5. Outcome & Product Thinking (15 points)

**Testable North-Star (5 pts)**
- 5: One number, one sentence, measurable on Day 14 of pilot. Example: "CG amendment-cycle count drops from 2.3 to under 1.0 average per shipment."
- 3: Specific but multiple numbers conflated
- 1: Directional ("faster", "more accurate") not testable
- 0: No north-star or aspirational fluff

**Real Failure Modes (5 pts)**
- 5: Tech write-up names 3 nasty failure modes from candidate's own testing, with real examples and handling strategy each. Evidence of actual testing: specific error messages, field values that went wrong, document types that broke, or logs/screenshots referenced.
- 3: 3 failure modes but feel hypothetical (no specific values, no "when I ran X, Y happened" language)
- 1: 1-2 failure modes, generic
- 0: Failure modes section missing

**Explicit Trust Handling (5 pts)**
- 5: Trust strategy is concrete: thresholds, escalation paths, audit trail, what makes the agent stop. Not vibes.
- 3: Concrete in places, vague in others
- 1: "We use confidence scores" without specifics
- 0: No trust strategy

## 6. Communication (5 points)

**Technical Write-up Sharpness (2 pts)**
- 2: 1-2 pages, dense, every section earns its space, one architecture diagram present
- 1: Present but bloated or missing sections
- 0: Missing or 5+ pages of fluff

**Demo Video (2 pts)**
- 2: 2-3 min, walks through pipeline on one document, shows real output not slides
- 1: Present but too long, too short, or doesn't show the pipeline running
- 0: Missing or unwatchable

**README (1 pt)**
- 1: Setup, run, sample queries, known limitations. Reproducible on a laptop.
- 0: Vague, broken commands, or missing

---

# Critical Auto-Fail Checks

If any of these are present, cap overall score at **69 (Fail, do not unlock Part 2)** regardless of other strengths:

- One or more of the 5 POC behaviors (A-E) does not run on real input
- No per-field confidence on extractions (explicit Behavior A requirement)
- Silent approval on uncertain validator fields (explicit Behavior B requirement)
- Router decisions emitted without reasoning (explicit Behavior C requirement)
- Single-prompt monolith pretending to be three agents (architectural fraud)
- Hallucinated fields in extraction (no grounding to source doc)
- PRD missing the Nova/FDE/System-of-Outcomes section, or it is clearly LLM-generated paraphrase
- Any one of the three deliverables (PRD, POC, Technical Write-up) entirely missing
- Demo video missing or shows mock data only
- PRD-to-POC incoherence: PRD describes an architecture/framework/model the POC doesn't implement, or vice versa (signals the PRD was written without connection to the code)

---

# Cross-Reference Checks

Perform these after scoring individual dimensions. These catch coherence issues that per-section scoring misses.

**PRD ↔ POC Alignment**
- Framework/model in PRD matches what's imported/called in code
- Agent boundaries described in PRD match actual module/class boundaries in code
- If PRD claims structured output/function calling, verify it's actually used in prompts
- If PRD names a fallback strategy for bad-quality docs, check if it's implemented

**Messy Document Handling**
- Locate the messy/low-quality sample document in the repo
- Trace what happens when it's fed to the Extractor: do confidence scores drop? Are uncertain fields flagged?
- Does the Validator handle low-confidence inputs differently than high-confidence ones?
- Does the system fail loudly or silently on a truly illegible section?

**AI-Generated Content Signals** (flag, don't auto-fail unless Nova section)
- Uniform section structure across all PRD sections (real human writing has texture variation)
- Generic hedging ("It's important to note", "In today's rapidly evolving landscape")
- Failure modes that read hypothetical despite the assignment asking for "from your own testing"
- Code comments that explain what code does rather than why (suggests generated code with generated comments)
- Technical write-up that doesn't reference specific numbers/errors from the candidate's actual runs

---

# Output Format

Produce the review using this template:

```
# GoComet Nova Full-Stack AI Engineer — Part 1 Review Report

**Candidate:** [Name]
**Submission Date:** [Date]
**Stack:** [e.g., Python / FastAPI / LangGraph / OpenAI GPT-4o + Claude / SQLite / Streamlit]
**Reviewer:** [Name]

## Score Summary

| Dimension | Score | Max | Notes |
|---|---|---|---|
| Architecture & Code Quality | __/20 | 20 | |
| AI Craft | __/20 | 20 | |
| End-to-End Demo | __/20 | 20 | |
| PRD Depth & Nova Understanding | __/20 | 20 | |
| Outcome & Product Thinking | __/15 | 15 | |
| Communication | __/5 | 5 | |
| **TOTAL** | **__/100** | **100** | |

**Result:** [STRONG PASS / PASS / FAIL]
**Gate Decision:** [Unlock Part 2 / Unlock with feedback / Do not unlock]
**Auto-Fail Triggered:** [Yes / No] — if yes, list which

## Deliverables Received

- [ ] PRD (PDF or Google Doc)
- [ ] Working POC (repo or zip)
- [ ] Technical Write-up (PDF or Google Doc)
- [ ] README with setup
- [ ] At least 2 sample documents (one clean, one messy)
- [ ] 2-3 minute demo video
- [ ] Sample queries against stored output

## POC Behavior Checklist

- [ ] A: Extractor Agent — runs on PDF + image, all 8 fields, per-field confidence
- [ ] B: Validator Agent — match/mismatch/uncertain, found-vs-expected, no silent approval
- [ ] C: Router Agent — 3 outcomes, decision reasoning
- [ ] D: Storage + Query — queryable store + NL question works
- [ ] E: Minimal UI — shows real run state

## Nova Concept Check (PRD Section 1)

- [ ] What is Nova — own words, real comprehension
- [ ] FDE model explained
- [ ] System of Outcomes vs Record vs Engagement explained
- [ ] No copy-paste paraphrase from JD

## PRD Section Coverage

- [ ] 1. Nova Understanding (200-word cap respected per question)
- [ ] 2. Problem Statement (specific failure modes + first-5-minutes success)
- [ ] 3. Users + JTBDs (5+ in proper format, 2+ personas)
- [ ] 4. Agent Architecture (defends 3-agent boundary)
- [ ] 5. LLM & Tooling Choices (with tradeoffs, including where to avoid structured output)
- [ ] 6. Trust, Failure Handling & Evals
- [ ] 7. Metrics & Success Criteria
- [ ] 8. What's Next (with prioritization reasoning)
- [ ] PRD is execution-oriented, not a vision doc

## Technical Write-up Coverage

- [ ] Architecture diagram
- [ ] 3 nastiest failure modes (from candidate's own testing)
- [ ] Observability story
- [ ] Cost per document estimate
- [ ] Latency analysis
- [ ] Week-instead-of-day plans

## Detailed Findings

### Agent Architecture
- Boundary defense: [Strong / Adequate / Weak / Missing]
- Inter-agent communication: [Schema-bound / Dict / Implicit]
- Crash recovery: [Addressed / Hand-waved / Missing]
- Framework: [LangGraph / Custom / Other — justified?]
- PRD ↔ POC alignment: [Consistent / Minor drift / Incoherent]

### AI Craft
- Hallucination handling: [Grounded / Schema-only / None]
- Confidence per field: [Yes / Overall only / None]
- Messy doc behavior: [Graceful degradation / No difference / Not tested]
- Eval defined: [Offline + online / One / None]
- Cost awareness: [Quantified / Mentioned / Missing]
- Observability: [Concrete / Generic / Missing]

### Nova Understanding (Critical Signal)
- Section quality: [Original thinking / Paraphrase / Boilerplate / Missing]
- 200-word cap respected: [Yes / Exceeded / N/A]
- FDE comprehension: [Real / Surface / Missing]
- System of Outcomes: [Crisp / Confused / Missing]

### North-Star Metric
- Specific number: [Yes / No]
- Testable on Day 14: [Yes / No]
- One sentence: [Yes / No]

### Cross-Reference Results
- PRD-to-POC coherence: [Aligned / Drift / Incoherent]
- Rule set quality: [Realistic / Minimal / Stub]
- Amendment discrepancy listing: [Per-field / Summary / Missing]
- Auto-approve stores result: [Yes / No / N/A]
- AI-generated content signals: [None / Minor / Significant] — list specific flags if any

## Code-Level Findings

### Strengths
1. **[file:line]**: [specific observation]
2. **[file:line]**: [specific observation]
3. **[file:line]**: [specific observation]

### Issues
1. **[Severity: Critical/High/Medium/Low] - [file:line]**: [issue + impact]
2. **[Severity] - [file:line]**: [issue + impact]

## Recommendations

### Must Fix (Blocking Part 2)
1. [issue with file/page reference]

### Should Improve (Feedback to send with unlock)
1. [improvement]

### Nice to Have
1. [enhancement]

## Final Decision
**Score:** __/100
**Gate:** [Unlock Part 2 / Unlock with feedback / Do not unlock]
**Rationale:** [3-4 sentences covering the 60% tech / 40% product split]
**Strongest signal:** [specific thing that stood out]
**Weakest signal:** [specific thing that gave us pause]
**Readiness for FDE role:** [Strong / Promising / Concerns / Not ready]

---

## 📋 Shareable Hiring Team Summary

**Before generating this section, ask the reviewer for their name if not already known.**

**Concise, copy-paste ready for hiring team channel, email, or ATS. Keep it under 25 lines.**

```
Candidate: [Name]
Role: Full-Stack AI Engineer (Nova) — Part 1 Review
Reviewer: [Ask reviewer for name]
Date: [Date]

Verdict: [Strong Pass / Pass / Fail]
Score: [__]/100
Recommendation: [Unlock Part 2 / Unlock Part 2 with feedback / Do not unlock]

What worked
• [Strongest technical signal — cite specific code-level evidence]
• [PRD/product thinking signal — quote or paraphrase the candidate's sharpest insight]
• [Third strength — breadth signal, e.g., rule set quality, observability, query layer]

What to watch in Part 2
• [1-2 concise concerns with real-world impact. No more.]

Bottom line
[2-3 sentences. What does this candidate look like as an FDE? Readiness call.]

Suggested next step
- [One concrete action with specific feedback to include]
```

**Rules for writing this section:**
- No scores per dimension. No "auto-fail triggered" language.
- Strengths and concerns must be specific to this candidate — no generic statements.
- Tie concerns to real-world impact so non-technical readers grasp the stakes.
- "Bottom line" is what hiring will quote in their decision meeting. Make it count.
- If declining, frame as fit/readiness, not personal critique. The candidate may reapply later.

---

# Pre-Finalization Checklist

Before submitting the review, verify:

- All three deliverables (PRD, POC, Tech Write-up) reviewed
- All five POC behaviors (A-E) traced in code, not just claimed in README
- Nova/FDE/System-of-Outcomes section read carefully for original thinking
- 200-word cap checked on each Nova sub-answer
- 8 required fields verified in extractor output schema
- Validator output checked for "uncertain" status, not just match/mismatch
- Customer rule set reviewed for realism (not a trivial 2-field stub)
- Router agent reasoning verified in actual decision output, not just prompt
- Auto-approve path verified to store results (not just approve)
- Amendment output verified to list per-field discrepancies (field, found, expected)
- Storage queryable AND NL question support working
- UI shows real run data, not hardcoded
- Messy/low-quality sample doc traced through the pipeline — graceful degradation verified
- PRD-to-POC coherence checked (framework, model, architecture match)
- AI-generated content signals checked across all deliverables
- Auto-fail conditions checked
- Specific file/line and PRD page references in every finding
- 60/40 tech/product weighting respected in final rationale
- Gate decision (unlock Part 2 or not) explicit and justified
