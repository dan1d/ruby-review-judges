---
name: ruby-code-review
description: "Trigger: review this, code review, check this PR, check against our conventions, team conventions, custom rubocop cops. Runs a three-judge Ruby review — general correctness/security pass, diff-scoped RuboCop offenses, and project conventions from your docs — reporting findings by default, fixing only when explicitly asked."
license: MIT
metadata:
  version: "1.0"
---

## Activation Contract
Load whenever a developer asks for any kind of code review while working in a Ruby repo — a bare "review this" or "code review," a PR check, or conventions-specific phrasing like "check this against our conventions." This skill is a superset of the generic built-in `code-review`: it runs a general correctness/security pass (Phase 0) plus a mechanical RuboCop pass (Phase A) and a judgment-based conventions pass (Phase B), so it's the natural target for both the generic and the conventions-specific request. The one caveat: if the developer explicitly asks for `code-review`'s own deeper modes (e.g. "run code-review ultra" or names an explicit effort level), that's still the global built-in's job to handle directly — don't intercept it.

## Hard Rules
- Phase 0 always runs first, before Phase A — see ../_shared/code-review-phases/phase-0-general-review.md. It attempts to delegate to the real built-in `code-review` skill by name (safe to do since this skill has a different name and cannot self-resolve); if that's unavailable, it falls back to a lightweight inline pass. Never skip Phase 0 entirely.
- Never skip Phase A (RuboCop) to jump to Phase B — mechanical offenses are resolved or explicitly surfaced first.
- Never rely on ambient session context for Phase B — always re-read the resolved convention docs in this task (see ../_shared/code-review-phases/phase-b-conventions.md), since a subagent or fresh session may not have them injected.
- **Default to reporting, never fixing.** Phase A reports every offense it finds — `[auto-fixable]` ones as a finding. Only apply an actual fix when the developer's own request explicitly asked for it (e.g. "review and fix what you can," not just "review this" or "code review"). Reviewing someone else's PR is not the same as fixing your own work-in-progress — don't silently rewrite a colleague's branch as a side effect of a review request.
- **Scope every phase to the diff, not the whole file.** RuboCop (and a careful read of nearby code) will surface things outside the lines this PR actually added or modified — pre-existing code that happens to share a file with a real change. Never treat that as this PR's fault, and never fix it. Report it separately as `category: "out-of-scope"` so a human decides what to do with it — don't fold it into this PR's findings, and don't silently drop it either. See phase-a-rubocop-loop.md §1 for the exact diff-range check.
- Any RuboCop offense whose message ends with `[needs-judgment]` is NEVER auto-fixed mechanically in Phase A, regardless of which cop produced it or whether fixes were requested — carry it forward as a judgment candidate for Phase B instead. It does not count against the 3-attempt bound. This tag is the contract every custom cop shipped with this harness follows — see the repo README for how to add a new cop.
- **Phase B checks every single-caller method for needless indirection directly, on every run — not only when RuboCop flagged something.** `Review/SingleUseTrivialMethod` deliberately stays silent on a longer single-caller method rather than guessing whether it's needless or legitimately complex; that judgment lives entirely in phase-b-conventions.md §5, every time.
- Bound the fix loop at 3 attempts per file, only when fixes were explicitly requested for in-scope `[auto-fixable]` offenses; on the 3rd unresolved failure, stop looping and report it instead.
- Report every finding through the `ReportFindings` tool when it is available. If it is not, use the markdown fallback table described in the Output Contract. Never prose-only.
- Never re-report in Phase B something a RuboCop cop already flagged in Phase A as mechanical.

## Decision Gates
| Situation | Action |
|---|---|
| Changed files include `*.rb` | Run Phase A on those files |
| An offense's line falls outside the diff's changed-line ranges for that file | Pre-existing, not this PR's responsibility — report as `category: "out-of-scope"`, never fix, never loop on it |
| RuboCop offense message ends with `[auto-fixable]` (in scope) | Report it (`category: "mechanical"`); only fix by hand, within the 3-attempt bound, if fixes were explicitly requested |
| RuboCop offense message ends with `[needs-judgment]` (in scope) | Never auto-fixable, regardless of what was requested — defer to Phase B as a judgment candidate |
| Convention docs location not yet known this session | Resolve it per ../_shared/code-review-phases/phase-b-conventions.md §1 before Phase B |
| No convention docs exist in this repo | Phase B still runs its built-in §5 single-caller check; say in the output that no project convention docs were found |
| A private, single-caller method appears in the diff, RuboCop or not | Always run Phase B §5's needless-wrapper judgment on it |
| An in-scope offense has no autocorrection and isn't obviously fixable | Leave it; report it as a Phase A finding instead of guessing |

## Execution Steps
1. Identify changed files (diff against the PR base or working tree).
2. Phase 0: general review — attempt delegation to the built-in `code-review` skill, falling back to an inline pass if unavailable — full procedure in ../_shared/code-review-phases/phase-0-general-review.md.
3. Phase A: run the bounded, diff-scoped RuboCop loop — full procedure in ../_shared/code-review-phases/phase-a-rubocop-loop.md.
4. Phase B: resolve the conventions location, load the applicable docs, and review the diff against them — including its own direct needless-wrapper-method check on every single-caller method, independent of Phase A — full procedure in ../_shared/code-review-phases/phase-b-conventions.md.
5. Report Phase 0's general findings, Phase A's unresolved offenses, and Phase B's convention findings together in one `ReportFindings` call, most-severe-first.

## Output Contract
A single `ReportFindings` call covering all phases: `category: "general"` for Phase 0's correctness/security/reuse findings, `category: "mechanical"` for in-scope RuboCop offenses (reported, not fixed, unless fixes were explicitly requested), `category: "convention"` for Phase B judgment calls, including its own needless-wrapper-method checks, and `category: "out-of-scope"` for anything real but outside this PR's actual diff (from any phase) — plus a short note on which convention docs were read, whether fixes were requested or this was report-only, and how many RuboCop loop iterations ran if fixes were applied.

If `ReportFindings` is not available in the current environment, emit one markdown table with the same columns instead: `severity | category | file:line | summary | failure scenario | suggested fix`, most-severe-first, followed by the same note.

## References
- ../_shared/code-review-phases/phase-0-general-review.md
- ../_shared/code-review-phases/phase-a-rubocop-loop.md
- ../_shared/code-review-phases/phase-b-conventions.md
