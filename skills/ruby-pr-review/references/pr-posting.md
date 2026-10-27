# PR Posting — Only When Explicitly Requested

This step only runs if the developer's request explicitly asked for findings to be posted to the PR (e.g. "post these as comments," "add this to the PR," "comment on the PR with these findings"). If it wasn't asked, skip this file entirely — reporting via `ReportFindings` in this session is the complete output.

## Posting a general comment
For a single overall summary comment:
`gh pr comment <ref> --body "<comment text>"`

## Posting a review with inline comments
For findings tied to specific files/lines, prefer a review over a plain comment, so they render inline on the diff:
`gh pr review <ref> --comment --body "<summary text>"`

(Inline, per-line comments require the GitHub API's review-comment endpoint with a commit SHA and diff position, which `gh pr review` alone does not expose — if the developer specifically wants inline comments, use `gh api repos/<owner>/<repo>/pulls/<number>/comments` with the required `commit_id`, `path`, and `line`/`position` fields, resolved from the PR's current head SHA. If unsure whether that's warranted, ask before making the API call, since it's a more elaborate action than a general comment.)

## Never resolve threads, never post silently
Reply to or add comments; never mark an existing review thread as resolved — that is the human reviewer's call. Always tell the developer, in this session's own reply, exactly what was posted and where (a link to the comment/review if `gh` returns one) — never post without that confirmation appearing in the conversation.
