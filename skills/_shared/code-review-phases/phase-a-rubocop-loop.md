# Phase A — RuboCop Loop (Judge 2: mechanical)

RuboCop lints whole files, not diff hunks — running it on every changed file will surface offenses in code the current PR never touched (pre-existing debt that happens to share a file with a real change). Never treat those as this PR's responsibility. Filter by diff scope before doing anything else.

`<base>` below is the PR's base branch (`origin/<baseRefName>` from pr-setup.md), or the repo's default branch when reviewing local work. If `bin/rubocop_diff_check` from this harness is installed in the repo, you may run it (`bin/rubocop_diff_check --base=<base> --cops=<cop list>`) to get steps 1–4 done deterministically for the listed cops; the manual procedure below is the reference behaviour either way.

FOR each changed `*.rb` file:
├── 1. Get this file's changed line ranges: `git diff -U0 <base>...HEAD -- <file>`,
│      parsed from the `@@ -a,b +c,d @@` hunk headers (the `+c,d` part — starting
│      line and span in the new file version). These are the only lines this PR
│      is responsible for.
├── 2. RUN: `bundle exec rubocop --force-exclusion --format json <file>` and read
│      each offense's line number.
├── 3. IF clean → done for this file, proceed to Phase B.
├── 4. IF offenses, split them by scope FIRST, before deciding what to do with any of them:
│   ├── a. **In scope** (offense line falls inside a changed range from step 1):
│   │      this PR's responsibility. Continue to step 5.
│   └── b. **Out of scope** (offense line falls outside every changed range —
│          pre-existing code the PR happened to share a file with): never fix
│          this, never loop on it, never count it against any attempt bound.
│          Still report it — via `ReportFindings` with `category: "out-of-scope"` —
│          with a summary that says plainly it's pre-existing and not part of this
│          PR's diff, so a human reviewer can decide whether it's worth a follow-up.
│          Silently dropping it would hide real technical debt from anyone; silently
│          fixing it would attribute an unrelated change to this PR.
├── 5. For each in-scope offense, read its message to decide how to report it —
│      default to reporting, never auto-fix, regardless of tag:
│      ├── a. Message ends with `[auto-fixable]` (e.g. `Review/SingleUseTrivialMethod`
│      │      on a short, simple body): report it via `ReportFindings` with
│      │      `category: "mechanical"`, naming the exact fix (e.g. "inline this
│      │      method at its one call site, then delete the definition"). Do NOT
│      │      apply the fix yourself unless the developer's request explicitly
│      │      asked for fixes to be applied (e.g. "review and fix what you can"),
│      │      not just "review this."
│      └── b. Message ends with `[needs-judgment]` (reserved for a cop whose
│              classification genuinely can't be made safely from AST shape alone —
│              `Review/SingleUseTrivialMethod` does not use this tag; see
│              phase-b-conventions.md §5 for why that specific check lives in Phase B
│              entirely instead): never auto-fix regardless of what was asked. Report it
│              as a Phase B judgment candidate, same category/format as any other Phase B
│              convention finding, and move on.
│   For offenses RuboCop itself marks as auto-correctable (stock cops, not
│   `Review/*`): same rule — report what it would change, only actually run
│   `bundle exec rubocop -a` if fixes were explicitly requested.
└── 6. If fixes WERE explicitly requested: apply in-scope `[auto-fixable]`/
       autocorrectable fixes by hand, bounded at 3 attempts per file, then
       re-run step 2 to confirm. Never apply a fix to an out-of-scope offense
       (step 4b) even when fixes are explicitly requested elsewhere in the
       PR — that's still not this PR's change to make.
