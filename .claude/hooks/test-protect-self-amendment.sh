#!/usr/bin/env bash
# Test harness for protect-self-amendment.sh. Bash 3.2 portable, no bats/shellspec
# dependency (matches this repo's "no new dependency without justification" rule).
# Builds the stdin JSON shape a real PreToolUse hook invocation receives, pipes it
# to the hook, and asserts on the JSON shape with jq. Prints PASS/FAIL per case;
# exits non-zero if any failed. Background/history: BUGS.md's "self-amendment `ask`
# gate" Resolved entry and claude/agents/GOVERNANCE-LOG.md.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/protect-self-amendment.sh"

PASS=0
FAIL=0

# ---- stdin builders -------------------------------------------------------

build_edit_stdin() {
  # $1=session_id $2=tool_name(Edit|MultiEdit) $3=file_path
  jq -n --arg cwd "$REPO_ROOT" --arg fp "$3" --arg tn "$2" --arg id "$1" \
    '{session_id:$id,cwd:$cwd,permission_mode:"auto",hook_event_name:"PreToolUse",tool_name:$tn,tool_input:{file_path:$fp,old_string:"a",new_string:"b"},tool_use_id:$id}'
}

build_multiedit_stdin() {
  # $1=session_id $2=file_path
  jq -n --arg cwd "$REPO_ROOT" --arg fp "$2" --arg id "$1" \
    '{session_id:$id,cwd:$cwd,permission_mode:"auto",hook_event_name:"PreToolUse",tool_name:"MultiEdit",tool_input:{file_path:$fp,edits:[{old_string:"a",new_string:"b"}]},tool_use_id:$id}'
}

build_write_stdin() {
  # $1=session_id $2=file_path
  jq -n --arg cwd "$REPO_ROOT" --arg fp "$2" --arg id "$1" \
    '{session_id:$id,cwd:$cwd,permission_mode:"auto",hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$fp,content:"x"},tool_use_id:$id}'
}

build_bash_stdin() {
  # $1=session_id $2=command
  jq -n --arg cwd "$REPO_ROOT" --arg cmd "$2" --arg id "$1" \
    '{session_id:$id,cwd:$cwd,permission_mode:"auto",hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$cmd},tool_use_id:$id}'
}

build_notebookedit_stdin() {
  # $1=session_id $2=file_path -- best-guess field name, matching the hook's own
  # best-guess handling (see protect-self-amendment.sh's NotebookEdit branch comment).
  jq -n --arg cwd "$REPO_ROOT" --arg fp "$2" --arg id "$1" \
    '{session_id:$id,cwd:$cwd,permission_mode:"auto",hook_event_name:"PreToolUse",tool_name:"NotebookEdit",tool_input:{file_path:$fp,new_source:"x"},tool_use_id:$id}'
}

# ---- runner + assertions ---------------------------------------------------

run_hook() {
  # $1=stdin content. Echoes hook stdout; never lets a missing/failing hook
  # abort the harness (RED-phase safe: hook script may not exist yet).
  local stdin_content="$1"
  local out
  out="$(printf '%s' "$stdin_content" | "$HOOK" 2>/dev/null)"
  printf '%s' "$out"
}

assert_deny() {
  # $1=case name $2=actual output $3=reason substring (optional)
  local case_name="$1" actual="$2" needle="${3:-}"
  local decision
  decision="$(printf '%s' "$actual" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  if [ "$decision" != "deny" ]; then
    echo "FAIL: $case_name -- expected permissionDecision=deny, got '$decision' (raw: $actual)"
    FAIL=$((FAIL + 1))
    return
  fi
  if [ -n "$needle" ]; then
    local reason
    reason="$(printf '%s' "$actual" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)"
    case "$reason" in
      *"$needle"*) ;;
      *)
        echo "FAIL: $case_name -- deny reason did not mention '$needle': $reason"
        FAIL=$((FAIL + 1))
        return
        ;;
    esac
  fi
  echo "PASS: $case_name"
  PASS=$((PASS + 1))
}

assert_no_deny() {
  # $1=case name $2=actual output
  local case_name="$1" actual="$2"
  if [ -z "$actual" ]; then
    echo "PASS: $case_name"
    PASS=$((PASS + 1))
    return
  fi
  local decision
  decision="$(printf '%s' "$actual" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  if [ -z "$decision" ] || [ "$decision" = "null" ]; then
    echo "PASS: $case_name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $case_name -- expected no deny, got permissionDecision='$decision' (raw: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ---- cases ------------------------------------------------------------

# 1. Edit on a protected file -> deny, reason mentions the file
actual="$(run_hook "$(build_edit_stdin t1 Edit claude/agents/pe-governance.md)")"
assert_deny "1 Edit protected pe-governance.md" "$actual" "claude/agents/pe-governance.md"

# 2. Edit on an unprotected file -> no deny
actual="$(run_hook "$(build_edit_stdin t2 Edit README.md)")"
assert_no_deny "2 Edit unprotected README.md" "$actual"

# 3. Write on a protected file -> deny
actual="$(run_hook "$(build_write_stdin t3 .gateflow/config.json)")"
assert_deny "3 Write protected .gateflow/config.json" "$actual"

# 4. Bash command referencing a protected path -> deny
actual="$(run_hook "$(build_bash_stdin t4 "sed -i '' 's/x/y/' .claude/settings.json")")"
assert_deny "4 Bash command referencing .claude/settings.json" "$actual"

# 5. Bash command with no protected path -> no deny
actual="$(run_hook "$(build_bash_stdin t5 "git status")")"
assert_no_deny "5 Bash git status" "$actual"

# 6. MultiEdit on a protected file -> deny (file_path best-guess, fail-closed also acceptable)
actual="$(run_hook "$(build_multiedit_stdin t6 claude/skills/_gateflow-shared/pe-agent-template.md)")"
assert_deny "6 MultiEdit protected pe-agent-template.md" "$actual"

# 7. Malformed stdin -> deny, fail closed, reason mentions parse failure
actual="$(run_hook 'not valid json {{{')"
assert_deny "7 malformed stdin fails closed" "$actual" "parse"

# 8. Edit on an agent file NOT in the protected allowlist -> no deny (exact allowlist, not */agents/*.md)
actual="$(run_hook "$(build_edit_stdin t8 Edit claude/agents/pe-general.md)")"
assert_no_deny "8 Edit non-protected agent file pe-general.md" "$actual"

# 9. Edit on a protected file using an absolute file_path (what real Edit/Write/MultiEdit
# calls actually send) -> deny. Exercises normalize_path's cwd-stripping branch.
actual="$(run_hook "$(build_edit_stdin t9 Edit "$REPO_ROOT/claude/agents/pe-governance.md")")"
assert_deny "9 Edit protected pe-governance.md via absolute path" "$actual" "claude/agents/pe-governance.md"

# 10. NotebookEdit on a best-guess protected file_path -> deny, matching the branch's
# current best-guess handling (tool_input.file_path).
actual="$(run_hook "$(build_notebookedit_stdin t10 .gateflow/config.json)")"
assert_deny "10 NotebookEdit best-guess protected .gateflow/config.json" "$actual"

# 11. Read-only Bash command referencing a protected path -> no deny. Locks in the
# read-vs-write distinction so a future change can't silently regress it either way.
actual="$(run_hook "$(build_bash_stdin t11 "cat .claude/settings.json")")"
assert_no_deny "11 Bash read-only cat on protected .claude/settings.json" "$actual"

# 12. Command-chaining bypass: a read verb chained via ";" with an unrecognized write
# mechanism (python3) -> deny. This is the exact live-reproduced GTF-21 round-2 bypass.
# No reason substring asserted: since round 6, this command also contains the word
# "git" and contains_unsafe_git_invocation fires first (deliberately, independent of
# path-relevance -- see protect-self-amendment.sh's header, bypass 5), so the deny
# reason now cites the git-grammar check rather than the protected path. Still denies
# either way -- only the specific reason text changed, not the security property.
actual="$(run_hook "$(build_bash_stdin t12 'git diff -- .claude/settings.json; python3 -c "print(1)"')")"
assert_deny "12 Bash chained via ; bypasses read-only allowlist" "$actual"

# 13. Command-chaining bypass via "&&" -> deny.
actual="$(run_hook "$(build_bash_stdin t13 "cat .claude/settings.json && echo done")")"
assert_deny "13 Bash chained via && bypasses read-only allowlist" "$actual" ".claude/settings.json"

# 14. Newline-separated two-line command: line 1 is a read verb, line 2 references a
# protected path -> deny. Exercises is_safe_char_command's embedded-newline rejection.
# No reason substring asserted (see case 12's comment -- this command also contains
# "git status" as its first line, so the round-6 git-grammar check fires first).
actual="$(run_hook "$(build_bash_stdin t14 "$(printf 'git status\ncat .claude/settings.json')")")"
assert_deny "14 Bash newline-separated command referencing protected path" "$actual"

# 15. Background-operator bypass ("&"): a read verb backgrounded via "&" with an
# unrecognized write mechanism -> deny. This is the exact live-reproduced GTF-21
# round-3 bypass -- "&" was never on the round-2 CHAIN_TOKENS denylist.
actual="$(run_hook "$(build_bash_stdin t15 'cat .claude/settings.json & python3 -c "open(1,0)"')")"
assert_deny "15 Bash backgrounded via & bypasses read-only allowlist" "$actual" ".claude/settings.json"

# 16. Literal tab character between the verb and the protected path -> deny. A tab is
# whitespace but not the ASCII space the allowlist admits.
actual="$(run_hook "$(build_bash_stdin t16 "$(printf 'cat\t.claude/settings.json')")")"
assert_deny "16 Bash literal tab character" "$actual" ".claude/settings.json"

# 17. Backslash line-continuation splitting the command across two lines -> deny.
actual="$(run_hook "$(build_bash_stdin t17 "$(printf 'cat \\\n.claude/settings.json')")")"
assert_deny "17 Bash backslash line-continuation" "$actual" ".claude/settings.json"

# 18. Leading/trailing whitespace around an otherwise-safe read command is trimmed and
# still allows -- the character allowlist applies to the trimmed command, not proof
# that trimming itself introduces a bypass.
actual="$(run_hook "$(build_bash_stdin t18 "   cat .claude/settings.json   ")")"
assert_no_deny "18 Bash leading/trailing whitespace around safe read still allows" "$actual"

# 19. Round-4 bypass: a doubled slash inside the protected path spelling
# (".claude//settings.json") used to dodge the old exact-literal-substring pre-gate
# entirely -- deny. Confirmed live before the fix: `sed -i '' 's/x/y/'
# .claude//settings.json` was ALLOWED.
actual="$(run_hook "$(build_bash_stdin t19 "sed -i '' 's/x/y/' .claude//settings.json")")"
assert_deny "19 Bash double-slash path-spelling bypass" "$actual" ".claude/settings.json"

# 20. Round-4 bypass: a redundant "/./ " segment inside the protected path spelling
# (".claude/./settings.json") -- same pre-gate dodge as #19, different spelling -> deny.
actual="$(run_hook "$(build_bash_stdin t20 "sed -i '' 's/x/y/' .claude/./settings.json")")"
assert_deny "20 Bash embedded ./ path-spelling bypass" "$actual" ".claude/settings.json"

# 21. Round-4 bypass: cd into the protected directory, then address the file by its
# bare name -- the bare filename alone never matches any PROTECTED_PATHS entry, so the
# old logic never scrutinized this command at all -> deny (via the cd/pushd/source
# rule, not a path match).
actual="$(run_hook "$(build_bash_stdin t21 "cd .claude && printf PWNED > settings.json")")"
assert_deny "21 Bash cd-then-write bare filename bypass" "$actual"

# 22. Documented tradeoff: a read-only command that cd's somewhere entirely unrelated
# first (no protected path anywhere in the command) still denies, because it fails the
# character allowlist (due to "&&") and the cd/pushd/source rule cannot be made
# path-specific without reintroducing the same enumerable fragility the round-4 fix
# eliminates. This is intentional, accepted over-blocking -- see
# protect-self-amendment.sh's header comment -- not a bug to fix.
actual="$(run_hook "$(build_bash_stdin t22 "cd /tmp && ls")")"
assert_deny "22 Bash cd-then-unrelated-read denies (accepted tradeoff)" "$actual"

# 23. Round-5 bypass: dot-source (the POSIX alias for "source") -- never matched by the
# old cd/pushd/source word check since "." is a punctuation character, not a word ->
# deny. Confirmed live before the fix: `. /path/to/malicious.sh` was ALLOWED.
actual="$(run_hook "$(build_bash_stdin t23 ". /path/to/malicious.sh")")"
assert_deny "23 Bash dot-source bypass" "$actual"

# 24. Round-5 bypass: a backslash-escape respelling of a protected path -- bash strips
# the backslash and resolves this to the real path at execution time, but the static
# substring check never sees a contiguous ".claude/settings.json" match -> deny.
# Confirmed live before the fix: `printf PWNED > .cl\aude/settings.json` was ALLOWED.
actual="$(run_hook "$(build_bash_stdin t24 'printf PWNED > .cl\aude/settings.json')")"
assert_deny "24 Bash backslash-escape respelling bypass" "$actual"

# 25. Round-5 bypass: quote-splitting -- adjacent empty quotes concatenate at
# shell-expansion time, so the static substring check never sees a contiguous
# ".claude/settings.json" match -> deny. Confirmed live before the fix: `printf PWNED >
# .clau''de/sett''ings.json` was ALLOWED.
actual="$(run_hook "$(build_bash_stdin t25 "printf PWNED > .clau''de/sett''ings.json")")"
assert_deny "25 Bash quote-splitting respelling bypass" "$actual"

# 26. Round-6: plain "git diff -- <protected path>" (no flags) is a legitimate read of
# a protected file and must still be allowed via the new is_safe_git_readonly_command
# grammar -- the round-6 fix must not break ordinary git-based inspection.
actual="$(run_hook "$(build_bash_stdin t26 "git diff -- .claude/settings.json")")"
assert_no_deny "26 Bash git diff -- <protected path>, no flags, still allows" "$actual"

# 27. Round-6: bare "git status" (no path at all) still allows.
actual="$(run_hook "$(build_bash_stdin t27 "git status")")"
assert_no_deny "27 Bash bare git status still allows" "$actual"

# 28. Round-6 bypass: git config-injection RCE via "-c" before the subcommand.
# Confirmed live before the fix (isolated scratch repo): `git -c
# diff.external=<script> diff HEAD~1 HEAD` executes the configured script as a
# subprocess -- full RCE, entirely outside this hook's visibility, and not contingent
# on referencing a protected path at all.
actual="$(run_hook "$(build_bash_stdin t28 "git -c diff.external=/tmp/evil.sh diff HEAD~1 HEAD")")"
assert_deny "28 Bash git -c config-injection RCE bypass" "$actual"

# 29. Round-6 bypass: "git diff --output <path> ..." (space-separated form) writes
# the diff's own content to an arbitrary file. Confirmed live before the fix: `git
# diff --no-index --output .claude/settings.json <a> <b>` overwrote the target.
actual="$(run_hook "$(build_bash_stdin t29 "git diff --output .claude/settings.json HEAD~1 HEAD")")"
assert_deny "29 Bash git diff --output write bypass" "$actual"

# 30. Round-6 bypass: "git -C <dir> diff --output <bare-name> ..." combines both --
# splits a protected path's directory from its filename across two tokens, defeating
# both the fast path and the (pre-round-6) substring check simultaneously.
actual="$(run_hook "$(build_bash_stdin t30 "git -C .claude diff --output settings.json HEAD~1 HEAD")")"
assert_deny "30 Bash git -C combined bypass" "$actual"

# 31. Round-6: bat, removed from the unconditional fast path per the verified-safe-verb
# checklist (PAGER-driven subprocess surface, precautionary), now denies a protected
# read via the ordinary protected-path substring fallback -- expected over-blocking,
# not a regression (see the hook's header comment).
actual="$(run_hook "$(build_bash_stdin t31 "bat .claude/settings.json")")"
assert_deny "31 Bash bat on protected path now denies (verb removed from fast path)" "$actual"

# 32. Round-6: same for less.
actual="$(run_hook "$(build_bash_stdin t32 "less .claude/settings.json")")"
assert_deny "32 Bash less on protected path now denies (verb removed from fast path)" "$actual"

# 33. Round-6: bat on a NON-protected path still allows -- removing it from the fast
# path doesn't blanket-deny bat, it just routes it through the ordinary fallback like
# any other command this hook has no special opinion on.
actual="$(run_hook "$(build_bash_stdin t33 "bat README.md")")"
assert_no_deny "33 Bash bat on unprotected path still allows" "$actual"

# 34. Round-6 re-review bypass: capitalized "Git" (macOS APFS default is case-
# insensitive-but-preserving -- "Git" resolves to the same real git binary as "git")
# was never matched by contains_unsafe_git_invocation's lowercase-only regex.
# Confirmed live before the fix: `Git -c diff.external=<script> diff HEAD~1 HEAD`
# silently allowed -- the exact same RCE as case 28, reopened by one capital letter.
actual="$(run_hook "$(build_bash_stdin t34 "Git -c diff.external=/tmp/evil.sh diff HEAD~1 HEAD")")"
assert_deny "34 Bash capitalized Git config-injection RCE bypass" "$actual"

# 35. Round-6 re-review bypass: a capitalized protected-path directory segment
# (".CLAUDE/settings.json") resolves to the same real file on a case-insensitive
# filesystem but was never matched by the PROTECTED_PATHS substring loop's exact
# lowercase comparison.
actual="$(run_hook "$(build_bash_stdin t35 "printf PWNED > .CLAUDE/settings.json")")"
assert_deny "35 Bash capitalized protected-path bypass via Bash" "$actual"

# 36. Round-6 re-review bypass, Edit/Write/MultiEdit path: a capitalized file_path
# ("claude/agents/PE-Governance.md") resolves to the same real protected file on a
# case-insensitive filesystem but was never matched by is_protected_path's exact
# case-sensitive comparison -- this is the path the header calls a "hard,
# non-heuristic guarantee," so this bypass matters more than the Bash-side ones.
actual="$(run_hook "$(build_edit_stdin t36 Edit claude/agents/PE-Governance.md)")"
assert_deny "36 Edit capitalized protected pe-governance.md path bypass" "$actual"

# 37. Case-insensitive fix stays conservative in the ALLOW direction too: a
# capitalized but otherwise-legitimate "Git diff -- <path>" now correctly falls
# through to the (now case-insensitive) deny checks instead of being fast-pathed --
# is_safe_git_readonly_command's grammar deliberately stays literal-lowercase-only.
actual="$(run_hook "$(build_bash_stdin t37 "Git diff -- .claude/settings.json")")"
assert_deny "37 Bash capitalized Git diff on protected path now denies (conservative)" "$actual"

# 38. Regression fix: round 6's first contains_unsafe_git_invocation denied ANY git
# subcommand outside the 5-verb read-only grammar, including ordinary `git add`/
# `git commit` on completely unprotected files -- not this hook's business per its
# own stated scope. The narrowed, global-flag-specific check must allow this again.
actual="$(run_hook "$(build_bash_stdin t38 "git add BUGS.md")")"
assert_no_deny "38 Bash git add on unprotected file now allows (regression fix)" "$actual"

# 39. Same regression fix: a plain git commit with no dangerous global flag, no
# protected path, no quotes (message from -F <path>, this repo's own established
# commit pattern) must allow.
actual="$(run_hook "$(build_bash_stdin t39 "git commit -F /tmp/msg.txt")")"
assert_no_deny "39 Bash git commit -F with no protected path now allows (regression fix)" "$actual"

# 40. git add on a PROTECTED path still denies -- the narrowed check doesn't widen
# protection, only stops blanket-denying every non-grammar git subcommand.
actual="$(run_hook "$(build_bash_stdin t40 "git add claude/agents/pe-governance.md")")"
assert_deny "40 Bash git add on protected path still denies" "$actual" "claude/agents/pe-governance.md"

# 41. --git-dir= global flag (same redirection class as -C) -> deny, independent of
# protected-path presence, regardless of subcommand.
actual="$(run_hook "$(build_bash_stdin t41 "git --git-dir=/tmp/evil/.git status")")"
assert_deny "41 Bash git --git-dir= global flag denies" "$actual"

# 42. --work-tree= global flag -> deny, same class as --git-dir=.
actual="$(run_hook "$(build_bash_stdin t42 "git --work-tree=/tmp/evil status")")"
assert_deny "42 Bash git --work-tree= global flag denies" "$actual"

# 43. --exec-path= global flag -- redirects where git looks for its OWN subcommand
# binaries, can hijack any git subcommand's implementation -> deny.
actual="$(run_hook "$(build_bash_stdin t43 "git --exec-path=/tmp/evil status")")"
assert_deny "43 Bash git --exec-path= global flag denies" "$actual"

# 44. Round-3 re-review bypass: shell glob/wildcard expansion (*, ?, [) is never
# expanded by this hook's static text match but IS expanded by the real shell at
# execution time. Confirmed live before the fix: `printf PWNED >
# .claude/settings.????` wrote to the real settings.json in an isolated scratch copy
# while the hook emitted no deny.
actual="$(run_hook "$(build_bash_stdin t44 "printf PWNED > .claude/settings.????")")"
assert_deny "44 Bash glob-wildcard path-expansion bypass" "$actual"

# 45. Round-3 re-review bypass: git --config-env= has identical config-injection
# power to -c but reads its value from an env var, never containing the literal
# "-c" token.
actual="$(run_hook "$(build_bash_stdin t45 "git --config-env=diff.external=EVIL diff HEAD~1 HEAD")")"
assert_deny "45 Bash git --config-env= config-injection bypass" "$actual"

# 46. Round-3 re-review bypass: GIT_DIR= (and GIT_WORK_TREE=/GIT_CONFIG_COUNT=/
# GIT_CONFIG_KEY_*/GIT_CONFIG_VALUE_*) env-var prefixes achieve the same
# redirection/config-injection as -C/--git-dir=/-c with zero flag tokens present.
actual="$(run_hook "$(build_bash_stdin t46 "GIT_DIR=/tmp/evil/.git git status")")"
assert_deny "46 Bash GIT_DIR= env-var redirection bypass" "$actual"

# 47. Round-3 re-review bypass: `env -C <dir>` (and other external tools' own
# cwd-redirect flags -- tar -C, make -C, rsync, etc.) is invisible to the
# cd/pushd/source word check. Confirmed live before the fix: `env -C <dirB> cp
# <payload> bare.txt` placed the file inside the redirected directory.
actual="$(run_hook "$(build_bash_stdin t47 "env -C .claude cp /tmp/payload.txt settings.json")")"
assert_deny "47 Bash env -C cwd-redirect bypass" "$actual"

# 48. Round-3 re-review bypass: two adjacent bare \$var references concatenate into
# the real protected filename at shell-expansion time with no quote or backslash
# character present at all.
actual="$(run_hook "$(build_bash_stdin t48 "part1=settings.js; part2=on; printf PWNED > .claude/\$part1\$part2")")"
assert_deny "48 Bash parameter-concatenation respelling bypass" "$actual"

# ---- summary ------------------------------------------------------------

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
