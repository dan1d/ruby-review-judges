# Phase B — Conventions Review (Judge 3: project conventions)

## 1. Resolve where the project's conventions live
In this order — do not invent a different order:
1. If `CONVENTIONS_PATH` is already set in this session's environment and it points at an existing file or directory, use it.
2. Else read this repo's `.claude/settings.local.json`; if it has `env.CONVENTIONS_PATH` pointing at an existing file or directory, use it.
3. Else probe these default locations, relative to the repo root, and use the first that exists:
   - `docs/conventions/` (directory of `*.md` files)
   - `.claude/conventions/` (directory of `*.md` files)
   - `CONVENTIONS.md` (single file)
   - `AGENTS.md` or `CLAUDE.md` containing `@`-imports of convention files — follow those imports
   - a sibling repo `../<name>-docs` or `../system-documentation` containing an `AGENTS.md` with the same import structure
4. Else ask the developer where their conventions are. Once given a path, verify it exists, then persist it to `.claude/settings.local.json` under `env.CONVENTIONS_PATH` (create the file if missing, preserve existing keys) so future sessions skip this step.
5. If the developer says there are none, continue: §5 below still runs (it needs no docs), and the final output must state plainly that no project convention docs were found, so nobody mistakes "no convention findings" for "conventions were checked."

## 2. Load applicable convention docs
- Read every convention file found in §1 — read them now, in this task, even if session-start context already injected them.
- If the conventions index (an `AGENTS.md`/`README.md` alongside them) has an "on-demand" table mapping task areas to extra docs, also read each row whose area matches the diff.
- If unsure whether a row matches, read it anyway — cheaper than missing a convention.

## 3. Review the diff
For each changed file, check the lines the PR's diff actually added or modified against every loaded convention doc, not just the one most related to the trigger phrase — all loaded docs are in scope every time. Reading a whole file for context is fine; attributing a violation to this PR for code the diff didn't touch is not.

- If a violation is in code this diff added or modified: report it normally (`category: "convention"`, per §4 below).
- If you notice a real issue in nearby code the diff never touched (pre-existing): don't fold it into this PR's findings as if it were introduced here, and don't silently ignore it either — report it with `category: "out-of-scope"`, same convention Phase A uses, stating plainly it predates this PR so a human reviewer can decide whether it's worth a follow-up.

Skip anything a RuboCop cop already deterministically covers and reported as mechanical in Phase A — don't duplicate it here. Phase B exists for the judgment-based remainder that can't be reduced to an AST rule alone. `Review/SingleUseTrivialMethod` only ever fires on the unambiguous, trivially-short case (`[auto-fixable]`) — it stays silent on a longer single-caller method rather than guessing whether that's needless indirection or legitimate complexity. §5 below is where that judgment actually happens, every time Phase B runs, independent of whether Phase A found anything.

## 4. Report via `ReportFindings`
One finding per convention violation:
- `file` — the changed file's path.
- `line` — the offending line.
- `category` — `"convention"`.
- `summary` — which doc + rule, e.g. "service-patterns.md: needless wrapper/indirection method."
- `failure_scenario` — the concrete consequence a reviewer would flag this for, not just "violates convention X."
- `short_summary` — one line, imperative fix.
- `verdict`/`outcome` — a convention violation with no functional bug is a lower-severity/style-tier finding, not a correctness bug.

Order most-severe-first. If a loaded doc has zero violations in this diff, don't fabricate a finding.

## 5. Check every single-caller method directly for needless indirection
This check does not depend on Phase A having flagged anything, and does not depend on any convention doc existing — `Review/SingleUseTrivialMethod` deliberately never emits an offense for this case (see the cop's class comment), so it is entirely Phase B's own responsibility, run on every diff, every time.

For each method in the diff's changed lines that's called from exactly one site within its class (the common case is a private Ruby method, but apply the same logic to any single-caller helper regardless of visibility):
- Read the method's actual body.
- Apply the real test for "avoid needless wrapper/indirection methods": is this method's existence justified by reuse across multiple call sites (it isn't — that's why it's a candidate) OR by naming something genuinely complex or meaningful on its own (a multi-join SQL builder, a multi-step data transformation)? If the latter, it is NOT a violation — recommend keeping it, and say why in one sentence.
- If neither applies (it's long only because of formatting or accidental complexity, not real complexity worth naming), recommend inlining it.
- Report the verdict either way via `ReportFindings` with `category: "convention"` — even a "no violation, keep as-is" verdict should be recorded so the developer sees Phase B actually looked at it, rather than silently dropping it.

Every candidate here comes from this diff's own changed lines (§3 above), so it's always this PR's own code — none of this section's candidates need the whose-code-is-it branching in §6 below.

## 6. A "keep" verdict encountered outside an active diff (e.g. debugging a broken CI run)

§5 above covers a single-caller-method judgment made *during a live skill run against a specific diff* — always in-diff, by construction. This section is different: it's for a `[needs-judgment]` offense from some other cop, found by running plain `bundle exec rubocop` directly, with no PR diff in context at all — e.g. investigating why CI is red. There, "in-diff" has no meaning, since there's no diff being scoped; what matters instead is **whose code it is**:

RuboCop itself has no concept of "reviewed and judged fine" — a `[needs-judgment]` offense left as-is fails CI regardless of any judgment call, since CI just runs the cop with no awareness of this harness's reasoning. A "keep" verdict here still has to resolve to *something* that makes RuboCop stop flagging it:

- **Code from the work currently being prepared** (yours to touch — e.g. new code in a branch you're actively developing): recommend an inline `# rubocop:disable <CopName>` / `# rubocop:enable` pair around the offending code, with a one-line reason comment, in that same file. No different from how most codebases already handle a justified `# rubocop:disable Metrics/MethodLength`. Doesn't touch anyone else's files, doesn't grow any shared list. Report it as a finding with the exact suggested comment text; only apply it if fixes were explicitly requested (same report-by-default rule as everywhere else in this harness).
- **Pre-existing code unrelated to the current work** (arrived via someone else's merge, blocking a full-repo `bundle exec rubocop` run): do **not** edit that file — it isn't yours to touch as an incidental change. Recommend adding it to that cop's own `Exclude:` list in `.rubocop.yml` instead, with the reasoning documented as a comment next to the entry. This should stay the rare exception — routing every "keep" here regardless of whose code it is would grow this list without bound.

(`Review/SingleUseTrivialMethod` is not a live example of this — it never uses `[needs-judgment]`, precisely to avoid this section's `Exclude:`-list-growth trade-off for the single-caller-method case. This section stays as infrastructure for a future cop that does need the tag.)
