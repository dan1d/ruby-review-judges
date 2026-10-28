# Phase C — Approach Review (Judge 4)

Phases 0, A and B ask "is this change correct, clean and conventional?". This phase asks the question a senior reviewer asks first: **"did this need to be this big?"** It judges the shape of the solution, not its lines.

It exists because a change can pass every other judge and still be the wrong size: new columns where existing ones would do, a model validation where the entry point already validates, a service where a controller method was enough. Those get caught in human review, after the work was done. This phase catches them before.

## 1. Reconstruct the requirement

From the PR description, the linked ticket (if readable) and the diff itself, write the requirement in one sentence and the acceptance criteria as bullets. If the PR description already lists the approaches that were considered and why they lost, read that first: this phase then only checks that the stated reasons hold.

## 2. Climb the ladder on the delivered change

Take the diff as a whole and ask, in order, stopping at the first rung that would have fully satisfied the requirement:

1. Did every part of it need to exist? Name any feature, option or flexibility the requirement did not ask for.
2. Was there something already in the codebase that could have carried it: an existing column or list, a helper, a serializer option, a validation pattern on a neighbouring controller, a prior feature of the same shape?
3. Standard library or platform feature?
4. An installed dependency?
5. Could a piece be one obvious line?
6. Otherwise, is this the minimum that works?

Read the surrounding code to answer rung 2. Grep for the same column names, the same concept, the same kind of validation elsewhere. Do not answer from the diff alone.

## 3. Decide whether a materially smaller complete approach exists

"Materially smaller" means at least one of:
- removes a migration, backfill task or destructive follow-up the change introduces;
- removes a new class (model, service, job) whose job an existing object already does;
- cuts the touched files by roughly a third or more;
- moves a check to the layer the team's conventions say it belongs in (for example entry-point validation instead of model validation), with no loss of behaviour.

"Complete" means it still meets every acceptance criterion, keeps validation at trust boundaries, error handling, security and the callers and specs the change needs. A smaller approach that drops a requirement is not an alternative; mention it only as a product question.

## 4. Report

- **No materially smaller complete approach:** report one finding with `category: "approach"`, severity low, summary "Approach: smallest complete shape", and one sentence on which rung it sits on and why the next rung down does not work. The developer should see that Judge 4 looked.
- **One exists:** report one finding per alternative (at most three), `category: "approach"`, severity by cost: high when it removes a schema change or a new class, medium when it only cuts files, low when it is a layer move. Each finding states:
  - what the alternative keeps and what it replaces (name the existing thing it reuses);
  - the estimated reduction (files, migrations, classes);
  - the convention that supports it, by file and heading, when one exists;
  - what the alternative cannot do that the delivered change can, honestly;
  - the cost of skipping it: what the reviewer will ask, and what gets reworked after merge if nobody does.

Never fix. Never edit. An approach finding is a conversation starter for the author and reviewer, not a mechanical correction. If the PR description already explains why the smaller approach was rejected and the reason holds, report PASS and quote the reason.

## 5. Bound

One pass. If the requirement cannot be reconstructed from the PR and ticket, say so in the finding and judge only what the diff makes obvious. Do not speculate about product intent.
