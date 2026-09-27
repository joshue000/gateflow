# Deferred work

Things deliberately NOT built into MVP v1, with the reasoning for deferring — so revisiting one of
these later starts from "here's why we said not yet," not from scratch. Nothing here is forgotten by
being absent from the code; if it's not on this list, it wasn't considered, not just left out.

## Requirements fallback when `sdd-*` isn't installed

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

`AGENTS.md` is an open, cross-tool convention for repo-level agent governance (formalized August 2025,
OpenAI-led with Google/Cursor/Factory participation) — other AI coding tools read it the way Claude Code
reads `CLAUDE.md`. `claude-md-template.md` could ship both files (or one that satisfies both) so a
gateflow-bootstrapped project isn't Claude-Code-only.

**Why not now**: no current need — this repo and every project it's used on so far are Claude Code only.
Revisit if gateflow (or a project using it) is ever worked on with a different AI coding tool.

## Other backends (adapter contracts already support adding these — see architecture.md)

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

Not needed for a solo project — `reviewers` in config is a plain list, no algorithm needed. Revisit only
if a project actually gains collaborators and reviewer assignment needs real logic (whole-team / specific
engineers / cross-team supporters — a pattern seen in similar internal tooling elsewhere).

## Worktree isolation for concurrent reviews

Confirmed (while researching `sdlc`'s reference material) that this mechanism is fully host-agnostic —
sibling hidden git-worktree directory, reuse-detect via `git worktree list --porcelain`, fall back to
in-place on failure. Cheap to add later. Deferred because nothing today runs concurrent reviews on one
repo.

## Verification loop for generated PE agents

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

## gateflow-ship's SHA-match check can't survive its own review-file bookkeeping commit

`gateflow-ship`'s Phase 1 requires `latest.sha == current HEAD` in the review file's last round. But
recording that round (or logging a Gate 1 override) is itself a commit — the moment you commit the
round/override entry, HEAD moves past the SHA the entry names, permanently. There's no way to make a
commit's own content correctly cite its own future hash. Hit live on GTF-21: the override-logging commit
(`6c20bf3`) immediately invalidated its own round's `SHA: 579e473` field relative to true HEAD.

**Idea**: `gateflow-ship` Phase 1 should treat commits touching only `docs/gateflow/reviews/**` (the
review file itself) as not invalidating the SHA match — i.e., diff `HEAD` against `latest.sha` and check
whether every file in that diff is the review file itself, not a strict hash equality.

**Why not now**: out of GTF-21's scope, and `gateflow-ship/SKILL.md` is an ordinary review-gated file
(not self-amendment-protected, per `CLAUDE.md`'s own split), so this doesn't need governance-log
authorization the way the hook's changes did — just its own small ticket, not a drive-by fix here.

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

`sdlc:implement`'s planning-playbook scales its scout→plan pipeline by ticket size (more explorer/
architect agents for XL tickets). `gateflow-implement` currently does a single-pass scout+plan for
every ticket size. Deferred because the SDD flow already gives this shape at the requirements layer
(propose→spec→design→tasks) before a ticket ever reaches `gateflow-implement` — the need for gateflow's
own implementation-planning to also fan out by size hasn't shown up yet.
