#!/usr/bin/env bash
# PreToolUse hook -- blocks Edit/Write/Bash/MultiEdit/NotebookEdit calls that would
# modify one of the 6 self-amendment-protected files, unconditionally and independent
# of permissions.defaultMode. Full history (why "deny" not "ask", the defaultMode:auto
# bypass that motivated this hook, the command-chaining/background-operator bypass
# fixes, and the path-spelling/cd-relative-addressing bypass fixed below) is in
# BUGS.md's "self-amendment `ask` gate" Resolved entry and in
# claude/agents/GOVERNANCE-LOG.md. permissions.ask is kept as a defense-in-depth
# fallback alongside this hook, not replaced by it.
#
# Bash 3.2 portable (macOS ships 3.2) -- no mapfile, readarray, declare -A, or
# ${var,,}/${var^^} case conversion. [[ =~ ]] (POSIX ERE) is used for word-boundary
# matching below -- available since bash 3.0, so still portable to 3.2.
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
# instead of protecting anything. This hook has tried, and abandoned, three DENYLIST
# designs in a row -- all three proved bypassable, and all three bypasses are logged in
# BUGS.md's "self-amendment `ask` gate" Resolved entry:
#   1. read-only verb prefix AND no write-token from a fixed denylist -- bypassed by
#      chaining a read verb with `;`/`&&` to a write mechanism not on the list
#      (e.g. `python3 -c "open(...,'w')"`).
#   2. read-only verb prefix AND no shell-chaining/substitution metacharacter from a
#      fixed denylist -- bypassed by the `&` background operator, which was never
#      added to that list.
#   3. (path-relevance PRE-GATE, not a command-shape denylist) the Bash branch only
#      scrutinized a command at all when the protected path appeared as an EXACT
#      LITERAL SUBSTRING of the raw command text -- bypassed by an alternate spelling
#      of the same path (a doubled slash: `.claude//settings.json`; a redundant `./`
#      segment: `.claude/./settings.json`) or by `cd`-ing into the target directory
#      first and addressing the file by its bare name (`cd .claude && printf ... >
#      settings.json`), neither of which ever matched the literal substring check, so
#      the character-allowlist/read-only-verb scrutiny below never even ran.
# Any enumerated "list of dangerous things" (or, per bypass 3, any single fixed
# spelling of a protected path) is structurally incomplete -- there is always one more
# operator, mechanism, spelling, or whitespace character nobody thought to add. The
# fix that closed 1 and 2 was a positive character-class ALLOWLIST instead of a
# metacharacter denylist. The fix that closes 3 (this revision) applies that same
# "allowlist, not enumerate-the-bypasses" philosophy one level up, to how relevance is
# even decided:
#   - The command text is normalized for path-matching (consecutive "/" collapsed to
#     one, "/./ " segments collapsed to "/") before the protected-path substring check
#     runs, so alternate spellings of the same path can't dodge the check.
#   - Whether a command is safe is no longer conditioned on path-relevance at all: a
#     command passing BOTH the character allowlist AND the read-only-verb check is
#     provably a single, unchained, safe-character invocation of a whitelisted read
#     verb -- it cannot write anywhere, period, so it is allowed unconditionally,
#     whether or not a protected path is textually present.
#   - Only a command that FAILS that combined check is then evaluated for relevance:
#     denied if the normalized text references a protected path, OR if the command
#     contains a `cd`/`pushd`/`source` token anywhere -- any of those make the
#     command's effective working directory (and therefore what a bare relative
#     filename resolves to) impossible to determine by static substring matching, so
#     "no protected path is textually present" can no longer be trusted as "this
#     command is irrelevant" once one of those tokens is present.
# A command that fails the safe/read-only check AND has neither a protected-path
# reference nor a cd/pushd/source token is none of this hook's business and is
# allowed -- this hook's scope is the 6 protected files, not general Bash vetting.
#
# Known, accepted over-blocking from the cd/pushd/source rule: a read-only command
# that happens to `cd` somewhere entirely unrelated first (e.g. `cd /tmp && ls`) fails
# the character allowlist (due to `&&`) and is then denied by the cd-token rule even
# though it never goes near a protected file. This is a deliberate tradeoff, not a
# bug: making the cd-token check path-specific (e.g. only firing when a protected
# path also appears somewhere in the command) would reintroduce exactly the kind of
# enumerable, gameable condition this fix exists to eliminate -- cd/pushd/source
# defeat static analysis in general, not just for the 6 protected paths. Fail-closed
# is this hook's stated philosophy throughout; a false positive on an unrelated `cd`
# command is an acceptable cost, a false negative on a protected file is not.
#
# This is a substring/prefix scan, not a shell parser: it cannot see through variable
# expansion or aliases. Fail-closed is the safety net for exactly that gap -- when in
# doubt, deny.
set -euo pipefail

PROTECTED_PATHS="
claude/agents/pe-governance.md
claude/skills/gateflow-review/SKILL.md
claude/skills/_gateflow-shared/pe-agent-template.md
.claude/settings.json
.gateflow/config.json
.claude/hooks/protect-self-amendment.sh
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

normalize_command_for_matching() {
  # $1 = raw command text. Collapses any run of 2+ consecutive "/" down to a single
  # "/", and any "/./ " segment down to "/" -- repeatedly, until a fixed point, so an
  # alternate spelling of a protected path (".claude//settings.json",
  # ".claude/./settings.json") can't dodge the substring check below. Portable bash 3.2
  # parameter-expansion substitution, no sed/external process. Termination is
  # structural, not assumed: every substitution this loop performs strictly shortens
  # the string (each "//" collapse removes one character, each "/./" collapse removes
  # two), and the loop only continues while the string actually changed last pass -- a
  # string bounded below by length 0 cannot shrink forever, so this always halts.
  local text="$1" prev slash="/"
  while :; do
    prev="$text"
    # NOTE: the replacement side of ${var//pat/repl} is a literal string with no
    # escape processing -- a literal "\/" here inserts a literal backslash before
    # the slash instead of meaning "just a slash" (verified directly; this bit
    # exactly the round-2/round-3 "don't assume the first attempt is correct" trap).
    # A variable holding "/" sidesteps the ambiguity entirely.
    text="${text//\/\//$slash}"
    text="${text//\/.\//$slash}"
    [ "$text" = "$prev" ] && break
  done
  printf '%s' "$text"
}

contains_cd_token() {
  # $1 = raw command text. True iff "cd", "pushd", or "source" appears anywhere as a
  # whole word -- not as a substring of a longer identifier ("cdfoo", "mypushd",
  # "sourced" must NOT match). cd/pushd/source make the command's effective working
  # directory (and therefore what a bare relative filename actually resolves to)
  # impossible to determine by static substring matching -- a bare "settings.json"
  # after "cd .claude" reaches the same file ".claude/settings.json" without that
  # path ever being spelled out in the command text. bash's =~ (POSIX ERE, available
  # since bash 3.0) is used unquoted for the pattern itself -- required for portable
  # matching semantics across bash 3.2 builds.
  local text="$1"
  [[ "$text" =~ (^|[^a-zA-Z0-9_])(cd|pushd|source)([^a-zA-Z0-9_]|$) ]]
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
    # defensively; a notebook (.ipynb) structurally can't match any of the 6 (.md/.json/.sh)
    # protected paths anyway, so a miss here is not a protection gap.
    file_path="$(printf '%s' "$input" | jq -r '(.tool_input.file_path)? // empty')"
    check_file_path_tool "$file_path"
    ;;
  Bash)
    command_text="$(printf '%s' "$input" | jq -r '(.tool_input.command)? // empty')"
    [ -n "$command_text" ] || deny "protect-self-amendment: internal error -- Bash call with no tool_input.command, failing closed"

    trimmed_command="$(trim "$command_text")"

    if is_safe_char_command "$trimmed_command" && is_read_only_command "$trimmed_command"; then
      : # character-allowlisted, single invocation of a recognized read-only verb --
        # provably cannot write anywhere, allowed unconditionally regardless of
        # whether a protected path is textually present (see header comment)
    else
      normalized_command="$(normalize_command_for_matching "$command_text")"
      matched_protected=""
      for protected in $PROTECTED_PATHS; do
        case "$normalized_command" in
          *"$protected"*)
            matched_protected="$protected"
            break
            ;;
        esac
      done

      if [ -n "$matched_protected" ]; then
        deny "$(protected_reason "$matched_protected")"
      fi

      if contains_cd_token "$command_text"; then
        deny "protect-self-amendment: command contains cd/pushd/source, which makes cwd-relative addressing of the 6 self-amendment-protected files impossible to rule out by static substring matching, and the command did not pass as a single safe read-only invocation -- failing closed"
      fi
    fi
    ;;
  *)
    : # not a tool this hook cares about -- no opinion
    ;;
esac

exit 0
