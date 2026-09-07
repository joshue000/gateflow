# Two-gate model

## Gate 1 — local lock

A fix loop: dispatch the matched PE agents, collect in-scope findings, remediate every one, re-dispatch,
repeat. Gate 1 **locks** only after **2 consecutive clean rounds at the same commit SHA** — one clean
round is a good sign, not a lock. A new commit after a clean round resets the counter to zero; the SHA
the lock is pinned to must match HEAD when `gateflow-ship` checks it.

```
consecutive_clean = 0
loop:
  findings = dispatch_and_collect()
  if findings is empty:
    consecutive_clean += 1
    if consecutive_clean >= 2:
      GATE 1 LOCKED at current SHA
      break
  else:
    consecutive_clean = 0
    remediate(findings)   # every in-scope finding, not just HIGH/CRITICAL
    commit()
    # loop — a new commit always re-enters at round 1 of the count
```

## Gate 2 — independent peer, derived not chosen

Compare the VCS adapter's `current-user` against the PR's author (`get-pr`). If they match, this is
still Gate 1 territory (self-review) no matter who's looking at it. Gate 2 only exists once someone
*other than the author* reviews the PR — the skill never lets a human pick which gate applies.

## Override — mandatory pushback, always logged

Shipping with findings still open requires, in order: (1) restate every open finding plainly — severity,
location, why it matters, (2) an explicit confirmation, (3) a one-line reason. All three get written
verbatim into the review record before `gateflow-ship` will proceed. No severity is exempt, including
low-severity findings — the point is a paper trail, not gatekeeping by severity.

## What this buys you

A finding never silently disappears — it's either fixed, or it's fixed later behind a logged, reasoned
override with a name attached. `gateflow-ship`'s preflight refuses to proceed on an unlocked Gate 1
unless that log entry exists.
