#!/usr/bin/env bash
# Test harness for protect-self-amendment.sh. Bash 3.2 portable, no bats/shellspec
# dependency (matches this repo's "no new dependency without justification" rule).
# Builds the exact stdin JSON a real PreToolUse hook invocation receives (per
# docs/gateflow/plans/GTF-21-plan.md §1.3), pipes it to the hook, and asserts on
# the JSON shape with jq. Prints PASS/FAIL per case; exits non-zero if any failed.
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

# ---- summary ------------------------------------------------------------

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
