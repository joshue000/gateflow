# PR description template

Four fixed sections. Each has exactly one source of truth — never re-summarize a source that already
has the answer verbatim.

```markdown
## Summary

- {bullet per logical change, clustered from the FULL commit range}

## Review

{Gate 1 verdict + round count from the local review record, or "No review performed" if skipped}

## Notes

{optional — omit the whole section if empty}

## Test Plan

{verbatim from the ticket's test-plan source, or the generic fallback below}
```

## Variable sources

| Section | Source | Rule |
|---|---|---|
| Summary | `git log <base>..HEAD` — the **full** range, not just the last commit | A squash merge collapses history into the PR title/body — this is the only place multi-commit context survives. Cluster by concept, not one bullet per commit |
| Review | The local `docs/gateflow/reviews/<KEY>-review.md`'s latest round | State plainly if none exists — never imply a review happened |
| Notes | Free-form — architectural context, migration steps | Omit the section entirely when there's nothing to say |
| Test Plan | `get-ticket`'s description, parsed per `planning.settings.testPlanSource` | **Verbatim, never re-summarized** — if the ticket author wrote specific scenarios, paraphrasing them loses precision. Fallback: `- [ ] Verify the change locally and exercise the scenarios above` |
