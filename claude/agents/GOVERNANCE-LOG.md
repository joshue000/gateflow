# Governance change log

Log of changes applied to the self-amendment-protected files:
`claude/agents/pe-governance.md`, `claude/skills/gateflow-review/SKILL.md`,
`claude/skills/_gateflow-shared/pe-agent-template.md`, `.claude/settings.json`,
`.gateflow/config.json`, and `.claude/hooks/protect-self-amendment.sh`.

Corrections to this log's own prior entries (never edits — see the rule below) also use
this format for consistency, even though this file isn't itself one of the 6 protected
files above.

**Entries are append-only — a past entry is never edited or deleted.** Git history
is the tamper-proof evidence; this file is the readable index, not the integrity
mechanism.

## Format

```
<!-- GOVERNANCE-CHANGE
Authorized by: [name] — explicit, [reference: chat message / commit / PR]
Date: YYYY-MM-DD HH:MM
Files: [explicit list of affected files, or * if it affects all 5]
Reason: ...
-->
```

## History

```
<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Acabo de revisarlo, me parece bien")
Date: 2026-09-12 22:39
Files: *
Reason: Initial creation of pe-governance and the self-amendment protection on the 3 files
        that govern the review process, so that no future change to the review rules is
        applied without explicit human oversight.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat (live gateflow-review Phase 1 dry-run, "Lo arreglo antes de seguir")
Date: 2026-09-13 (see commit c9c4b65)
Files: .gateflow/config.json
Reason: Backfilled for completeness. This commit added a peRoster.pathRules entry routing
        pe-agent-template.md to pe-governance. At the time, .gateflow/config.json was NOT YET one of
        the self-amendment-protected files (that expansion happened in the 2026-09-14 08:55 entry
        below) — so this was not a gate bypass, just a change made before this file's protection
        began. Logged here retroactively so the history is reconstructable.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue -- explicit, confirmed in chat ("remediar todo, BUGS.md debe poder rastrear o contener bugs de distintos proyectos")
Date: 2026-09-14 08:55
Files: *
Reason: Round 1 of the first real gateflow-review run surfaced 9 findings, remediated in full. Key
        governance-relevant changes: expanded self-amendment protection from 3 to 5 files (added
        .claude/settings.json and .gateflow/config.json, which enforce/route the protection but
        weren't themselves protected -- a "guard doesn't guard itself" gap); fixed pe-governance.md's
        persona line and its inaccurate team-rules/*.md ownership claim.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("remediar todo") in response to gateflow-review
               round 2 finding #1 (vague/commingled citation) and finding #5 (dash-style
               inconsistency) found in the entry above
Date: 2026-09-14 13:45
Files: claude/agents/GOVERNANCE-LOG.md
Reason: Correction to the 2026-09-14 08:55 entry above. Its original "Authorized by" line vaguely
        cited an unrelated BUGS.md scope decision instead of the governance changes it actually
        authorized, and used inconsistent dash style. Correct citation: authorized via "remediar
        todo" in direct response to the 9 gateflow-review round-1 findings presented, specifically
        finding #1 (self-amendment scope expansion to 5 files) and findings #8-9 (pe-governance.md
        persona/ownership fixes). Per this file's own append-only rule, the entry above is left
        unchanged rather than rewritten — this entry documents the correction instead of rewriting
        history. (Round 2's remediation mistakenly edited that entry in place; this restores the
        original and corrects properly via append, per gateflow-review round 3's finding.)
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("remediar y ronda 6") in response to
               gateflow-review round 5 finding #1
Date: 2026-09-14 14:08
Files: claude/agents/pe-governance.md
Reason: Removed a stray leftover "</content>" wrapper-tag artifact from the end of the file
        (a generation-process leftover, also present in pe-bash.md though that file isn't one
        of the 5 protected files so doesn't need its own entry here). The artifact was being
        fed verbatim into the dispatched agent's own prompt on every review — a real, if minor,
        functional bug, not just cosmetic.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Si, dale adelante") approving the GTF-21 plan
               (docs/gateflow/plans/GTF-21-plan.md), which explicitly detailed this exact
               .claude/settings.json change before approval was given
Date: 2026-09-14 18:46 -05
Files: .claude/settings.json
Reason: Implements GTF-21 — adds a PreToolUse hook (.claude/hooks/protect-self-amendment.sh) that
        blocks Edit/Write/Bash/MultiEdit/NotebookEdit calls against the 5 self-amendment-protected
        files regardless of permissions.defaultMode, fixing the CRITICAL finding that the prior
        permissions.ask-only protection was silently bypassed under defaultMode:auto. permissions.ask
        is kept unchanged as a defense-in-depth fallback.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Si, remedia todo") in response to gateflow-review
               GTF-21 round 1 finding #1
Date: 2026-09-14 19:20
Files: claude/agents/GOVERNANCE-LOG.md
Reason: Correction to the entry above (2026-09-14 18:46). Its citation of
        docs/gateflow/plans/GTF-21-plan.md as evidentiary support was flagged by gateflow-review as
        citing an untracked, never-committed file -- contradicting this log's own stated principle
        that "git history is the tamper-proof evidence." The entry above is left unchanged per the
        append-only rule; the correct, durable citation for that authorization is the chat quote
        alone ("Si, dale adelante" approving the GTF-21 plan as presented at the gateflow-implement
        Phase 3 approval gate), which remains valid and sufficient on its own -- consistent with
        every other entry in this file's History, none of which cite an uncommitted file.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("si, remediar") in response to gateflow-review
               GTF-21 round 2 finding #5
Date: 2026-09-14 19:40
Files: claude/agents/GOVERNANCE-LOG.md
Reason: Cosmetic correction. The 2026-09-14 19:20 entry above used plain double-hyphens instead of
        this file's consistent em-dash style in two places. Per the append-only rule, that entry is
        left unchanged; noting the drift here so it isn't repeated in future entries.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Si, arreglamos los dos") in response to
               gateflow-review GTF-21 round 4 finding #2
Date: 2026-09-15 08:00
Files: .claude/settings.json, claude/agents/pe-governance.md, claude/skills/gateflow-review/SKILL.md,
       claude/skills/_gateflow-shared/pe-agent-template.md
Reason: Expanded self-amendment protection from 5 to 6 files, adding
        .claude/hooks/protect-self-amendment.sh itself -- the hook script enforces the protection but
        was not itself protected, the same "guard doesn't guard itself" gap already fixed once before
        for .claude/settings.json/.gateflow/config.json (see the 2026-09-14 08:55 entry above).
-->
```
