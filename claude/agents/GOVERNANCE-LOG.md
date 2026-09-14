# Governance change log

Log of changes applied to the self-amendment-protected files:
`claude/agents/pe-governance.md`, `claude/skills/gateflow-review/SKILL.md`,
`claude/skills/_gateflow-shared/pe-agent-template.md`, `.claude/settings.json`, and
`.gateflow/config.json`.

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
Authorized by: Josue -- explicit, confirmed in chat ("remediar todo, BUGS.md debe poder rastrear o contener bugs de distintos proyectos")
Date: 2026-09-14 08:55
Files: *
Reason: Round 1 of the first real gateflow-review run surfaced 9 findings, remediated in full. Key
        governance-relevant changes: expanded self-amendment protection from 3 to 5 files (added
        .claude/settings.json and .gateflow/config.json, which enforce/route the protection but
        weren't themselves protected -- a "guard doesn't guard itself" gap); fixed pe-governance.md's
        persona line and its inaccurate team-rules/*.md ownership claim.
-->
```
