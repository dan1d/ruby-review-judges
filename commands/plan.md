# /plan — three approaches first, then judges, then phases

Analyse the task and produce a phased execution plan before doing any work.

**Task:** $ARGUMENTS

## Instructions

1. Detect project context: read `CLAUDE.md` (and `AGENTS.md` if present) for stack,
   conventions location, quality gates and available agents.

2. Approach exploration (mandatory, before any phase is drafted):
   - Invoke the `ruby-approach-plan` skill (outside Ruby, apply the same contract by
     hand): read the code the task touches, then write at least THREE materially
     different approaches — reuse (no schema change; existing columns, helpers and
     entry points), extend (additive migration + backfill + later cleanup),
     restructure (blank-page design) — each with its ladder rung, estimated files,
     schema and deploy steps, conventions for/against, what it cannot do, and the
     reviewer's first objection.
   - Invoke the `approach-judge` agent on that set. FAIL (fewer than three kinds, or
     variants of one idea) → adopt the approaches it produces and re-run once.
     WARN → justify the recommendation or lower it.
   - Present the comparison table and ask the user to pick (AskUserQuestion when
     available, recommended option first). Do not continue until they choose.
   - Carry the chosen approach and the rejected ones (one paragraph) into the plan
     and, later, into the PR description under "Approaches considered".

3. Draft the phased plan for the chosen approach: one deliverable per phase, each
   with a measurable completion check and the files it touches.

4. Invoke the `plan-judge` agent: infrastructure coverage, end-to-end path,
   error paths, environment/config, verification strategy, integration points.
   On WARN or FAIL: revise with its findings and re-invoke (max 2 retries); if
   still failing, present the plan with the unresolved findings.

5. Invoke the `taste-judge` agent on the plan: scope creep, premature
   architecture, vague success criteria. On WARN or FAIL: cut "while we're at
   it" phases, inline premature abstractions, add measurable checks; re-invoke
   once.

6. Present the plan for approval. Implement only after approval, phase by phase,
   with the smallest code that solves the stated problem, matching existing style.

7. After implementation:
   - Run the test suite (`bundle exec rspec` / `npm test` as the repo dictates)
     and the linter; report counts and remaining issues.
   - Invoke `approach-judge` on the diff. FAIL (a smaller complete approach
     removes a migration, a backfill or a new class) → stop and show the user
     before marking done; WARN → note it in the summary and the PR description.
   - Invoke `impl-judge` (nothing unwired), `test-judge` (tests are meaningful)
     and `taste-judge` (code). Fix FAILs before marking done; note WARNs.
   - Run the review skill (`ruby-code-review`) for the four-judge diff review.

8. Summarise: chosen approach and why, what shipped, judge verdicts, what was
   skipped or not verified.
