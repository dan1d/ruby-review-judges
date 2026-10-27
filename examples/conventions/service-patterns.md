# Service Object Conventions (example)

This is an example conventions file in the shape Phase B expects: a heading per rule, a short
statement of the rule, and a **Why** so the reviewer can tell a real violation from a lookalike.
Copy it to `docs/conventions/` in your repo and replace the rules with your team's own.

## Avoid needless wrapper/indirection methods

Don't add a method whose body is just a call to another method, with no validation, transformation,
or branching added. If a method only delegates, question whether it needs to exist. Don't extract a
fragment of a method into its own method purely to reduce line count or satisfy a complexity linter,
if the extracted piece isn't reusable or meaningful on its own.

**Why:** indirection for a metric, not for clarity, makes control flow harder to trace during
debugging. A linter warning can legitimately be silenced with a documented reason instead.

## Services raise; the flow owner logs

A service or lib class raises (a custom error, if needed) rather than logging directly. The job or
controller that invokes it is responsible for rescuing and reporting.

**Why:** one place owns each failure path, and internal details never leak to API clients.

## Services take resolved objects and a plain Hash

A service's public interface takes already-fetched records and a plain `Hash`, not
`ActionController::Parameters` and not a repository it has to query itself.

**Why:** keeps the business-logic object trivially testable with plain Ruby objects and keeps
IO/network failure modes isolated to the fetch layer.
