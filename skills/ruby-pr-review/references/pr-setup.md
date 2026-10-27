# PR Setup — Resolve, Isolate, and Read Context

## 1. Resolve the PR reference
From a PR number or URL, get its branch and basic metadata:
`gh pr view <ref> --json headRefName,baseRefName,title,url,files`
(`<ref>` is the PR number, or `owner/repo#number`, or the full URL — `gh` accepts all three when run from within a clone of the right repo.)

Keep `baseRefName` — it is the `<base>` every diff-scoped step in Phase A and Phase B uses (`git diff -U0 origin/<baseRefName>...HEAD`).

## 2. Set up an isolated worktree — never touch the current checkout
Check whether a worktree already exists for this PR's branch (`git worktree list`). If not, create one as a sibling directory named after the repo and the PR number:

```
git fetch origin <headRefName>
git worktree add ../<repo-name>-pr-<number> origin/<headRefName>
```

Do all subsequent work (reading files, running RuboCop, running the phases) inside that worktree directory — never in the main checkout, even if it looks idle. If a worktree for this PR already exists from a previous run, reuse it; refresh it if the remote branch has moved (`git fetch` + `git reset --hard origin/<headRefName>` inside the worktree — the same way you would resolve a rebase).

Also fetch the base branch inside the worktree (`git fetch origin <baseRefName>`) so the `<base>...HEAD` diff has an up-to-date merge base.

## 3. Read existing comments and reviews for context
`gh pr view <ref> --json comments,reviews`

Skim these before starting Phase 0. The goal is narrow: don't re-raise a finding that's clearly already been flagged and is already part of an active discussion thread. Don't try to determine whether a past comment was "resolved" — that's not reliably inferable from the API alone, and guessing wrong is worse than just proceeding. When in doubt, report the finding anyway; the human reviewer decides whether it's redundant.
