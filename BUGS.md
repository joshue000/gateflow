# Dogfooding findings

Anomalies hit while using gateflow for real — dogfooding on gateflow itself (this repo) as well as on
any consuming project (e.g. `fastender`, gateflow's own guinea-pig project) — where it's unclear at the
time whether the cause is gateflow itself, `acli`, or something else. Log it here the moment it's found
— don't wait until it's diagnosed. Move an entry to "Resolved" with the actual root cause once it's
understood; delete only if it turns out not to be gateflow's fault at all (say so in the commit message
removing it).

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

### `ensure-account` hard-requires `.gateflow/config.json` before gateflow-init ever writes one

**Where found**: gateflow (this repo), `gateflow-init` Phase 2, 2026-09-13.

**Symptom**: Running `bash claude/skills/_gateflow-shared/adapters/planning-jira.sh ensure-account
<site>` per `gateflow-init/SKILL.md`'s Phase 2 pseudocode fails immediately with `planning-jira: no
.gateflow/config.json in the current project — see config-schema.md` (exit 1) — even though a site is
passed directly on the command line. `.gateflow/config.json` isn't written until Phase 8, six phases
later, so Phase 2 as documented can never succeed on a fresh project.

**Root cause**: two compounding bugs, not one.
1. `planning-jira.sh` line 13-14 gates every op — including `ensure-account` — on
   `.gateflow/config.json` existing, before the op switch runs.
2. `ensure_account()` never reads its own `$1`. `planning-adapter-contract.md` documents
   `ensure-account | <expectedSite>` — a site argument — but the implementation ignores it and instead
   reads `expected_site` unconditionally from the config file (`jq -r '.planning.settings.site'
   "$CONFIG"`, line 16). The CLI argument gateflow-init passes is silently discarded.

`gateflow-init/SKILL.md` Phase 2/Phase 8 and `config-schema.md` were all re-checked: no phase writes a
partial/minimal config before Phase 8, and no doc describes an intended bootstrap sequence. This is a
genuine ordering bug, not a documented-but-missed step.

**Workaround used**: manually wrote a minimal `.gateflow/config.json` containing just
`{"planning":{"settings":{"site":"<site>"}}}` before Phase 2, matching exactly the one field
`ensure_account()` actually reads. Phase 8 later overwrites the file wholesale with the full object, so
the partial content is safe to leave in place in the meantime.

**To fix properly**: either (a) `planning-jira.sh`'s `ensure-account` case should use `$1` when passed,
skipping the config-file read entirely for that op (matching `planning-adapter-contract.md`'s
documented `<expectedSite>` signature), or (b) `gateflow-init/SKILL.md` Phase 2 should write a minimal
`{vcs, planning}` config before calling `ensure-account`, with Phase 8 doing a full overwrite as
already documented. (a) is preferable — it fixes the contract mismatch at the source and lets
`ensure-account` be called standalone from outside any gateflow project, which the contract's argument
signature implies was the original intent.

**Status**: unresolved, blocks `gateflow-init` Phase 2 on every fresh project until fixed.

### `create-ticket`'s `--description-file` rejects an empty file

**Where found**: gateflow (this repo), `gateflow-init` Phase 6, 2026-09-13, creating the throwaway
status-verification ticket.

**Symptom**: `gateflow-init/SKILL.md` Phase 6's pseudocode calls
`create-ticket --type Task --summary "..." --description-file <empty tmpfile>` — but passing a truly
empty file fails with `✗ Error: The field value is not valid Atlassian Document Format (ADF) content.`
A file containing at least one line of plain text succeeds and converts to ADF fine.

**Root cause**: not fully diagnosed — likely `acli`'s plain-text-to-ADF conversion (or Jira's API
validation of the resulting ADF document) rejects an empty `doc` node. Not reproduced against other
`acli` commands/fields, only `create-ticket`'s `--description-file` path.

**Workaround used**: wrote one line of placeholder text ("Throwaway ticket for gateflow-init status
verification. Safe to delete.") instead of an empty file — succeeded immediately.

**To fix properly**: update `gateflow-init/SKILL.md` Phase 6's pseudocode to specify writing a
one-line placeholder description instead of literally "empty tmpfile" — cheap, low-risk fix, no
adapter script change needed.

**Status**: workaround applied and in use; SKILL.md's Phase 6 pseudocode still needs the
one-line-placeholder doc fix before this can move to Resolved.

### Self-amendment `ask` gate doesn't cover Bash-based writes, only the Edit tool

**Where found**: gateflow (this repo), gateflow-review round 1, 2026-09-14.

**Symptom / Root cause**: `.claude/settings.json`'s `permissions.ask` array only lists `Edit(...)` rules
for the 5 self-amendment-protected files. Any write performed via `Bash` (shell redirection, `tee`,
`sed -i`, or any other command that overwrites one of those files) never triggers the `Edit`-scoped
`ask` gate at all — the protection only inspects the `Edit` tool's target path, not what a `Bash` call
writes to. A PE reviewer or any Bash-capable actor could overwrite a protected file without ever hitting
the gate.

**To fix properly**: a `PreToolUse` hook inspecting `Edit`/`Write`/`Bash`/`MultiEdit`/`NotebookEdit`
calls against the 5 protected paths, not an `ask` permission array scoped to `Edit` alone.

**Status**: unresolved, tracked as backlog.

### gateflow-ship's SHA-match check is unsatisfiable when the review file itself gets committed

**Where found**: gateflow (this repo), gateflow-ship Phase 1 preflight, 2026-09-14, shipping GTF-3.

**Symptom**: `gateflow-review`'s Phase 7 persists the review verdict by committing
`docs/gateflow/reviews/{key}-review.md` to the repo. That commit itself becomes the new HEAD. When
`gateflow-ship`'s Phase 1 then checks `if latest.sha != current HEAD: stop`, it always fails — the
persisted round's recorded SHA is necessarily the commit *before* the persist commit, which can never
equal HEAD *after* persisting, since the review file cannot know its own future commit hash at the
moment its content is written.

**Root cause**: a structural chicken-and-egg gap in the current design: persisting the review verdict
as a committed file inherently shifts HEAD past the SHA that verdict certifies, with no way for the
review file to correctly self-reference the commit it will become part of.

**Workaround used**: explicit human override — the only commit between the locked SHA and current HEAD
was the review-file-persist commit itself (zero code changes, pure documentation), so shipping was
manually authorized to proceed despite the SHA mismatch. Documented as an override in
`docs/gateflow/reviews/GTF-3-review.md` rather than silently bypassing the check.

**To fix properly**: this is a direct consequence of committing plan/review docs to the repo at all —
already tracked as ticket GTF-20 ("Stop committing gateflow-implement/gateflow-review's plan and review
docs to the consuming repo — persist as Jira/GitHub comments instead"). Once GTF-20 lands, this bug
disappears structurally (nothing gets committed, so there's no SHA to chase). Until then, a narrower
interim fix: gateflow-ship's Phase 1 SHA check could special-case "HEAD's only new commit since the
locked SHA touches solely the review file itself" as an automatic pass, rather than requiring manual
override every time.

**Status**: unresolved, expected to be structurally fixed by GTF-20; the narrower interim fix is not
implemented.

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
