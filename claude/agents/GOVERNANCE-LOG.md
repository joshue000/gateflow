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
Files: [explicit list of affected files, or * if it affects all 6]
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

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Si adelante con eso") in response to
               gateflow-review GTF-21 round 5 findings
Date: 2026-09-15 09:38
Files: .claude/hooks/protect-self-amendment.sh
Reason: The 2026-09-15 08:00 entry's Files: list omitted this file, even though it received the
        actual protection-logic rewrite (154 lines, commit deda7ef) that entry's Reason text
        describes. Recorded here per the append-only rule rather than editing that entry. This
        commit's follow-up (round-5 remediation) also closes 3 further Bash bypasses (dot-source,
        backslash-escape, quote-splitting) in the same file -- see BUGS.md for detail.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Si adelante con eso") approving the round-5 fix
               plan described in this session's gateflow-review round-5 remediation
Date: 2026-09-15 16:30 (see commit 401d2f7)
Files: .claude/hooks/protect-self-amendment.sh
Reason: Correction/backfill. The entry above (2026-09-15 09:38) forward-referenced "this commit's
        follow-up" without ever citing the commit that actually applied it — that commit is 401d2f7
        ("fix: GTF-21 close dot-sourcing/backslash/quote-splitting Bash bypasses"), authored at
        16:30:15, over 3 hours after the entry above was committed. Recorded here per the append-only
        rule (the entry above is left unchanged) with the actual commit hash, closing the gap
        gateflow-review round 6 flagged: BUGS.md's own narrative said round 5 was "not yet applied" at
        a point in time when it already had been.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat, style-drift note only (no content authorization
               needed — this is a correction of this log's own formatting, not a change to a
               protected file)
Date: 2026-09-15 16:35
Files: claude/agents/GOVERNANCE-LOG.md
Reason: The 2026-09-14 19:40 entry flagged that the 19:20 entry used plain double-hyphens ("--")
        instead of this file's em-dash ("—") convention, and asked that the drift not repeat. The
        2026-09-15 08:00 and 09:38 entries both repeated it anyway. Noting the recurrence per the same
        pattern — not editing those entries, which stay as written.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, standalone answer to a direct question ("Auditoria estructural ahora
               (recomendado)") on how to close gateflow-review round 6's 3 CRITICAL findings, plus
               ("Una ronda adversarial por cambio" + "Checklist de verbos verificados") on where the
               resulting stopping policy should live and what it says
Date: 2026-09-15 (round 6 remediation, commit hash to follow once applied)
Files: .claude/hooks/protect-self-amendment.sh, claude/agents/pe-governance.md
Reason: Closes gateflow-review GTF-21 round 6's 3 CRITICAL findings (git -c config-injection RCE; git
        diff/log/show --output arbitrary-file-write; git -C combined bypass) by removing git's
        log/diff/show/blame/status verbs from protect-self-amendment.sh's unconditional character-
        allowlist fast path and giving git its own stricter positive grammar
        (is_safe_git_readonly_command / contains_unsafe_git_invocation), plus removing bat/less/more
        from that same fast path as a precaution (PAGER/LESSOPEN-driven subprocess surface, no
        confirmed PoC). Also writes a REVIEW SCOPE / STOPPING POLICY section into the hook's own header
        comment (one dedicated adversarial round per hook change, plus a verified-safe-verb checklist
        for any future addition to READ_ONLY_VERBS), per the repo owner's explicit decision on how to
        stop re-litigating this hook's review scope every round. Separately corrects
        claude/agents/pe-governance.md's citation of "the 2026-09-15 08:00 entry" (which never mentions
        the hook script in its own Files: list) to also cite its 09:38 correction — a doc-accuracy fix
        raised by the same round-6 review, not a change to review-scope logic.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("Auditoria estructural ahora (recomendado)") for
               the plan this commit implements
Date: 2026-09-15 (see commit 38fb720)
Files: .claude/hooks/protect-self-amendment.sh, claude/agents/pe-governance.md
Reason: Correction/backfill. The entry above authorized round 6's change before it landed and promised
        "commit hash to follow once applied" — that commit is 38fb720 ("fix: GTF-21 close
        git-invocation RCE bypasses, add stopping policy"). Recorded here per the append-only rule (the
        entry above is left unchanged) with the actual commit hash, same pattern as the earlier 401d2f7
        backfill for round 5.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("si, dale, resolvamos") in response to
               gateflow-review GTF-21 round 2 (of the review file; 7th real review pass this session)
               finding #1 (case-insensitivity bypass, CRITICAL) and findings #2-6
Date: 2026-09-15 (round 6 re-review remediation, commit hash to follow once applied)
Files: .claude/hooks/protect-self-amendment.sh
Reason: Closes gateflow-review round 2's CRITICAL finding: every protected-path/git-invocation
        comparison in protect-self-amendment.sh (is_protected_path, contains_unsafe_git_invocation, the
        PROTECTED_PATHS substring loop) was case-sensitive, but this machine's default filesystem
        (macOS APFS) is case-insensitive-but-preserving, reopening round 6's RCE fix via one
        capitalized letter and also breaking the Edit/Write/MultiEdit path's claimed
        non-heuristic guarantee. Fixed by lowercasing both sides of every comparison before matching,
        without loosening is_safe_git_readonly_command's ALLOW grammar. Also documents the
        quote/backslash path-independent over-blocking case in the header (finding #5) and defines
        "round" in the STOPPING POLICY section (finding #6) — both doc-accuracy fixes from the same
        review round. Additionally narrows contains_unsafe_git_invocation itself, applied and
        authorized in the same pass ("haz el cambio"): the first version denied ANY git subcommand
        outside a 5-verb read-only grammar, which blocked ordinary git add/commit on unprotected files
        -- not a governance-scope change (still the same 6 protected files, same authority model), a
        correctness fix to an unintended over-block discovered live in this session. See BUGS.md's
        round-6 re-review entry for detail.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("si, dale, resolvamos") for the plan this commit
               implements
Date: 2026-09-15 (see commit 6970705)
Files: .claude/hooks/protect-self-amendment.sh
Reason: Correction/backfill. The entry above authorized this change before it landed and promised
        "commit hash to follow once applied" — that commit is 6970705 ("fix: GTF-21 case-insensitive
        matching, narrow git-invocation scope"). Recorded here per the append-only rule (the entry above
        is left unchanged) with the actual commit hash — same pattern as the deda7ef and 38fb720
        backfills above. Process note: this is the 3rd time this exact placeholder has been left
        unfilled at commit time; gateflow-review's round-closing step should check for "commit hash to
        follow" text referencing the round just closed before considering a round done.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("si, dale") in response to gateflow-review GTF-21
               round 3 (of the review file) findings — the first dedicated adversarial pass on the
               narrowed contains_unsafe_git_invocation from commit 6970705
Date: 2026-09-15 (round 3 re-review remediation, commit hash to follow once applied)
Files: .claude/hooks/protect-self-amendment.sh
Reason: Closes gateflow-review round 3's 5 findings (3 CRITICAL, 1 HIGH, 1 MEDIUM), the first in this
        entire history not exclusively about git or a fixed-spelling path: glob/wildcard expansion
        (*, ?, [) never expanded by static text but expanded by the real shell at execution time;
        git --config-env= (same power as -c, reads from an env var instead); GIT_DIR=/GIT_WORK_TREE=/
        GIT_CONFIG_* env-var prefixes achieving the same redirection with zero flag tokens; env -C
        (and other external tools' own cwd-redirect flags) invisible to the cd-token check; bare
        parameter concatenation ($part1$part2) respelling a protected path with no quote/backslash.
        Fixed by extending contains_disallowed_escape_char (glob chars, bare $), extending
        contains_unsafe_git_invocation (--config-env=, GIT_* prefixes), and generalizing
        contains_cd_token to catch a standalone -C/--chdir=/--directory= token on any command. Per the
        explicit repo-owner decision recorded in BUGS.md's round-3 re-review closing paragraph, this is
        the final dedicated round of Bash-bypass hunting for this ticket — any further bypass class
        found later is a new BUGS.md entry / new ticket, not a reopening of this one.
-->

<!-- GOVERNANCE-CHANGE
Authorized by: Josue — explicit, confirmed in chat ("si, dale") for the plan this commit implements
Date: 2026-09-15 (see commit 17586b0)
Files: .claude/hooks/protect-self-amendment.sh
Reason: Correction/backfill. The entry above authorized this change before it landed and promised
        "commit hash to follow once applied" — that commit is 17586b0 ("fix: GTF-21 close
        glob/env-var/param-concat bypasses, close hunting"). Recorded here per the append-only rule
        (the entry above is left unchanged) with the actual commit hash — same pattern as the deda7ef,
        38fb720, and 6970705 backfills above. This is the 4th time this exact placeholder has been left
        unfilled at commit time despite the process note in the 6970705 backfill entry above explicitly
        flagging the 3rd occurrence — the gateflow-review Phase 7 enforcement change that note
        recommended was never implemented. Per gateflow-review round 4's finding, deferred to TODO.md
        as a process improvement rather than fixed inline here (this file is not the place to change
        gateflow-review/SKILL.md's own logic, and that change is out of GTF-21's scope).
-->
```
