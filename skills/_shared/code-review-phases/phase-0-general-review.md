# Phase 0 — General Review (Judge 1: correctness)

This phase covers what the conventions-focused Phase A/B do not: correctness bugs, security issues, and clear reuse/simplification opportunities — the same territory Claude Code's built-in `code-review` skill covers, generically, for any codebase.

## Step 1 — attempt to delegate to the real built-in skill

Invoke the `Skill` tool with `skill: "code-review"` (no path prefix — this refers to the globally-available built-in skill, not this harness; the harness skills are named `ruby-code-review` and `ruby-pr-review`, distinct names, specifically so this reference is unambiguous and cannot resolve back to themselves). Pass `args` that explicitly scope the review to this PR's actual diff against its base branch (e.g. "review only the diff against the PR's base branch — do not review the full working tree"). Never invoke it bare with no scope: its own default "current diff" behavior isn't something this harness controls, and observed in practice, an unscoped invocation reviewed the entire working tree — including unrelated local/untracked changes that happened to be sitting there — instead of just this PR's changes.

- If this succeeds and produces findings genuinely scoped to the PR's diff (likely via its own `ReportFindings` call), carry those findings forward — they get merged into this harness's own final `ReportFindings` call in Phase B's output step, not reported a second time separately.
- If this call fails, errors, is unavailable in the current environment, **or returns findings for files that aren't actually part of this diff** (a sign it ignored the scope and reviewed the working tree instead), discard those out-of-scope findings and fall through to Step 2. Do not retry it — one attempt only.

## Step 2 — fallback: inline general review

If Step 1 didn't produce usable findings, perform a single, straightforward pass over the diff yourself:

- **Correctness bugs**: logic errors, off-by-one mistakes, incorrect edge-case handling, nil/blank handling that doesn't match the surrounding code's conventions.
- **Security issues**: injection risks (SQL, shell, template), exposed secrets or credentials, missing authorization checks, mass-assignment holes, unsafe deserialization (`Marshal.load`, `YAML.unsafe_load`, `send` on user input).
- **Reuse/simplification**: duplicated logic that already exists elsewhere in the diff or nearby files, obviously over-complicated code for what it does.

This is intentionally a single lightweight pass, not a substitute for the built-in `code-review` skill's deeper modes (`high`, `max`, `ultra`) — if a developer wants that level of depth, they should invoke `code-review` directly with an explicit level, outside of this automatic Phase 0 step.

## Reporting

Findings from either step 1 or step 2 get tagged `category: "general"` when they reach the final `ReportFindings` call (see Phase B's output step) — distinct from `"mechanical"` (Phase A) and `"convention"` (Phase B).
