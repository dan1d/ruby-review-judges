---
name: ruby-approach-plan
description: "Trigger: plan this ticket, new ticket, pick up ENG-123, how should we implement, approach options, before we start coding. Produces at least three materially different approaches to a change (reuse, extend, restructure), each placed on the ponytail ladder and checked against the team's conventions, then recommends the smallest complete one and asks the developer to pick before any code is written."
license: MIT
metadata:
  version: "1.0"
---

## Why this skill exists

A plan that starts from one idea gets implemented, reviewed, and reworked around that idea. The reviewer then asks the question nobody asked at the start: "why do we need this at all?" One real case: a ticket shipped as 22 changed files with new columns, a service and a backfill, and ended as 5 files that reused columns the table already had. All three versions worked. Only the last one was what the reviewer wanted, and it was findable on day one by listing alternatives before picking.

So: **no implementation plan with a single approach.** Three materially different ones, compared, then a choice.

The ladder below is the [ponytail](https://github.com/dietrichgebert/ponytail) ladder (MIT, by Dietrich Gebert). It is used here as the axis the approaches are placed on, not as a replacement for reading the code.

## Activation Contract
Load when a developer is about to start a ticket or asks how to implement something, before any file is edited: "plan ENG-123", "pick up this ticket", "how should we do X", "options for X", or when a planning command invokes it. Do not load for a bug fix with one obvious root cause or for a change the developer has already specified file by file; say in one line why it was skipped.

## Hard Rules
- **Understand before proposing.** Read the code the change touches and trace the real flow: models, columns, serializers, services, jobs, the frontend fields that send the data, the specs that exist. List what already exists that could carry the change. An approach that ignores an existing column, helper or pattern is not an approach, it is a guess.
- **At least three approaches, of three different kinds** (see the kinds below). Two variants of the same idea do not count. If a kind is genuinely impossible, say so with the reason in one line and still present the other two plus a fourth of a different kind.
- **Every approach is complete.** Each must satisfy the whole requirement, including validation at the entry point, error handling, callers, specs and the frontend side. Smaller never means a feature was dropped silently. What an approach cannot do is listed under its own heading, never hidden.
- **Place each approach on the ladder** and name the lowest rung it reaches. The recommendation is the lowest rung that is complete, unless a listed convention or a stated product constraint rules it out.
- **Check each approach against the written conventions** the repo imports (`CONVENTIONS_PATH`, `docs/conventions/`, `CLAUDE.md`/`AGENTS.md` imports). Cite the rule by file and heading, for or against. A convention that forbids an approach is a reason; "it feels cleaner" is not.
- **Write the reviewer's question.** For each approach, one line: the first thing a senior reviewer who dislikes extra moving parts would ask. If the answer is weak, say so.
- **Stop and ask.** Present the comparison and the recommendation, then ask the developer to pick (use `AskUserQuestion` when available, with the recommended option first). Write no code until they answer. If the session is non-interactive, implement the recommendation and state that the choice was made by default.

## The ladder
Take the first rung that fully works:

1. Does it need to exist? What was asked, minus features nobody asked for.
2. Is it already in this codebase: a column, helper, service, pattern, serializer option?
3. Standard library or platform feature?
4. An installed dependency?
5. Can it be one line a reader gets at a glance?
6. Otherwise, the minimum code that works.

Never cut: validation at trust boundaries, error handling that prevents data loss, security, anything the ticket asked for.

## The three kinds

| Kind | Rungs | What it looks like | Typical cost |
|---|---|---|---|
| **Reuse** | 2 to 5 | No schema change. The existing columns, lists, helpers and entry points carry the new behaviour; the API may change shape, the storage does not. | Smallest diff; may carry a known limitation of the existing storage |
| **Extend** | 6 | Additive data-model change: a new column, flag or table, with migration, backfill task and a later destructive step. Delivery or readers change to use the new storage. | Medium diff, three deploy steps, a follow-up PR |
| **Restructure** | 6 | The design you would pick on a blank page: new model, join table, service object, moved responsibility. | Largest diff; justified only when the existing structure is the actual problem |

Optional fourth: **Push back.** The requirement, or part of it, may not need building. One line, with the question to take to the product owner.

## Execution Steps
1. Restate the requirement in one sentence, plus the acceptance criteria as bullets. Mark anything ambiguous.
2. Read the touched code. Produce a short "what exists" list: tables and columns involved, serializers, services and jobs that read or write them, the frontend fields, the specs. Grep for prior art (a similar feature already solved the same shape).
3. Draft the three approaches using the card below. Fill every heading; "n/a" is allowed only with a reason.
4. Build the comparison table and pick the recommendation by the ladder rule.
5. Present it and ask the developer to choose. Do not start implementing.
6. Record the choice and the rejected approaches in one paragraph at the top of the plan (and in the PR description later), so a reviewer sees the alternatives were considered and why they lost.

## Approach card (one per approach)

```
### <Kind>: <one-line name>
Ladder rung: <n> — <why it stops here>
What changes: <areas and an estimated file count; name the files you already know>
Schema: <none | additive: ... | destructive follow-up: ...>
Deploy steps: <1 line each; include backfills and their dry-run>
Conventions: <rule (file § heading): for / against>
What it cannot do: <limits, stale-data cases, anything dropped>
Risk: <the realistic failure and who notices>
Reviewer's question: "<the first objection>" — <your answer, honestly rated>
```

## Comparison table

| | Reuse | Extend | Restructure |
|---|---|---|---|
| Rung | | | |
| Files touched (est.) | | | |
| Schema / migration | | | |
| Backfill / follow-up PR | | | |
| Conventions for / against | | | |
| Known limitation | | | |
| Reviewer's question answered? | | | |

**Recommendation:** the lowest rung that is complete, with the one sentence that justifies it. If the developer or a convention pushes toward a higher rung, name the limitation of the lower one that justifies the extra cost.

## Output Contract
One message containing: the requirement restated, the "what exists" list, three (or four) approach cards, the comparison table, the recommendation, and the question to the developer. No code, no file edits, no branch created. When `AskUserQuestion` is available, the pick is collected through it with the recommended approach listed first.

## Worked example (shape only)
Requirement: "Practice settings must pick notification recipients among the practice's users instead of free-text emails."
- What exists: six serialized text lists on `practices` (emails and SMS numbers per kind), read by two delivery services and an SMS opt-out webhook; `users.email` and `users.sms_number`; a serializer with per-render options; a controller that already validates ids against the practice for another feature.
- Reuse (rung 2): accept user ids, validate in the controller, write the users' email and number into the existing lists; serializer resolves lists back to ids. 5 files, no migration. Limitation: a legacy address with no user drops off on first save.
- Extend (rung 6): three id-array columns on practices, model readers, migration, backfill, destructive PR later. 21 files.
- Restructure (rung 6): join table `practice_recipients(practice_id, user_id, kind)` with a model and associations. 25+ files.
- Reviewer's question on Extend and Restructure: "why do we need new storage when the lists already exist?" Weak answer. Recommendation: Reuse.
