# Review tier classification

Two layers. The first is deterministic and sets a **floor** — the second can only raise the tier above
that floor, never lower it below. All five review passes (Architecture, Quality+Tests, Security,
Adversarial Re-read, Self-Adversarial) run at every tier — the tier scopes *which files* enter review
and the test/build budget, never how many passes run.

## Layer 1 — deterministic (size + path)

Computed from `tierClassifier` config thresholds against `git diff --stat <base>...HEAD`, after removing
`ignorePathPatterns` (lockfiles, `dist/**`, snapshots — noise, not signal):

```
files_changed, lines_changed = diff stats over the filtered set

if files_changed >= standardMaxFiles or lines_changed >= standardMaxLines:
  tier = DEEP
elif any changed file matches deepPathPatterns:
  tier = STANDARD          # a safety floor — auth/secrets/money-shaped paths are never auto-TRIVIAL
elif files_changed <= trivialMaxFiles and lines_changed <= trivialMaxLines:
  tier = TRIVIAL
else:
  tier = STANDARD
```

## Layer 2 — content judgment (escalate only)

Reads the actual diff content (not just paths) for secret-shaped strings, IAM/policy blocks, or
money-handling logic — signal that lives in the *values*, not the file name. If found, raise the tier
one step (never lower it) and log a one-line rationale: `"escalated TRIVIAL -> STANDARD: diff touches
a JWT secret constant in config/auth.ts"`. An unescalated diff keeps Layer 1's tier unchanged.

## Depth contracts

| Tier | Scope | Test/build budget |
|---|---|---|
| TRIVIAL | Changed lines + their direct callers/consumers only | Narrowest test command touching those files |
| STANDARD | Changed files in full, plus what they import and what imports them | That project's/package's full build+test+lint |
| DEEP | Unlimited exploration — chase any thread the diff raises | Full repo build+test+lint |

## Escalation valve mid-review

If a dispatched agent finds the diff needs more depth than its assigned tier allows, it stops and
reports `tier_escalation: {requested, why}` instead of silently expanding scope. The orchestrating skill
re-dispatches at the higher tier. Never silently over- or under-review.
