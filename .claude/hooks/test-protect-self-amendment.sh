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

# 8. Edit on an agent file NOT in the 5-file allowlist -> no deny (exact allowlist, not */agents/*.md)
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
# Reason substring is the file path, not the word "chaining" -- round-3's allowlist
# rewrite collapsed the chaining-specific deny path into the same generic
# protected_reason() used everywhere else (see protect-self-amendment.sh Finding 1).
actual="$(run_hook "$(build_bash_stdin t12 'git diff -- .claude/settings.json; python3 -c "print(1)"')")"
assert_deny "12 Bash chained via ; bypasses read-only allowlist" "$actual" ".claude/settings.json"

# 13. Command-chaining bypass via "&&" -> deny.
actual="$(run_hook "$(build_bash_stdin t13 "cat .claude/settings.json && echo done")")"
assert_deny "13 Bash chained via && bypasses read-only allowlist" "$actual" ".claude/settings.json"

# 14. Newline-separated two-line command: line 1 is a read verb, line 2 references a
# protected path -> deny. Exercises is_safe_char_command's embedded-newline rejection.
actual="$(run_hook "$(build_bash_stdin t14 "$(printf 'git status\ncat .claude/settings.json')")")"
assert_deny "14 Bash newline-separated command referencing protected path" "$actual" ".claude/settings.json"

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

# ---- summary ------------------------------------------------------------

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
