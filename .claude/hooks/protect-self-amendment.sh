#!/usr/bin/env bash
# PreToolUse hook -- blocks Edit/Write/Bash/MultiEdit/NotebookEdit calls that would
# modify one of the 5 self-amendment-protected files, unconditionally and independent
# of permissions.defaultMode. Full history (why "deny" not "ask", the defaultMode:auto
# bypass that motivated this hook, and the later command-chaining bypass fix) is in
# BUGS.md's "self-amendment `ask` gate" Resolved entry and in
# claude/agents/GOVERNANCE-LOG.md. permissions.ask is kept as a defense-in-depth
# fallback alongside this hook, not replaced by it.
#
# Bash 3.2 portable (macOS ships 3.2) -- no mapfile, readarray, declare -A, or
# ${var,,}/${var^^} case conversion.
#
# Contract: reads the PreToolUse stdin JSON once, prints at most one JSON object to
# stdout, always exits 0. On no match: prints nothing. On match, or on any internal
# error (missing jq, malformed stdin, unrecognized shape): prints a "deny" decision.
# An internal error must never look like "no opinion" -- this hook fails closed.
#
# Bash-command design decision: a command whose text merely CONTAINS a protected
# path is not automatically denied. Read-only inspection of a protected file (e.g.
# `cat .claude/settings.json`, `git log -- .gateflow/config.json`) is legitimate and
# common during review/debugging, and blanket-denying it trains reflexive workarounds
# instead of protecting anything. This hook has tried, and abandoned, two DENYLIST
# designs in a row -- both proved bypassable, and both bypasses are logged in
# BUGS.md's "self-amendment `ask` gate" Resolved entry:
#   1. read-only verb prefix AND no write-token from a fixed denylist -- bypassed by
#      chaining a read verb with `;`/`&&` to a write mechanism not on the list
#      (e.g. `python3 -c "open(...,'w')"`).
#   2. read-only verb prefix AND no shell-chaining/substitution metacharacter from a
#      fixed denylist -- bypassed by the `&` background operator, which was never
#      added to that list.
# Any enumerated "list of dangerous things" is structurally incomplete -- there is
# always one more operator, mechanism, or whitespace character nobody thought to add.
# The fix is a positive character-class ALLOWLIST instead: a command referencing a
# protected path is allowed through ONLY when (a) every character in the
# leading/trailing-trimmed command is an ASCII letter, digit, space, or one of the
# punctuation characters `- _ / . : ~` -- checked first, as a blanket gate -- AND
# (b) the entire trimmed command is a single invocation of a recognized read-only
# verb. Every shell metacharacter this hook cares about (`;`, `&`, `&&`, `||`, `|`,
# a backtick, `$(`, `>`, `<`, a quote, a tab, a backslash, an embedded newline) falls
# outside that allowed set by construction, so none of them need to be enumerated --
# there is no "one more operator" to miss. Anything else -- including any command
# shape this scan doesn't recognize -- denies. This is a substring/prefix scan, not a
# shell parser: it cannot see through variable expansion or aliases. Fail-closed is
# the safety net for exactly that gap -- when in doubt, deny.
set -euo pipefail

PROTECTED_PATHS="
claude/agents/pe-governance.md
claude/skills/gateflow-review/SKILL.md
claude/skills/_gateflow-shared/pe-agent-template.md
.claude/settings.json
.gateflow/config.json
"

# Command prefixes (after trimming leading whitespace) recognized as read-only.
READ_ONLY_VERBS="
git log
git diff
git show
git blame
git status
cat
bat
less
more
head
tail
grep
rg
wc
ls
jq
"

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"protect-self-amendment: internal error -- jq not found, failing closed"}}'
  exit 0
}

input="$(cat)"

printf '%s' "$input" | jq -e . >/dev/null 2>&1 \
  || deny "protect-self-amendment: internal error -- malformed stdin (JSON parse failure), failing closed"

printf '%s' "$input" | jq -e 'type == "object"' >/dev/null 2>&1 \
  || deny "protect-self-amendment: internal error -- top-level JSON is not an object, failing closed"

tool_name="$(printf '%s' "$input" | jq -r '(.tool_name)? // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

normalize_path() {
  # Strip a leading "./" or an absolute cwd/ prefix so both relative and
  # cwd-absolute file_path values compare against the same relative list.
  local raw="$1"
  case "$raw" in
    "$cwd"/*) raw="${raw#"$cwd"/}" ;;
  esac
  case "$raw" in
    ./*) raw="${raw#./}" ;;
  esac
  printf '%s' "$raw"
}

is_protected_path() {
  local candidate="$1" protected
  for protected in $PROTECTED_PATHS; do
    [ "$candidate" = "$protected" ] && return 0
  done
  return 1
}

protected_reason() {
  printf 'File '\''%s'\'' is self-amendment-protected per CLAUDE.md -- it requires explicit human sign-off, logged in claude/agents/GOVERNANCE-LOG.md, before this change can be applied.' "$1"
}

check_file_path_tool() {
  # $1 = raw tool_input.file_path (may be empty)
  local file_path="$1" norm
  [ -n "$file_path" ] || return 0
  norm="$(normalize_path "$file_path")"
  if is_protected_path "$norm"; then
    deny "$(protected_reason "$file_path")"
  fi
}

is_read_only_command() {
  # $1 = trimmed command text. Matches only on a whole-token verb prefix (the
  # verb followed by a space, or the verb alone) -- "catbadcommand" does not match "cat".
  local text="$1" verb
  local old_ifs="$IFS"
  IFS='
'
  for verb in $READ_ONLY_VERBS; do
    case "$text" in
      "$verb"|"$verb "*)
        IFS="$old_ifs"
        return 0
        ;;
    esac
  done
  IFS="$old_ifs"
  return 1
}

trim() {
  # $1 = command text. Strips only leading/trailing whitespace (space, tab,
  # newline, CR, FF, VT) -- an embedded newline in the middle of the command is
  # deliberately left intact so is_safe_char_command below still sees it and
  # denies. Portable bash 3.2 parameter-expansion trim, no external process.
  local var="$1"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

is_safe_char_command() {
  # $1 = trimmed command text. True iff EVERY character in it is an ASCII
  # letter, digit, space, or one of the safe punctuation characters - _ / . : ~
  # -- the positive allowlist gate described in the Bash-command design
  # decision comment above. Any other character anywhere (;, &, &&, ||, |, a
  # backtick, $(, >, <, a quote, a tab, a backslash, an embedded newline, ...)
  # fails this by construction, with nothing to enumerate.
  case "$1" in
    *[!a-zA-Z0-9\ _./:~-]*) return 1 ;;
    *) return 0 ;;
  esac
}

case "$tool_name" in
  Edit|Write|MultiEdit)
    file_path="$(printf '%s' "$input" | jq -r '(.tool_input.file_path)? // empty')"
    if [ -z "$file_path" ]; then
      deny "protect-self-amendment: internal error -- $tool_name call with no tool_input.file_path, failing closed"
    fi
    check_file_path_tool "$file_path"
    ;;
  NotebookEdit)
    # NotebookEdit's tool_input field name is unconfirmed. Best-guess file_path, checked
    # defensively; a notebook (.ipynb) structurally can't match any of the 5 (.md/.json)
    # protected paths anyway, so a miss here is not a protection gap.
    file_path="$(printf '%s' "$input" | jq -r '(.tool_input.file_path)? // empty')"
    check_file_path_tool "$file_path"
    ;;
  Bash)
    command_text="$(printf '%s' "$input" | jq -r '(.tool_input.command)? // empty')"
    [ -n "$command_text" ] || deny "protect-self-amendment: internal error -- Bash call with no tool_input.command, failing closed"

    matched_protected=""
    for protected in $PROTECTED_PATHS; do
      case "$command_text" in
        *"$protected"*)
          matched_protected="$protected"
          break
          ;;
      esac
    done

    if [ -n "$matched_protected" ]; then
      trimmed_command="$(trim "$command_text")"
      if is_safe_char_command "$trimmed_command" && is_read_only_command "$trimmed_command"; then
        : # character-allowlisted, single invocation of a recognized read-only verb referencing a protected path -- allow
      else
        deny "$(protected_reason "$matched_protected")"
      fi
    fi
    ;;
  *)
    : # not a tool this hook cares about -- no opinion
    ;;
esac

exit 0
