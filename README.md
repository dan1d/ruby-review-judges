# ruby-review-judges

A project-agnostic, four-judge code review harness for Ruby repos, plus a planning skill that
forces three approaches before any code, packaged as [Claude Code](https://claude.com/claude-code)
skills with an optional RuboCop cop and a diff-scoped CI script.

Every review runs four independent judges over the **diff only**, then reports all findings in
one place, most-severe-first. It reports by default and never fixes unless you explicitly ask.

| Judge | Phase | What it checks | How |
|---|---|---|---|
| 1 — Correctness | Phase 0 | Bugs, security, obvious reuse/simplification | Delegates to Claude Code's built-in `code-review` skill, scoped to the diff; falls back to an inline pass |
| 2 — Mechanical | Phase A | RuboCop offenses on the lines the PR touched | `rubocop --format json`, filtered by `git diff -U0` hunk ranges |
| 3 — Conventions | Phase B | Your team's written conventions + a built-in "needless wrapper method" judgment | Reads your `docs/conventions/*.md` (or wherever they live) fresh on every run |
| 4 — Approach | Phase C | Did this need to be this big? Climbs the [ponytail](https://github.com/dietrichgebert/ponytail) ladder on the delivered change and reports any materially smaller complete alternative (no new storage, no new class, fewer files, the check in the layer your conventions name) | Reads the surrounding code and your conventions; always reports one `approach` finding, even when the verdict is "smallest complete shape" |

Anything real but outside the diff is reported as `out-of-scope`, never fixed, never dropped.

## Before the code: three approaches, not one

`skills/ruby-approach-plan` runs when you pick up a ticket. It reads the code the change touches,
then writes at least three materially different approaches — **reuse** (no schema change, the
columns and helpers you already have), **extend** (additive migration + backfill + later cleanup),
**restructure** (the blank-page design) — each placed on the ponytail ladder, checked against your
conventions, with what it cannot do and the first question a reviewer will ask. It recommends the
lowest complete rung and makes you pick before a line is written.

Why: a real ticket shipped as 22 files with new columns, a service and a backfill, and ended as 5
files reusing columns the table already had. All three versions worked. Only the last was what the
reviewer wanted, and it was visible on day one once the alternatives were written down.

## Contents

```
skills/
  ruby-approach-plan/      "plan ENG-123" — three approaches, comparison, pick before coding
  ruby-code-review/        "review this" on local changes
  ruby-pr-review/          "review PR #123" — isolated worktree, reads existing PR comments, optional posting
  _shared/code-review-phases/
    phase-0-general-review.md
    phase-a-rubocop-loop.md
    phase-b-conventions.md
    phase-c-approach.md
rubocop/
  lib/rubocop/cop/review/single_use_trivial_method.rb   custom cop (RuboCop >= 1.x)
  spec/                                                  its spec (13 examples)
  rubocop.yml.example                                    config snippet
bin/rubocop_diff_check     diff-scoped CI gate, no LLM involved
examples/conventions/      the file shape Phase B expects
install.sh
```

## Install

```bash
git clone https://github.com/dan1d/ruby-review-judges.git
cd ruby-review-judges

# skills only
./install.sh /path/to/your-ruby-repo

# skills + custom cop + CI script
./install.sh /path/to/your-ruby-repo --with-rubocop
```

Then, in your repo:

1. Put your team conventions somewhere Phase B can find them (see below), or point
   `CONVENTIONS_PATH` at them.
2. If you installed the cop, merge `rubocop/rubocop.yml.example` into your `.rubocop.yml`.
3. Open Claude Code in the repo and say `review this` or `review PR #123`.

## Where conventions live

Phase B resolves your conventions in this order and stops at the first hit:

1. `CONVENTIONS_PATH` env var
2. `.claude/settings.local.json` → `env.CONVENTIONS_PATH`
3. `docs/conventions/`, `.claude/conventions/`, `CONVENTIONS.md`, or `@`-imports in `AGENTS.md`/`CLAUDE.md`
4. Asks you once, then persists the answer to `.claude/settings.local.json`

If there are none, Judge 3 still runs its built-in single-caller-method check and the report says
plainly that no convention docs were found.

A convention file is just markdown: one heading per rule, the rule, and a **Why**. See
`examples/conventions/`.

## Trigger phrases

| Say | Skill |
|---|---|
| `plan ENG-123`, `pick up this ticket`, `how should we implement X`, `options for X` | `ruby-approach-plan` |
| `review this`, `code review`, `check this against our conventions` | `ruby-code-review` |
| `review PR #123`, `code review https://github.com/o/r/pull/123` | `ruby-pr-review` |
| `review and fix what you can` | either — fixes are applied only because you said so |
| `... and post the findings to the PR` | `ruby-pr-review` posts; otherwise nothing leaves your session |

Asking for `code-review ultra` or an explicit effort level is still handled by the built-in skill
directly; these skills do not intercept that.

## The custom cop: `Review/SingleUseTrivialMethod`

Flags a **private** method whose body is a single non-branching expression and which is called from
exactly one site in its class — the "needless wrapper" that exists only to satisfy a line-count
linter. It is deliberately narrow:

- silent on anything with branching, multiple statements, memoization (`||=`), or `permit`/`permit!`
- silent on long chained bodies (more than 3 calls) — whether that is real complexity worth naming
  or accidental indirection is a judgment call, so Judge 3 makes it on every run instead

Offense messages end with a tag the skills route on:

- `[auto-fixable]` — report it with the exact fix; apply only if fixes were requested
- `[needs-judgment]` — never auto-fix; hand it to Judge 3

Any cop you add that follows the same suffix contract plugs into the same flow with no skill changes.

Run its spec:

```bash
cd rubocop && bundle install && bundle exec rspec
```

## Why diff-scoped

RuboCop lints whole files. Turning on a new cop against an old codebase normally means either a
huge `Exclude:` list or a flag-day cleanup. `bin/rubocop_diff_check` instead runs the cop on every
changed file, then discards any offense whose line is outside the ranges this branch actually
changed. Pre-existing debt is grandfathered by scope, not by file, and the list never grows.

```bash
bin/rubocop_diff_check                                   # default cop, against origin/<default branch>
bin/rubocop_diff_check --cops=Review/SingleUseTrivialMethod,Style/GuardClause --base=origin/develop
```

Exit 1 with a listing when the branch introduced an in-scope offense; exit 0 otherwise. Wire it
into CI next to your normal `rubocop` run.

## Design rules the skills enforce on themselves

- Report, don't fix, unless the request said to fix.
- Never touch the user's checkout for a PR review — always a worktree.
- Never post to GitHub unless asked; never resolve review threads.
- Never re-report in Judge 3 something Judge 2 already flagged.
- Re-read conventions every run; never trust ambient session context.
- Bound any fix loop at 3 attempts per file, then report.

## License

MIT
