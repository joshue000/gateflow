# GTF-21 review

Note: the prior `docs/gateflow/reviews/GTF-21-review.md` (rounds 1–5, run earlier in this same session)
was lost — almost certainly to an unrelated cross-session `git reset --hard` collision documented in
this session's engram history, not in this file. This file restarts cleanly at Round 1; Gate 1 requires
2 consecutive clean rounds from here.

## Round 1

**SHA:** 401d2f7
**Verdict:** changes requested
**Gate Status:** OPEN

| # | Severity | File:Line | Finding | Agent |
|---|---|---|---|---|
| 1 | CRITICAL | `.claude/hooks/protect-self-amendment.sh:215-232,349-352` | `git -c diff.external=<script> diff ...` matches no `READ_ONLY_VERBS` global-flag exception and none of the fallback checks — falls through to implicit allow. Git executes the configured external diff driver as a subprocess with full shell privileges; once running outside the hook's visibility, it can write any of the 6 protected files. PoC verified in isolated scratch repo. | pe-bash |
| 2 | CRITICAL | `.claude/hooks/protect-self-amendment.sh:349-352` | `git diff/log/show --output <path> ...` (space-separated form) is composed entirely of allowlisted characters and matches a `READ_ONLY_VERBS` prefix, so it hits the fast unconditional-allow path — but `--output` makes these verbs writers, not readers. Verified: `git diff --no-index --output .claude/settings.json <fileA> <fileB>` overwrites the target with attacker-controlled content. | pe-bash |
| 3 | CRITICAL | `.claude/hooks/protect-self-amendment.sh:283-306` | `git -C <dir> diff --output <bare-filename> ...` splits a protected path's directory from its filename across two tokens — defeats both the fast path (fails the `"git diff "` prefix match) and the fallback substring check (`-C` isn't a `cd`/`pushd`/`source`/dot-source token). Same bypass class as round 4's cd-relative-addressing gap, recurring via git's own `-C`/`--git-dir=` instead of a shell builtin. | pe-bash |
| 4 | HIGH / CRITICAL (split view) | `BUGS.md` Status paragraph (~L452-456) + round-5 Fix/Verified prose (~L420,436-439) | Says round 5 is "designed and scratch-verified but not yet applied, pending manual application" — false as of `401d2f7`, which already applied it to the tracked file (confirmed: 25/25 passes against the tracked file, not a scratch copy). Doc actively contradicts its own "Status: resolved" opening clause. | pe-general, tech-writer (duplicate finding) |
| 5 | MEDIUM | `claude/agents/GOVERNANCE-LOG.md` (no entry for `401d2f7`) | No `GOVERNANCE-CHANGE` entry cites commit `401d2f7` (the round-5 logic change to the protected hook script) by hash. The nearest entry (2026-09-15 09:38) was committed at 13:11:50, over 3 hours before `401d2f7` was authored, and only forward-references "this commit's follow-up" without a hash. Per `pe-governance.md`'s own stated rule, a missing/vague audit record for a protected-file change is Critical on its own — logged here as MEDIUM only because the *content* change was already human-authorized and applied; the gap is the log entry, not unauthorized action. | pe-governance, tech-writer (duplicate finding) |
| 6 | MEDIUM | `BUGS.md` Status paragraph | Cites "commits `deda7ef`, `067f0b9`" for the tracked hook-script fix; `067f0b9` only touches the 3 banner-comment files, not the hook script. Misleading if a reader skims only the Status line. | pe-general |
| 7 | MEDIUM | `BUGS.md` "Unrelated discovery" paragraph (uncommitted) | Cites "the cross-session `git reset --hard` collision documented elsewhere in this file's history" — searched the whole file, no such entry exists anywhere in `BUGS.md`. The incident is real (this session's history/engram) but the in-file cross-reference doesn't resolve to anything. | pe-general |
| 8 | LOW | `claude/agents/GOVERNANCE-LOG.md` (2026-09-15 09:38 and 08:00 entries) | Both newest entries use plain `--` instead of the file's own established em-dash (`—`) convention — the exact drift the 2026-09-14 19:40 entry already flagged and asked not to repeat. | pe-governance |
| 9 | LOW | `claude/agents/pe-governance.md:70-73` | Cites only the 08:00 GOVERNANCE-LOG entry for "the hook must guard itself too" — that entry's own `Files:` field omits the hook script (only the 09:38 correction adds it). A reader following the citation alone sees an inconsistency. | tech-writer |

Findings 4 and 5 were each raised independently by two agents — counted once above, agent column shows both.
