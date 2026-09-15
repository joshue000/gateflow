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
# instead of protecting anything. A prior version of this hook tried to allow that via
# "read-only verb prefix AND no write-token from a fixed denylist" -- that denylist
# could never be exhaustive (chaining a read verb with `;`, `&&` etc. and any write
# mechanism not on the list sailed through). The fix: a command referencing a
# protected path is allowed through ONLY when (a) it contains NO shell chaining or
# substitution metacharacter anywhere (`;`, `&&`, `||`, `|`, a backtick, `$(`, `>`,
# `<`, or an embedded newline) -- checked first, as a blanket disqualifier -- AND
# (b) the entire trimmed command is a single, unchained invocation of a recognized
# read-only verb. Anything else -- including any command shape this scan doesn't
# recognize -- denies. This is a substring/prefix scan, not a shell parser: it cannot
# see through variable expansion, aliases, or a write hidden behind an unrecognized
# wrapper command with none of the scanned metacharacters. Fail-closed is the safety
# net for exactly that gap -- when in doubt, deny.
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

# Shell metacharacters/chaining or substitution operators. If ANY of these appears
# anywhere in a command that references a protected path, the command is denied
# outright, before the read-only verb check even runs -- a single unchained read
# command has no legitimate need for any of these against a protected path, and
# their presence means this scan can no longer safely vouch for the rest of the
# command (see the Bash-command design decision comment above). Single-quoted so
# the backtick and $( are stored literally, not evaluated at assignment time.
CHAIN_TOKENS=';
&&
||
|
`
$(
>
<'

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

contains_chain_operator() {
  # $1 = full (untrimmed) command text. True if any shell chaining/substitution/
  # redirection metacharacter appears anywhere in it.
  local text="$1" token
  local old_ifs="$IFS"
  IFS='
'
  for token in $CHAIN_TOKENS; do
    case "$text" in
      *"$token"*)
        IFS="$old_ifs"
        return 0
        ;;
    esac
  done
  IFS="$old_ifs"
  return 1
}

contains_newline() {
  # $1 = full (untrimmed) command text. True if it spans more than one line.
  case "$1" in
    *$'\n'*) return 0 ;;
    *) return 1 ;;
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
      if contains_chain_operator "$command_text" || contains_newline "$command_text"; then
        deny "Bash command references self-amendment-protected file '$matched_protected' and contains shell chaining/substitution/redirection (;, &&, ||, |, a backtick, \$(, >, <, or an embedded newline) -- cannot safely verify the whole command is read-only, failing closed per CLAUDE.md. Explicit human sign-off, logged in claude/agents/GOVERNANCE-LOG.md, is required before this change can be applied."
      fi

      trimmed_command="$command_text"
      read -r trimmed_command <<EOF_CMD || true
$command_text
EOF_CMD
      if is_read_only_command "$trimmed_command"; then
        : # single, unchained invocation of a recognized read-only verb referencing a protected path -- allow
      else
        deny "Bash command references self-amendment-protected file '$matched_protected' per CLAUDE.md -- it requires explicit human sign-off, logged in claude/agents/GOVERNANCE-LOG.md, before this change can be applied."
      fi
    fi
    ;;
  *)
    : # not a tool this hook cares about -- no opinion
    ;;
esac

exit 0
