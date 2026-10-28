# Design notes: why the harness looks like this

This is the design history behind the skills, the cop and the judges in this repo, ported
from the engineering docs of the team that built it. Names are generic here; the lessons are
not. Read it before changing a phase, adding a cop, or wondering why a review flagged (or did
not flag) something.

## Why this exists

An LLM's instruction-following is probabilistic. A convention loaded into a session is just
more text competing for attention; it does not override a strong training prior. "Extract
small single-purpose methods" is one of the most reinforced patterns in any model's training
data, so a team rule saying "do not extract a trivial method used once" loses even when it is
in context. It lost in practice: an agent kept producing one-line private methods with a single
caller inside service classes, straight against the written convention.

The fix is not a better prompt. Enforcement moves outside the model, with two mechanisms
depending on the kind of rule:

- **Deterministic** (answerable from code shape alone) → a RuboCop cop, run in CI, regardless of
  who or what wrote the code.
- **Judgment-based** (needs business or architectural context) → an explicit review step that
  re-reads the actual convention docs and applies judgment, instead of trusting whatever is
  already in the session.

A third kind of question turned out to need its own judge: **size**. A change can be correct,
clean and conventional and still be three times bigger than the requirement needed. That is
Phase C, added after a ticket shipped as 22 files, then 21, then 5, all three versions working.

## Two front doors, one shared core

`ruby-code-review` reviews local, uncommitted changes. `ruby-pr-review` reviews an open GitHub
PR: it resolves the PR with `gh`, works in an isolated worktree so it never switches the
caller's checkout, reads the PR's existing comments first so it does not re-raise what is
already being discussed, and never posts back unless explicitly asked. Both run the identical
phases from `skills/_shared/code-review-phases/`. Duplicating that logic into two skills would
mean fixing every bug twice.

## The cop contract

The skills never hardcode a cop's wording. Every custom cop ends its offense message with one
of two tags, and Phase A routes purely on the tag:

- `[auto-fixable]` — safe to fix mechanically. Reported by default; fixed only when the
  developer asked for fixes, bounded at three attempts per file.
- `[needs-judgment]` — never auto-fixed. Deferred to Phase B, which applies the convention text.

Adding a second or tenth cop never touches the skill. `[needs-judgment]` is infrastructure,
not a requirement: the shipped cop stopped using it (see below). Reach for it on a new cop only
when a case is unsafe to leave completely unflagged.

## The phases, always in this order

**Phase 0, general.** Delegates to Claude Code's built-in `code-review` skill for correctness,
security and simplification, scoped explicitly to the diff against the base branch. The
delegation is mandatory on every run: the inline fallback is allowed only when the call fails,
is unavailable or returns findings outside the diff, never to save cost or time, and the report
says which condition triggered it. This became a hard rule after an agent skipped the delegation
on three consecutive PR reviews to save tokens and silently lost the independent second
perspective. One attempt, never retried. The skills deliberately do not share the built-in's name: a
same-named project skill would shadow it, and Phase 0 invoking `code-review` from inside would
resolve to itself with no way to address the global one.

**Phase A, mechanical.** Runs RuboCop on the changed files, then filters every offense by whether
its line falls inside the diff's changed ranges (`git diff -U0 <base>...HEAD`). In-scope
offenses are reported, not fixed. Out-of-scope ones are reported as `out-of-scope`, never fixed,
never dropped.

**Phase B, conventions.** Resolves where the conventions live (`CONVENTIONS_PATH`, settings,
default folders, ask once), re-reads every convention doc itself (a subagent or fresh session
may not have them), reviews the diff's changed lines against them, and checks every
single-caller method directly for needless indirection, whatever Phase A said.

**Phase C, approach.** Reconstructs the requirement, climbs the ponytail ladder on the delivered
change, and reports whether a materially smaller complete approach exists: one that removes a
migration, a backfill, a new class, a third of the files, or moves a check to the layer the
conventions name, with no loss of behaviour. Always reports one `approach` finding, even when the
verdict is "smallest complete shape", so the developer sees the size was judged.

Everything lands in one `ReportFindings` call, most-severe-first: `general`, `mechanical`,
`convention`, `approach`, `out-of-scope`.

## Before the code: three approaches

Phase C catches size after the fact. `skills/ruby-approach-plan` catches it before: on a new
ticket it reads the touched code, then writes at least three materially different approaches,
reuse (no schema change), extend (additive migration plus backfill plus later cleanup),
restructure (blank-page design), each on the ladder, checked against the conventions, with what
it cannot do and the reviewer's first objection. It recommends the lowest complete rung and
stops until the developer picks. The rejected approaches go into the PR description, so the
reviewer sees they were considered.

The `approach-judge` agent is the same judgment as an agent: it fails a plan with one approach
and produces the missing ones; on a diff it gives the Phase C verdict. `commands/plan.md` chains
it with `plan-judge`, `taste-judge`, `test-judge` and `impl-judge`.

## Lessons from live testing

**Auto-fix was the wrong default.** The first live run rewrote a method the PR never touched,
because it lived in a file the PR touched elsewhere and the original Phase A auto-fixed by
default. Reviewing someone else's branch is not fixing your own work in progress. Fixed: report
by default, fix only on request, and filter by changed-line ranges first. A second live run
confirmed it: pre-existing offenses landed as `out-of-scope`, untouched, while the run reported
four real correctness bugs and three convention findings without editing a file.

**Phase 0 needs an explicit scope.** Unscoped, the built-in review read the whole working tree,
including unrelated local files. The phase doc now requires "diff against the base branch".

**Phases overlap.** Two findings that were arguably convention violations were caught by Phase
0's bug lens, not Phase B's convention read. Do not assume "Phase B read the doc" means every
violation of that doc is caught there.

**Shape-based bucketing is wrong for judgment calls.** Walking a list of single-caller methods
by hand: a six-key hash naming an audience-based decomposition of an API response → keep; a
`find_by` with four conditions naming a real domain query → keep; a string concatenation of two
params → inline. All three look identical to "single caller, no memoization". Only reading the
body and its caller gets the right answer.

**Forced invocation.** Natural language triggers are a wide net, not a guarantee. In Claude Code
a skill can always be invoked as a slash command (`/ruby-code-review`). This does not port to
Codex or Copilot CLI as-is.

## The shipped cop: `Review/SingleUseTrivialMethod`

Flags a private method whose body is a single non-branching expression with at most three
method calls, called from exactly one site. Deliberately narrow.

**Design change 1: it no longer classifies the complex case.** It used to tag longer chains
`[needs-judgment]`. A "keep" verdict on a well-named single-caller method is everyday good code,
so every keep grew a `.rubocop.yml` exclude list without bound. The cop now stays silent past the
threshold, and Phase B checks every single-caller method directly, every review. Cost: a long
single-caller method is invisible to a plain `rubocop` run and is only judged when a diff touching
it goes through the skills.

**Design change 2: no exclude list at all.** Grandfathering 70 files hid any new violation added
to them later. `bin/rubocop_diff_check` runs RuboCop unfiltered, asks git for the PR's changed
line ranges, keeps only offenses inside them, and fails only on those. CI runs plain RuboCop with
this cop excluded, plus the diff-scoped check for it. Pre-existing debt stays invisible until a
PR touches the exact lines, then it is that PR's responsibility, in any file.

**False positives already fixed** (do not rediscover): memoized `@ivar ||=` readers; Rails
strong-parameter methods; a body containing a block with real logic; index access and comparison
operators inflating the call count. **Accepted limitation:** a short credential-lookup chain still
over-counts as complex; since the cop is silent on that case anyway, the only consequence is that
Phase B judges it.

## What is portable to a cop, and what is not

If "does this violate the convention?" is answerable from an AST pattern alone, it belongs in a
cop. If it needs intent that is not in the code, it stays in Phase B. Some rules are not a
linter's job at all: PR title and ticket link formats belong in a PR bot, branch naming in a git
hook or CI check, frontend patterns in ESLint. Some cannot be mechanised: a per-tenant scoping
rule that caused two real data leaks needs careful review every time or an architectural fix,
not a lint rule.

## Open items

- `out-of-scope` is used for two things: outside the diff's changed lines, and "not verifiable
  from code alone" (an operational fact). Both legitimate, not the same concept.
- The delegated Phase 0 sometimes reports `correctness` instead of `general`; worth making it a
  formal category.
- Phase C has been dry-run against a three-version history of one ticket (it failed the first two
  designs and passed the third, citing the conventions the human reviewer used). It has not yet
  run on a stranger's PR.
