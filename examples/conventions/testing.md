# Testing Conventions (example)

## Don't use `described_class` in specs

Reference the actual class name in specs, not RSpec's `described_class`.

**Why:** a spec should be readable on its own without looking up the outer `describe` block.

## Don't test third-party/library behavior

Don't write a test asserting the default behavior of a gem your code merely uses (e.g. a pagination
gem's default page size). Test the code you actually wrote.
