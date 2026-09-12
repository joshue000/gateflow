# Dogfooding findings

Anomalies hit while using gateflow for real on `fastender` (gateflow's own guinea-pig project) where
it's unclear at the time whether the cause is gateflow itself, `acli`, or something else. Log it here
the moment it's found — don't wait until it's diagnosed. Move an entry to "Resolved" with the actual
root cause once it's understood; delete only if it turns out not to be gateflow's fault at all (say so
in the commit message removing it).

## Open

### Batch-created Jira tickets can have summary/description desynced by one item

**Where found**: `fastender`, `gateflow-plan create-from-sdd inventario-mvp`, 2026-09-07.

**Symptom**: Created 7 Story tickets via `_gateflow-shared/adapters/planning-jira.sh create-ticket`,
one call per iteration of a bash `for` loop (`out=$(bash planning-jira.sh create-ticket --summary
"$name" --description-file "phase${i}.md" ... 2>&1)`). The loop's own echoed output looked plausible
(6 successes + 1 argument-parsing failure), but direct per-ticket verification afterward
(`acli jira workitem view <KEY> --fields summary,description`) showed every created ticket's
**summary belonged to phase N while its description body belonged to phase N+1** — and the phase
whose creation the loop reported as failing (the last one) was actually the one phase with no ticket
at all. Local source files (`phase1.md`..`phase7.md`) were independently confirmed correctly
numbered/labeled, ruling out a content-authoring mistake — the desync happened during or around the
`create-ticket` calls themselves.

**Suspected cause**: not isolated. Candidates: something about invoking `planning-jira.sh` (which
itself shells out to `acli`) repeatedly inside a `$(...)` command-substitution loop; an `acli`-side
race/caching effect across rapid sequential invocations; a stdout/stderr interleaving quirk under
`set -euo pipefail`. Not reproduced deliberately — only observed once, then worked around.

**Workaround used**: deleted the 6 mismatched tickets, recreated all 7 as separate sequential Bash
tool calls (no shared loop), verifying summary+description immediately after each before creating the
next. Fully consistent on the second pass.

**To fix properly**: reproduce deliberately (script a minimal repro: 3-4 sequential `create-ticket`
calls in a loop against a scratch Jira project, diff each result against intent) before deciding
whether the fix belongs in `planning-jira.sh` (e.g. don't batch via loop — accept a list and issue
requests with a delay/serial-lock) or in `gateflow-plan`'s own instructions (explicitly forbid looping
raw shell calls to the adapter; mandate one Bash tool invocation + one verification read per ticket,
which is what the workaround above does by hand).

**Status**: unresolved, workaround documented in `sdd-*`-adjacent session memory for `fastender`
(engram, topic `gateflow-init/fastender`) and in `token-optimizer` project wiki (anchored to
`planning-jira.sh`).

### `transition-to` reported "already-there" for a ticket that was NOT already there

**Where found**: `fastender`, `gateflow-implement FTE-16`, Phase 2 (branch + transition), 2026-09-07.

**Symptom**: `planning-jira.sh transition-to FTE-16 activeWork` printed `{"status":"already-there"}` —
which per the script's own logic means it read the ticket's `statusCategory.key` as already
`"indeterminate"` (or `"done"`) *before* attempting anything. But a direct `acli jira workitem view`
on the same ticket moments earlier (Phase 1 of the same skill run, `get-ticket`) had returned
`"status": "To Do"` / `"statusCategory": "new"`. No other Jira call touched FTE-16 in between — only
local `git checkout`/`git pull`/`git checkout -b` ran. A follow-up direct `acli jira workitem view`
right after confirmed the ticket genuinely was "In Progress" — so the end state was correct, only the
script's implied "no action was needed" claim was wrong (or Jira's status read was stale/inconsistent
at the moment `transition-to` queried it).

**Suspected cause**: not isolated — same general shape as the create-ticket desync above (an
acli-backed read returning something inconsistent with an adjacent direct read). Could be Jira-side
read-after-write consistency lag, could be something in how `transition-to` shells out.

**Impact**: low so far — the actual transition happened correctly either way, this was only caught
because the ticket's status was independently verified before and after. A workflow that trusts
`transition-to`'s reported status without an independent check could silently believe no transition
happened when one did (or vice versa).

**Status**: unresolved, low priority unless it starts affecting `transition-to`'s actual candidate-list
fallback logic (not just its status message).

## Resolved

### `transition-to` crashed with "mapfile: command not found" on macOS's default bash

**Where found**: `fastender`, `gateflow-implement FTE-23`, Phase 2 (branch + transition), 2026-09-11.

**Symptom**: `planning-jira.sh transition-to FTE-23 activeWork` failed with `mapfile: command not
found` (exit 127) the first time it actually needed the candidate-list loop — every prior call in
this project happened to short-circuit via the `already-there` early return, so the buggy line was
never exercised until a ticket started in a genuinely different status category.

**Root cause**: `mapfile` is a bash 4+ builtin. macOS ships `/bin/bash` frozen at 3.2.57 (Apple
can't ship GPLv3), and nothing in the repo or CLAUDE.md pins/requires a newer bash — `bash
script.sh` on a stock Mac resolves to 3.2 with no warning.

**Fix**: replaced the `mapfile -t candidates < <(...)` line in
`claude/skills/_gateflow-shared/adapters/planning-jira.sh` with a portable `while IFS= read -r
line; do candidates+=("$line"); done < <(...)` loop — process substitution and array append both
work fine in bash 3.2, only `mapfile` itself doesn't.

**Verified**: created a throwaway ticket (FTE-24) in "To Do", ran the fixed `transition-to ...
activeWork` against it — correctly transitioned to "In Progress" this time instead of crashing.
Deleted the throwaway ticket after.

**Status**: resolved. Grepped both adapter scripts for other bash-4-only constructs (`mapfile`,
`readarray`, `declare -A`, `${var,,}`/`${var^^}` case conversion) — none found elsewhere. This one
hid for a while simply because its buggy line wasn't on the common path (the `already-there`
early-return almost always fired first).
