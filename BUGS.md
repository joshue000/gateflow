# Dogfooding findings

Anomalies hit while using gateflow for real — dogfooding on gateflow itself (this repo) as well as on
any consuming project (e.g. `fastender`, gateflow's own guinea-pig project) — where it's unclear at the
time whether the cause is gateflow itself, `acli`, or something else. Log it here the moment it's found
— don't wait until it's diagnosed. Move an entry to "Resolved" with the actual root cause once it's
understood; delete only if it turns out not to be gateflow's fault at all (say so in the commit message
removing it).

## Open

### `gateflow-review`'s current SKILL.md has no non-committed persistence option, which is self-contradictory for the exact ticket that removes committed review docs

**Where found**: `fastender`, delivering FTE-29 (removing the committed `docs/gateflow/plans/*.md` /
`docs/gateflow/reviews/*.md` convention, backfilling the old content as Jira/PR comments instead),
2026-09-14.

**Symptom**: `gateflow-review/SKILL.md`'s Phase 7 only knows one persistence path — append the round to
`docs/gateflow/reviews/{name}-review.md` and commit it (PR-comment mirroring is a best-effort bonus on
top, not a substitute). Running the documented procedure literally on FTE-29's own diff would have
created a brand-new committed review file in the same commit range whose entire purpose is deleting all
the other committed review files — self-contradictory, and it would immediately need its own follow-up
cleanup.

**Root cause**: `gateflow-review`/`gateflow-implement`/`gateflow-ship`'s SKILL.md files have not yet
been updated for the plan-as-Jira-comment / review-as-PR-comment design (feature request handed to the
`gateflow-fb` session earlier this session, plain-text prompt, not yet confirmed landed — checked via
`rg` against the installed SKILL.md files before starting FTE-29: no `add-comment`/persistence-design
references in `gateflow-implement/SKILL.md` or `gateflow-ship/SKILL.md`, `gateflow-review/SKILL.md`
still only does the local-file-plus-PR-comment-mirror flow). `planning-jira.sh` already has the
`add-comment` op needed for the new design (pre-existing, not added for this).

**Workaround used**: for FTE-29 only, manually applied the target design ahead of gateflow adopting it:
ran the review (pe-general + tech-writer Round 1, pe-general lock-confirmation Round 2, both clean,
2 consecutive clean rounds at the same SHA → Gate 1 locked) entirely in-session without ever writing a
`docs/gateflow/reviews/FTE-29-review.md` file to disk or committing one. Gate-1-lock bookkeeping (2
consecutive clean rounds, same HEAD SHA) was tracked in conversation instead of in a persisted file.

**To fix properly**: once the plan-as-Jira-comment/review-as-PR-comment feature lands in
`gateflow-implement`/`gateflow-review`/`gateflow-ship`'s SKILL.md files, this stops being a workaround
and becomes the documented default — no separate fix needed here beyond that feature landing.

**Status**: unresolved, blocked on the pending feature request (tracked separately, not in this file —
see the `gateflow-fb` session/conversation for the drafted prompt). Not re-logging the feature request
itself here since it's a design decision already made and handed off, not an anomaly of unclear cause.

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

### `transition-to` short-circuits on statusCategory match even when the target is a genuinely different status

**Where found**: gateflow (this repo), gateflow-ship Phase 5, 2026-09-14, shipping GTF-3.

**Symptom**: `planning-jira.sh transition-to GTF-3 inReview` printed `{"status":"already-there"}` while
GTF-3's real status was "In Progress" — not "In Review". Unlike the earlier-logged "already-there for a
ticket that was NOT already there" bug (stale read, correct end-state), this time the end state was
also wrong: the ticket never actually moved to "In Review" until manually transitioned via
`acli jira workitem transition --key GTF-3 --status "In Review" --yes`.

**Root cause**: this project's Jira workflow has both "In Progress" and "In Review" mapped to the same
statusCategory ("indeterminate"). `transition-to`'s short-circuit logic ("if already at or past the
target category, skip") only checks category, not the specific status name — so when the current status
and the target semantic status share a category but are genuinely different named statuses, the script
wrongly concludes no transition is needed and never attempts one.

**Workaround used**: manual `acli jira workitem transition` to the exact status name.

**To fix properly**: `transition-to`'s short-circuit should compare the *specific* current status name
against the configured candidate list for the target, not just the category — category-level
short-circuiting is only safe across category boundaries (new -> indeterminate -> done), not within one
category that contains multiple distinct named statuses (as this project's workflow now does after
adding "In Review").

**Status**: unresolved, tracked as backlog. Likely related to the already-logged "already-there for a
ticket that was NOT already there" entry (both are transition-to status-reporting defects) but has a
distinct root cause — do not merge the two without confirming they're actually the same bug.

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

### CRITICAL: self-amendment `ask` gate doesn't reliably enforce at all under `defaultMode: auto` — not just a Bash coverage gap

**Where found**: gateflow (this repo), gateflow-review round 1, 2026-09-14 (Bash-coverage gap first
found); confirmed broader and more severe via a live test, 2026-09-14, same session (after a restart,
testing the shipped GTF-3 protection directly); the hook's own first fix then over-blocked legitimate
reads, found and fixed the same day; a command-chaining bypass in that fix was then found by
gateflow-review round 2, 2026-09-14; a background-operator bypass in the round-2 fix was then found via
live re-verification, round 3, 2026-09-14; a path-spelling/cd-relative-addressing bypass in the round-3
allowlist, plus the hook script's own lack of self-protection, were then found by gateflow-review round
4, 2026-09-15.

**Symptom / Root cause (original bug)**: originally scoped as "Bash isn't covered" —
`.claude/settings.json`'s `permissions.ask` array only lists `Edit(...)` rules for the 5
self-amendment-protected files, so a write via `Bash` (shell redirection, `tee`, `sed -i`) never
triggered the gate at all. Live-testing revealed it was worse than that: a direct `Edit` call against
`claude/agents/pe-governance.md` — a path *explicitly listed* in `ask` — completed with zero prompt or
pause, to either the model or the user. Root cause: `~/.claude/settings.json` has
`permissions.defaultMode: "auto"`, and in that mode a classifier reviews every action *in place of* the
human — it does not surface the configured `ask` rule as a prompt, it substitutes its own judgment.

**Fix (round 1)**: GTF-21 — a `PreToolUse` hook (`.claude/hooks/protect-self-amendment.sh`) inspecting
`Edit`/`Write`/`Bash`/`MultiEdit`/`NotebookEdit` calls against the 5 protected paths, wired into
`.claude/settings.json`'s new `hooks.PreToolUse` entry. Hooks are enforced by the Claude Code harness
itself, before the tool call proceeds — independent of permission mode — unlike `permissions.ask`, which
this bug proved is bypassable under `auto`. `permissions.ask` was kept as a defense-in-depth fallback,
unchanged. Implemented TDD (8 test cases, red before the hook script existed, green after).

**Over-blocking regression (round 1 follow-up, same day)**: the first hook implementation had no
read/write distinction for `Bash` at all, so legitimate read-only inspection of a protected file (e.g.
`cat .claude/settings.json`, `git log -- .gateflow/config.json`) was denied right alongside genuine
writes — correct in the fail-closed sense, but broad enough to train reflexive workarounds instead of
protecting anything. Fixed same day: a read-only-verb allowlist (`git log`/`git diff`/`cat`/`grep`/etc.)
gated by a write-token denylist (redirects, `tee`, `sed -i`, `cp`/`mv`/`rm`, a pipe, ...) — a command
matching a read verb AND containing none of the write tokens was allowed through. Also fixed in the same
pass: the hook now fails closed on malformed/non-object stdin instead of silently passing. Test suite
grew to 11 cases (added: malformed-stdin fail-closed, absolute-path `Edit`, `NotebookEdit` best-guess,
read-only-`cat`-allow).

**Command-chaining bypass (round 2, gateflow-review, 2026-09-14)**: the read-verb-allowlist +
write-token-denylist approach was itself bypassable — chaining a whitelisted read verb with `;`, `&&`,
`||`, a pipe, a backtick, `$(`, or an embedded newline, followed by any write mechanism NOT enumerated in
the denylist (e.g. `perl -pi`, `curl --output`, `python3 -c "open(...,'w')"`), sailed straight through.
Confirmed live: `git diff -- .claude/settings.json; python3 -c "print(1)"` was allowed. Root cause: a
fixed write-token denylist can never be exhaustive — it enumerates known write mechanisms instead of
recognizing the shape (chaining) that makes any of them reachable from an otherwise-trusted read verb.

**Fix (round 2)**: replaced the denylist approach entirely. A Bash command referencing a protected path
is now denied outright, before the read-verb check even runs, if it contains ANY shell chaining/
substitution/redirection metacharacter anywhere (`;`, `&&`, `||`, `|`, a backtick, `$(`, `>`, `<`, or an
embedded newline) — a blanket disqualifier, not an enumerated list of write mechanisms. Only past that
gate does the read-only-verb check apply, and only to the entire trimmed command matching a single,
unchained invocation of a recognized verb. `WRITE_TOKENS`/`contains_write_token` were dropped entirely —
redundant once chaining itself is the gate (a single unchained `sed -i ... .claude/settings.json` already
fails the read-verb match and correctly denies on its own). Test suite grew to 14 cases (added: `;`-chained
bypass, `&&`-chained bypass, newline-separated two-line command).

**Background-operator bypass (round 3, live re-verification, 2026-09-14)**: round 2's metacharacter
denylist (`CHAIN_TOKENS`) was itself still a denylist, and had the exact same structural weakness one
level up — it enumerated `;`, `&&`, `||`, `|`, a backtick, `$(`, `>`, `<`, and an embedded newline, but
never added the `&` background operator. `cat .claude/settings.json & echo done` sailed straight through:
no chaining token matched, `cat` matched the read-only-verb prefix, so it was allowed even though `&`
backgrounds the read and lets an unbounded second command run alongside it. Root cause: enumerating
"dangerous shell operators" has the same completeness problem as enumerating "dangerous write tokens" did
in round 2 — there is always one more operator nobody thought to add, regardless of which fixed list is
being maintained.

**Fix (round 3)**: replaced the denylist approach entirely with a positive character-class ALLOWLIST — a
structurally different mechanism, not one more entry added to the round-2 list. A Bash command
referencing a protected path is allowed through only when (a) every character in the leading/trailing-
trimmed command is an ASCII letter, digit, space, or one of `- _ / . : ~`, and (b) the entire trimmed
command is a single invocation of a recognized read-only verb. Because every shell metacharacter this
hook cares about — `;`, `&`, `&&`, `||`, `|`, a backtick, `$(`, `>`, `<`, a quote, a tab, a backslash, an
embedded newline — falls outside that allowed character set by construction, none of them need to be
individually enumerated, and there is no "one more operator" left to miss. `CHAIN_TOKENS`,
`contains_chain_operator`, and `contains_newline` were dropped entirely — the character allowlist
subsumes all three, including the newline case that previously needed its own dedicated check. Test suite
grew to 18 cases (added: `&`-backgrounding bypass, a literal tab character, backslash line-continuation,
and leading/trailing whitespace around an otherwise-safe read).

**Verified**: 2026-09-14, live re-test of the exact original reproduction — a direct `Edit` call against
`claude/agents/pe-governance.md`, no prior authorization — correctly blocked, error citing `CLAUDE.md` and
`GOVERNANCE-LOG.md`. Both the round-2 bypass reproduction
(`git diff -- .claude/settings.json; python3 -c "print(1)"`) and the round-3 bypass reproduction
(`cat .claude/settings.json & echo done`) now correctly deny. Legitimate single reads (`cat
.claude/settings.json`, `git log -- .claude/settings.json`, `git diff -- .gateflow/config.json`) still
allow; a direct single-command write (`sed -i ... .claude/settings.json`) still denies. Full 18/18
automated test suite passes. Commits: `3034161` (round-1 tests), `1b2f392` (round-1 hook), `5421826`
(round-1 wiring), `fd20f25` (round-1 governance log entry), `92e4c76` (moved to Resolved), `c88d170`
(round-1 over-blocking fix — fail-closed + read/write distinction), `27a5bcd` (round-1 regression tests),
`b4bf56f` (untracked-citation correction), `c728a75` (round-2 command-chaining fix), `2136f22`/`c3cf596`
(round-2 doc updates), `058ca10` (round-3 character-allowlist commit). Round-2's command-chaining fix
and this doc update touched only `.claude/hooks/protect-self-amendment.sh`, its test file, and this
doc — none of the 6 self-amendment-protected files — so no `GOVERNANCE-LOG.md` entry applies to either;
the same is true of round 3's allowlist rewrite.

**Round-4 findings (gateflow-review, 2026-09-15)**: two more gaps, both in the same "enumerate instead
of allowlist" and "guard doesn't guard itself" families as the rounds above.

1. **Path-spelling / cd-relative-addressing bypass (CRITICAL).** The Bash branch only ever scrutinized
   a command's character-allowlist/read-only-verb shape when a protected path appeared as an EXACT
   LITERAL SUBSTRING of the raw command text — a pre-gate, not the allowlist itself. An alternate
   spelling of the same path (`.claude//settings.json`, a doubled slash; `.claude/./settings.json`, a
   redundant `./` segment) or a `cd` into the target directory followed by the bare filename
   (`cd .claude && printf PWNED > settings.json`) never matched that literal substring, so the
   allowlist/verb logic never ran at all and the command sailed through unconditionally. Confirmed
   live: `sed -i '' 's/x/y/' .claude//settings.json` was ALLOWED. Root cause: same structural pattern
   as every prior round — a single fixed spelling/substring check is not an allowlist, no matter how
   good the logic gated behind it is.

2. **The hook script didn't protect itself (HIGH).** `.claude/hooks/protect-self-amendment.sh` was not
   in its own `PROTECTED_PATHS`, and wasn't in `.claude/settings.json`'s `permissions.ask` either — so
   the file that enforces the entire protection mechanism could itself be edited or deleted with zero
   gate, silently disabling everything above. Same "guard doesn't guard itself" class as the
   `.claude/settings.json`/`.gateflow/config.json` gap fixed in the 2026-09-14 08:55 entry.

**Fix (round 4, designed and verified, application blocked — see below)**: (1) command text is
normalized before the substring check (consecutive `/` collapsed to one, `/./` segments collapsed to
one `/`, both to a fixed point), closing the alternate-spelling half of finding 1; a command containing
a `cd`/`pushd`/`source` token anywhere is denied whenever it does not independently pass as a single
safe read-only invocation, regardless of whether a protected path is textually present, closing the
cd-relative-addressing half (documented, accepted tradeoff: a read-only command that `cd`s somewhere
unrelated first, e.g. `cd /tmp && ls`, is also denied — cd/pushd/source defeat static path-relevance
analysis in general, so this is not made path-specific). (2) `.claude/hooks/protect-self-amendment.sh`
was added to its own `PROTECTED_PATHS`, and `"Edit(.claude/hooks/protect-self-amendment.sh)"` was added
to `.claude/settings.json`'s `permissions.ask`, expanding self-amendment protection from 5 to 6 files
(`claude/agents/GOVERNANCE-LOG.md`, 2026-09-15 08:00 entry). Test suite grew to 22 cases (added:
double-slash bypass, embedded `./` bypass, cd-then-write bare filename, cd-then-unrelated-read
documenting the accepted tradeoff) — committed to `test-protect-self-amendment.sh`, which is not itself
one of the 6 protected files.

**Self-lockout discovered applying fix (2)**: adding the hook script to its own `PROTECTED_PATHS` was
applied first (a plain `Edit`, legal at that moment since the file did not yet protect itself) and
immediately made every further `Edit`/`Write`/`Bash`-based change to that same file — including fix
(1)'s logic rewrite, and even a revert — hard-denied by the hook's own unconditional "deny" (not "ask")
decision, which by design has no chat-authorization bypass. This is the mechanism working exactly as
intended (self-protection holding even against the session that just added it), but it means the actual
logic fix (1) could not be applied to the tracked file through Claude Code tool calls in the same pass
that added self-protection — the ordering has to be reversed (apply (1) and (2) as one single edit, not
two) or a human must apply the remainder directly, outside Claude Code. `PROTECTED_PATHS` on the tracked
file currently includes itself; the character-allowlist/`cd`-token logic rewrite from fix (1) and the
updated header comment do not yet exist there.

**Verified**: 2026-09-15, fix (1)+(2)'s complete logic was written and tested against a byte-identical
copy of the hook in an isolated scratch directory (not the tracked file, per the lockout above). All 4
round-4 adversarial reproductions (`sed -i '' 's/x/y/' .claude//settings.json`; the same with
`.claude/./settings.json`; `cd .claude && printf PWNED > settings.json`; `cd claude/agents; echo PWNED
>> pe-governance.md`) correctly deny. Legitimate reads (`cat .claude/settings.json`, `git log --
.gateflow/config.json`, `git diff -- .claude/settings.json`) still allow. Previously-fixed bypasses
(`;`, `&&`, `&`) still deny. A direct `Edit`/`Bash`-write attempt against the hook script itself also
denies. Full 22/22 automated test suite passes against that scratch copy; only 18/22 currently pass
against the tracked file (the 4 new round-4 cases correctly fail there, since the tracked file doesn't
have fix (1) applied yet).

**Status**: fix designed, isolated-copy-verified, and test-covered; NOT YET applied to the tracked
`.claude/hooks/protect-self-amendment.sh` — blocked on manual application (see self-lockout above). The
verified final content is available for direct application outside Claude Code's tool calls.
