---
name: ruby-pr-review
description: "Trigger: code review PR, review PR #, review this PR (with a PR number or GitHub PR URL given), pull request review. Fetches an already-open GitHub PR via gh CLI, reads its existing comments for context, runs the shared three-judge Ruby review, and optionally posts findings back to the PR — only if explicitly asked."
license: MIT
metadata:
  version: "1.0"
---

## Activation Contract
Load when the request names a specific PR — a PR number (e.g. "PR #1583", "code review PR 1583"), a GitHub PR URL, or an explicit "review this PR" where a PR reference is present in context. This is the reviewer's tool: reviewing someone else's (or your own already-pushed) work that lives on GitHub, not your own local uncommitted changes. A bare "review this" or "code review" with no PR reference is `ruby-code-review`'s job instead — don't intercept that.

## Hard Rules
- Never operate on the user's current checkout directly. Always resolve or create an isolated git worktree for this specific PR first (see references/pr-setup.md) — this skill must never switch the branch out from under a session that might be doing unrelated work in the main checkout.
- Always read the PR's existing comments and reviews before analyzing the diff (see references/pr-setup.md) — the goal is context, not exhaustive deduplication: use it to avoid re-raising something already flagged and already being discussed, not to reason about whether something is "already resolved."
- The shared Phase 0/A/B analysis (references in `../_shared/code-review-phases/`) runs exactly as it does for `ruby-code-review` — do not reimplement or fork its logic here.
- Never post anything to the actual GitHub PR unless the developer's request explicitly asked for it (e.g. "post these as comments," "add this to the PR") — reporting findings back in this session is always the default. See references/pr-posting.md for how posting works when it is requested.
- Report through the `ReportFindings` tool, same categories as `ruby-code-review` (`general`, `mechanical`, `convention`, `out-of-scope`) — plus note, in prose alongside the tool call, whether anything was actually posted to GitHub or this was report-only.

## Decision Gates
| Situation | Action |
|---|---|
| Request includes a PR number or GitHub PR URL | This skill applies — resolve it per references/pr-setup.md |
| No dedicated worktree exists yet for this PR | Create one — never reuse/switch the current checkout |
| PR has existing comments/reviews | Read them for context before Phase 0 starts |
| Findings are ready and posting was NOT explicitly requested | Report locally only, via `ReportFindings` |
| Findings are ready and posting WAS explicitly requested | Report via `ReportFindings`, then post per references/pr-posting.md |

## Execution Steps
1. Resolve the PR reference (number or URL) and set up an isolated worktree for it — full procedure in references/pr-setup.md.
2. Read the PR's existing comments and reviews for context — same reference file, §3.
3. Phase 0: general review — ../_shared/code-review-phases/phase-0-general-review.md.
4. Phase A: mechanical RuboCop loop, diff-scoped, report-only by default — ../_shared/code-review-phases/phase-a-rubocop-loop.md.
5. Phase B: conventions review — ../_shared/code-review-phases/phase-b-conventions.md.
6. Report everything in one `ReportFindings` call, most-severe-first.
7. Only if posting was explicitly requested: post per references/pr-posting.md.

## Output Contract
Same as `ruby-code-review`'s (see `../ruby-code-review/SKILL.md`) — `category: "general"`/`"mechanical"`/`"convention"`/`"out-of-scope"` — plus an explicit statement of whether findings were posted to GitHub or kept local to this session.

## References
- references/pr-setup.md
- references/pr-posting.md
- ../_shared/code-review-phases/phase-0-general-review.md
- ../_shared/code-review-phases/phase-a-rubocop-loop.md
- ../_shared/code-review-phases/phase-b-conventions.md
