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

## Round 2

**SHA:** 38fb720
**Verdict:** changes requested
**Gate Status:** OPEN

Round 1 findings #1–#9: all RESOLVED (verified independently by 4 agents — re-run PoCs deny, GOVERNANCE-LOG append-only intact, citations fixed, test suite 33/33 against the tracked file).

| # | Severity | File:Line | Finding | Agent |
|---|---|---|---|---|
| 1 | CRITICAL | `.claude/hooks/protect-self-amendment.sh:228` (`is_protected_path`), `:378` (`contains_unsafe_git_invocation`), `:416` (`PROTECTED_PATHS` substring loop) | Every protected-path/git-invocation comparison in the file is case-sensitive, but this machine's filesystem (macOS APFS default) is case-insensitive-but-preserving — confirmed live, non-destructively (`Git --version` executed the real git binary; `ls BUGS.MD` resolved to the real `BUGS.md`). `Git -c diff.external=<script> diff HEAD~1 HEAD` (capital G) is not recognized by `contains_unsafe_git_invocation`'s lowercase-only regex and silently allows — same RCE as round-6 finding #1, reopened by one capitalized letter. Same root cause also breaks `is_protected_path`'s exact-match comparison used by the **Edit/Write/MultiEdit path** — the header's claimed "hard, non-heuristic guarantee" — so `Edit` with `file_path: claude/agents/PE-Governance.md` would not match, yet the OS resolves it to the real protected file. | pe-bash |
| 2 | MEDIUM | `claude/agents/GOVERNANCE-LOG.md` (last entry) | The round-6 authorization entry still reads `Date: 2026-09-15 (round 6 remediation, commit hash to follow once applied)` — never backfilled with the actual commit `38fb720`, unlike round 5's parallel `401d2f7` backfill entry. Raised independently by 3 agents. | pe-governance, pe-general, tech-writer |
| 3 | HIGH | `BUGS.md` Status paragraph | Still says round 6 is "pending the same manual-application step" — false as of `38fb720`, which is already HEAD. Same defect shape as round-1 finding #4, recurred one round later. Raised independently by 2 agents. | pe-general, tech-writer |
| 4 | MEDIUM | `BUGS.md` "Fix (round 6)" paragraph | Says the 33-case suite passes "against a byte-identical scratch copy" — now stale, it passes against the tracked file itself. | pe-general |
| 5 | MEDIUM | `.claude/hooks/protect-self-amendment.sh` "Known, accepted over-blocking" section | Documents 2 path-independent over-blocking cases (unrelated `cd`, removed `bat`/`less`/`more`) but omits a 3rd, more common one: `contains_disallowed_escape_char` denies ANY command containing a quote/backslash character regardless of protected-path relevance (e.g. any quoted `grep`/`rg` pattern) — undersells the false-positive surface. | tech-writer |
| 6 | LOW | `.claude/hooks/protect-self-amendment.sh` STOPPING POLICY section | "One dedicated adversarial round" isn't locally defined — recoverable from context elsewhere in the same comment, but not stated where the policy itself is written. Optional. | tech-writer |

Finding 1 is the same class of "alternate spelling a case-sensitive scanner can't see through" as round 4 (path-spelling) and round 5 (backslash/quote) — except here the alternate spelling (capitalization) is not obfuscation, it's a trivial, everyday variant. It also breaks the Edit/Write/MultiEdit "hard guarantee" for the first time across all 6 rounds, since that path relies on the same case-sensitive comparison.
