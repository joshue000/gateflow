# Deferred work

Things deliberately NOT built into MVP v1, with the reasoning for deferring — so revisiting one of
these later starts from "here's why we said not yet," not from scratch. Nothing here is forgotten by
being absent from the code; if it's not on this list, it wasn't considered, not just left out.

An entry moves under `## Done` at the end of this file once its ticket is actually resolved (or the
idea is otherwise confirmed obsolete) — see CLAUDE.md's Deferred-work rule for the `**Tracked as:**
GTF-N` convention that precedes the move, and the `**Built via:** GTF-N (commit <hash>)` line that
replaces it once an entry lands here — or, if the idea is confirmed obsolete instead (whether or not
it ever landed a ticket), a `**Obsolete:** <reason, date>` note (citing the ticket key in the reason
if one existed). Never deleted, only moved. `## Done` is a section divider, not an entry itself, even
though entries beneath it share its heading level.

## Requirements fallback when `sdd-*` isn't installed

**Tracked as:** GTF-11

`gateflow-plan create-from-sdd` depends on a file shape (`requirements-artifact-contract.md`), not on
the `sdd-*` skill family specifically — but without `sdd-*`, producing a good `proposal.md`/`tasks.md`
means doing that structuring work by hand, which is real friction, not just filling a template.

**Idea**: a lean fallback mode inside `gateflow-plan` — if `sdd-*` isn't detected, ask a handful of
structured questions itself and write a *minimal* `proposal.md`/`tasks.md` matching the contract. Not a
reimplementation of SDD's full 4-phase rigor (explore→propose→spec→design→tasks) — just enough to not
leave someone with a blank page.

**Why not now**: this only matters for a hypothetical *other* user running gateflow without `sdd-*` —
the actual user of this repo always has it installed. Building it now solves a problem nobody currently
has, at the cost of real complexity today. Revisit if/when gateflow is ever used by someone else.

## AGENTS.md compatibility

**Tracked as:** GTF-12

`AGENTS.md` is an open, cross-tool convention for repo-level agent governance (formalized August 2025,
OpenAI-led with Google/Cursor/Factory participation) — other AI coding tools read it the way Claude Code
reads `CLAUDE.md`. `claude-md-template.md` could ship both files (or one that satisfies both) so a
gateflow-bootstrapped project isn't Claude-Code-only.

**Why not now**: no current need — this repo and every project it's used on so far are Claude Code only.
Revisit if gateflow (or a project using it) is ever worked on with a different AI coding tool.

## Other backends (adapter contracts already support adding these — see architecture.md)

**Tracked as:** GTF-13

- **Notion / Obsidian** planning adapters (alternative to Jira)
- **Bitbucket / GitLab** VCS adapter (alternative to GitHub)
- **Confluence publishing** — `acli confluence page` is read-only (`view` only, confirmed live, no
  `create`/`update`). Would need a raw REST API adapter (`POST /wiki/api/v2/pages`) with its own token,
  not `acli`. Deferred: `openspec`/README docs already give real, git-tracked "documentos técnicos";
  Confluence upload stays a manual copy-paste for now.

**Why not now**: MVP intentionally ships one concrete backend per adapter contract (GitHub, Jira) to
prove the seam works before widening it. Adding a second backend on either side is additive — a new
`adapters/<kind>-<name>.sh` file, zero changes to any `SKILL.md` — so there's no cost to waiting.

## Team-routing / multi-reviewer roster resolution

**Tracked as:** GTF-14

Not needed for a solo project — `reviewers` in config is a plain list, no algorithm needed. Revisit only
if a project actually gains collaborators and reviewer assignment needs real logic (whole-team / specific
engineers / cross-team supporters — a pattern seen in similar internal tooling elsewhere).

## Worktree isolation for concurrent reviews

**Tracked as:** GTF-15

Confirmed (while researching `sdlc`'s reference material) that this mechanism is fully host-agnostic —
sibling hidden git-worktree directory, reuse-detect via `git worktree list --porcelain`, fall back to
in-place on failure. Cheap to add later. Deferred because nothing today runs concurrent reviews on one
repo.

## Verification loop for generated PE agents

**Tracked as:** GTF-16

`gateflow-init`/`add-pe` generates a new PE from `pe-agent-template.md` grounded in real project files
when available — but unlike the Jira status check (verified against a live throwaway ticket), a
generated PE's quality has no live check at all. It's only as good as the knowledge available at
generation time.

**Why not now**: no evidence yet that generated PEs are actually weak in practice — building a
verification loop (e.g., dry-run the new PE against a real past diff and sanity-check its findings)
for a problem that hasn't shown up is the same premature-investment mistake avoided elsewhere in this
file.

**Concrete trigger to revisit** (not just "if it feels weak"): the two-gate model already records every
override with its reason in `docs/gateflow/reviews/*.md`. If overrides start concentrating on one
generated PE's findings specifically — a real, free-to-observe pattern in data already being captured,
no new instrumentation needed — that's the signal its judgment isn't well-calibrated for that stack.

## Enforce the round-closing hash-backfill check in gateflow-review

GTF-21's dogfooding run surfaced a recurring pattern (4 occurrences across one ticket): a
`GOVERNANCE-CHANGE` entry authorizes a protected-file change with `Date: ... (commit hash to follow
once applied)`, the fix lands, and the placeholder never gets backfilled until a *later* review round
catches it — each time independently re-discovered, never prevented. The 3rd occurrence's own log entry
(`claude/agents/GOVERNANCE-LOG.md`, `6970705` backfill) explicitly recommended a fix and it still
recurred a 4th time.

**Idea**: `gateflow-review/SKILL.md`'s Phase 7 (Persist), before marking a round's verdict `clean`/gate
`LOCKED`, greps the relevant `GOVERNANCE-LOG.md` entry (if the round touched a self-amendment-protected
file) for the literal string `commit hash to follow` and refuses to close the round — or at minimum
warns loudly — until it's replaced with a real hash.

**Why not now**: out of GTF-21's scope (that ticket was about the ask-gate not enforcing under
`permissions.defaultMode:auto`, not about `gateflow-review`'s own persistence checklist), and
`gateflow-review/SKILL.md` is itself one of the 6 self-amendment-protected files — changing it needs
its own dedicated authorization, not a drive-by fix bundled into an already-long ticket. Revisit as its
own small ticket; the fix itself is a few lines in Phase 7.

## Size-tiered multi-explorer/multi-architect planning fan-out

**Tracked as:** GTF-17

`sdlc:implement`'s planning-playbook scales its scout→plan pipeline by ticket size (more explorer/
architect agents for XL tickets). `gateflow-implement` currently does a single-pass scout+plan for
every ticket size. Deferred because the SDD flow already gives this shape at the requirements layer
(propose→spec→design→tasks) before a ticket ever reaches `gateflow-implement` — the need for gateflow's
own implementation-planning to also fan out by size hasn't shown up yet.

## Unguarded `$2` consumption in planning-jira.sh's add-comment and create-ticket

GTF-20 Gate 1 Round 4 finding 2 fixed `update-comment`'s `--id`/`--body-file` flag parsing so it guards
against a missing value (`[ $# -ge 2 ] || die ...`) instead of crashing on bash's raw "unbound variable"
error under `set -euo pipefail`. The identical unguarded pattern — consuming `$2` right after matching a
flag, with no value-presence check first — also exists in `add-comment`'s `--body-file` parsing
(`claude/skills/_gateflow-shared/adapters/planning-jira.sh` ~line 82) and in `create-ticket`'s
flag-parsing loop (~lines 123-126) of the same file.

**Why not now**: out of scope for that finding, which was restricted to `update-comment` specifically.
Revisit as its own small fix — apply the same guard pattern to `add-comment` and `create-ticket`.

## Interactive tier banner-confirmation gate in gateflow-review

`sdlc`'s reference implementation (`review/SKILL.md` lines 509-538) renders an `AskUserQuestion`
banner on every review invocation — "(yes) Proceed at tier {session.tier}" listed first, plus explicit
TRIVIAL/STANDARD/DEEP overrides and a "(no)" to stop — after its own pre-dispatch judgment pass can
already raise the tier above the mechanical floor. `gateflow-review`'s tier system
(`_gateflow-shared/tier-classifier.md`) is fully deterministic and silent instead: a mechanical
size/path floor plus a content-judgment escalate-only pass that logs a one-line rationale but never
prompts. Confirmed by direct read of both files, not assumed.

**Idea**: add a banner-confirmation gate to `gateflow-review/SKILL.md`, right after tier
classification, mirroring `sdlc`'s pattern — surface the computed tier and its source (mechanical
floor vs. judgment-escalated) via `AskUserQuestion`, with "(yes) Proceed at tier {tier}" listed first
and explicit TRIVIAL/STANDARD/DEEP overrides available.

**Why not now**: `gateflow-review/SKILL.md` is one of the 6 self-amendment-protected governance files
(see CLAUDE.md's Security posture section) — a change needs the repo owner's explicit, standalone
sign-off on that specific change, never inferred from a general "yes, add the banner" in conversation.
Logged here first per the Deferred-work rule so the direction isn't lost before that sign-off is given.

## Done

## gateflow-ship's SHA-match check can't survive its own review-file bookkeeping commit — obsoleted by GTF-20

**Built via:** GTF-20 (commit 4676cc2)

Originally logged because recording a review round (or a Gate 1 override) was itself a commit to
`docs/gateflow/reviews/{key}-review.md`, so HEAD always moved past the SHA that round named — hit live
on GTF-21, where the override-logging commit (`6c20bf3`) immediately invalidated its own round's
`SHA: 579e473` field relative to true HEAD.

**Why this no longer applies**: GTF-20 (this repo) removed the premise — `gateflow-ship`'s Phase 4 no
longer commits the review file at all; it posts the round content as a PR comment and leaves the file
on disk, gitignored (`2668509`, `44cc539`, `4676cc2`). With no review-file commit ever landing, there's
no SHA left for HEAD to move past, so the scenario this idea was meant to work around can't occur.
No fix needed.
