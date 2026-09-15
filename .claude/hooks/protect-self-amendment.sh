#!/usr/bin/env bash
# PreToolUse hook -- blocks Edit/Write/Bash/MultiEdit/NotebookEdit calls that would
# modify one of the 6 self-amendment-protected files, unconditionally and independent
# of permissions.defaultMode. Full history (why "deny" not "ask", the defaultMode:auto
# bypass that motivated this hook, the command-chaining/background-operator bypass
# fixes, the path-spelling/cd-relative-addressing bypass fix, the round-5
# dot-source/backslash/quote-splitting bypass fix, and the round-6 git-invocation
# bypass fix below) is in BUGS.md's "self-amendment `ask` gate" Resolved entry and in
# claude/agents/GOVERNANCE-LOG.md. permissions.ask is kept as a defense-in-depth
# fallback alongside this hook, not replaced by it.
#
# LIMITS OF TEXT-BASED BASH SCANNING -- READ THIS BEFORE RELYING ON THE BASH PATH:
# the Bash branch below is a static text scan, not a shell parser or interpreter.
# Scanning shell command TEXT for danger has an inherent, irreducible completeness
# limit: a shell has an effectively unbounded number of ways to obfuscate a string
# before executing it, and beyond the shell itself, an individual TOOL considered
# "read-only" can still have its own config/env/plugin-driven subprocess-spawning
# surface (round 6's discovery -- see bypass 5 below). This hook provides strong
# protection against the bug it was originally built for (silent, unprompted
# Edit/Write against a protected file under permissions.defaultMode:auto), and against
# unsophisticated or accidental Bash usage, and reasonable protection against common
# obfuscation techniques -- but it does NOT claim, and will not claim, to be airtight
# against a sophisticated, deliberately adversarial agent using Bash specifically to
# evade it. The hard, unconditional guarantee this hook provides, with no equivalent
# gap, is the Edit/Write/MultiEdit path: those tool calls carry a structured file_path
# field with no shell to obfuscate through, so that path's protection is not a
# heuristic.
#
# REVIEW SCOPE / STOPPING POLICY (set 2026-09-15, GTF-21 round 6, explicit repo-owner
# decision -- do not silently relitigate this in a future review round):
#   1. One dedicated adversarial round per hook change ("round" = one dedicated
#      `pe-bash` gateflow-review pass over a change to this file, as tracked in
#      BUGS.md's round-N findings -- not a PR, not a calendar period). Whatever a
#      `pe-bash` review finds in that round gets fixed once, in that round. A bypass
#      class discovered LATER, in a future unrelated session, is a new BUGS.md entry
#      / new ticket -- it does not retroactively reopen whatever ticket last touched
#      this file.
#   2. Verified-safe-verb checklist for READ_ONLY_VERBS (the character-allowlist fast
#      path below): a verb is added to that list ONLY after confirming it has NO
#      config/env/plugin-driven subprocess-spawning surface (does it read a pager
#      variable, an external-diff/merge setting, a preprocessor hook, a plugin
#      directory, etc). If that audit is unclear or unconfirmed for a verb, it does
#      NOT get unconditional-allow treatment -- it goes through the ordinary fallback
#      checks below like any other command this hook has no special opinion on. This
#      is why `git log/diff/show/blame/status` (config-injectable via `-c`,
#      `core.pager`, `diff.external`) and `bat`/`less`/`more` (PAGER/LESSOPEN-driven)
#      are NOT unconditional-fast-path verbs even though they are common read
#      commands -- see bypass 5 below for git's dedicated, stricter grammar instead.
# This replaces any future round's temptation to declare "this is the last round" as
# an assertion (round 5 tried that; round 6 immediately found a new bypass CLASS, not
# just a new spelling, proving the assertion wrong within one round) with a checkable
# criterion: did THIS round's dedicated adversarial pass get fixed? If yes, this file
# is done for this ticket, regardless of whether a hypothetical future bypass might
# still exist. Residual risk beyond what a dedicated round found is an accepted,
# permanent, documented limitation of static text scanning as a technique -- not an
# open-ended obligation to keep re-auditing this file indefinitely.
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
# instead of protecting anything. This hook has tried, and abandoned, four DENYLIST-
# shaped designs in a row -- all four proved bypassable, and all four bypasses are
# logged in BUGS.md's "self-amendment `ask` gate" Resolved entry:
#   1. read-only verb prefix AND no write-token from a fixed denylist -- bypassed by
#      chaining a read verb with `;`/`&&` to a write mechanism not on the list.
#   2. read-only verb prefix AND no shell-chaining/substitution metacharacter from a
#      fixed denylist -- bypassed by the `&` background operator, never on that list.
#   3. (path-relevance PRE-GATE) the Bash branch only scrutinized a command at all
#      when the protected path appeared as an EXACT LITERAL SUBSTRING of the raw
#      command text -- bypassed by an alternate spelling (doubled slash, redundant
#      `./`) or by `cd`-ing into the target directory first and addressing the file by
#      its bare name.
#   4. (dot-source / backslash-escape / quote-splitting, round 5) even with bypass 3's
#      fix in place, three further single, unchained commands still slipped through:
#      dot-source (`.` as the POSIX alias for `source`, never matched by the word
#      check); a backslash respelling of a protected path; adjacent empty quotes that
#      concatenate at shell-expansion time.
#   5. (git invocation surface, round 6) even with bypass 1-4 all closed, `git`
#      itself -- one of the READ_ONLY_VERBS entries -- turned out to violate this
#      hook's own core invariant ("a safe-character, read-only-verb command cannot
#      write anywhere, period"). Verified, concrete PoCs (isolated scratch repo, never
#      run against this repo): `git -c diff.external=<script> diff HEAD~1 HEAD`
#      configures git to run an attacker-controlled program as its diff driver --
#      full RCE, entirely outside this hook's (or any PreToolUse hook's) visibility,
#      and NOT contingent on the command textually referencing a protected path at
#      all; `git diff --output <path> ...` (space-separated form; `=`-joined already
#      failed the character allowlist) writes the diff's own content to an arbitrary
#      file, letting `git diff --no-index --output .claude/settings.json <a> <b>`
#      overwrite a protected file directly; `git -C <dir> diff --output <bare-name>
#      ...` combines both, splitting a protected path's directory from its filename
#      across two tokens, defeating the substring check too. The lesson (see the
#      REVIEW SCOPE / STOPPING POLICY above): "is this verb read-only" is not a stable
#      property of the verb's NAME -- git's `-c`/`-C`/`--git-dir=`/`--output` global
#      and per-command flag surface makes it a write-and-exec-capable tool disguised
#      as a read one. Fixed by removing git from the unconditional character-
#      allowlist fast path entirely and giving it its own, much stricter, positive
#      grammar (`is_safe_git_readonly_command`): the trimmed command must start with
#      an EXACT literal `git <verb>` (no token, flagged or not, between "git" and the
#      verb -- this is what rules out `-c`/`-C`/`--git-dir=` etc as a class, not one
#      enumerated flag at a time), and no token anywhere else in the command may start
#      with `-` except the literal `--` separator (this is what rules out `--output`
#      and any other future flag as a class). Any other `git` invocation --
#      chained, flagged, or otherwise not matching that exact grammar -- is denied
#      outright by `contains_unsafe_git_invocation`, independent of whether a
#      protected path is textually present, because git's RCE surface doesn't need
#      one: once a subprocess is running, what it does next is no longer this hook's
#      business to detect via text matching.
#   6. (case-insensitivity, round 6 re-review) even with bypass 5's fix in place,
#      every protected-path/git-invocation comparison in this file (`is_protected_path`,
#      `contains_unsafe_git_invocation`, the `PROTECTED_PATHS` substring loop) was
#      case-sensitive -- but this machine's default filesystem (macOS APFS) is
#      case-insensitive-but-preserving. `Git -c diff.external=<script> diff HEAD~1
#      HEAD` (capital G) resolved to the same real git binary at the OS level while
#      failing every case-sensitive text check in this file -- reopening bypass 5's
#      RCE with one capitalized letter. The same root cause also broke
#      `is_protected_path`, used by the Edit/Write/MultiEdit path this header
#      elsewhere calls a "hard, non-heuristic guarantee" -- an `Edit` with
#      `file_path: claude/agents/PE-Governance.md` would not case-sensitively match,
#      yet the OS resolves it to the real protected file. Fixed by lowercasing both
#      sides of every comparison (`tr '[:upper:]' '[:lower:]'`) before matching --
#      `PROTECTED_PATHS` entries are already all-lowercase, so only the candidate/
#      command side needs folding. `is_safe_git_readonly_command`'s ALLOW grammar is
#      deliberately NOT made case-insensitive -- it stays literal-lowercase-only,
#      since only the one exact trusted spelling should ever fast-path; a capitalized
#      `Git diff -- <path>` now correctly falls through to the (now case-insensitive)
#      deny checks instead of being fast-pathed, which is the conservative direction.
# Any enumerated "list of dangerous things" (or, per bypass 3, any single fixed
# spelling of a protected path) is structurally incomplete -- there is always one more
# operator, mechanism, spelling, or whitespace character nobody thought to add. Every
# fix above replaced an enumerated denylist with a positive ALLOWLIST one level up:
# bypasses 1-2 -> a character-class allowlist instead of a metacharacter denylist;
# bypass 3 -> normalizing the path text instead of a single fixed spelling, and
# deciding safety independent of path-relevance; bypass 4 -> extending what counts as
# an address-obscuring token/character; bypass 5 -> replacing "is this verb's NAME on
# a safe list" with "does this EXACT invocation match a verified-safe grammar",
# per-tool, informed by that tool's own config/plugin surface (the verified-safe-verb
# checklist in the STOPPING POLICY above).
#   - The command text is normalized for path-matching (consecutive "/" collapsed to
#     one, "/./ " segments collapsed to "/") before the protected-path substring check
#     runs, so alternate spellings of the same path can't dodge the check.
#   - A command is allowed unconditionally, regardless of whether a protected path is
#     textually present, ONLY if it passes the character allowlist AND (matches a
#     verified-safe read-only verb prefix from READ_ONLY_VERBS OR matches git's
#     dedicated safe-read-only grammar). Both conditions together prove the command
#     cannot write anywhere and cannot invoke an attacker-controlled subprocess.
#   - A command that fails that combined check is evaluated for relevance in a fixed
#     order: denied if it invokes `git` outside the safe grammar (bypass 5, checked
#     independent of path-relevance); denied if the normalized text references a
#     protected path; denied if it contains a `cd`/`pushd`/`source` token or a bare
#     `.` dot-source command word (cwd becomes undeterminable); denied if it contains
#     a backslash or quote character (path can be respelled/reconstructed around the
#     literal check). A command failing the fast path but triggering NONE of these is
#     none of this hook's business and is allowed -- this hook's scope is the 6
#     protected files plus git's independently-dangerous RCE surface, not general Bash
#     vetting.
#
# Known, accepted over-blocking: a read-only command that happens to `cd` somewhere
# entirely unrelated first (e.g. `cd /tmp && ls`) fails the character allowlist (due to
# `&&`) and is then denied by the cd-token rule even though it never goes near a
# protected file -- deliberate, not a bug (see bypass 4's fix rationale). The same,
# path-independent over-blocking applies to ANY command containing a backslash or
# quote character at all (see bypass 4's `contains_disallowed_escape_char`) -- a
# perfectly ordinary quoted `grep`/`rg` pattern with no relation to a protected file
# denies too, since this check runs regardless of protected-path relevance, same as
# the cd-token and unsafe-git checks. This is the single most common source of
# over-blocking in practice, more so than the two narrower cases below -- not a
# defect, just worth knowing before reaching for a quoted pattern in this repo. The
# same tradeoff now also applies to `bat`/`less`/`more`: removed from the unconditional
# fast path per the verified-safe-verb checklist, a plain `bat .claude/settings.json`
# or `less .claude/settings.json` now denies (caught by the protected-path substring
# check in the fallback) where it previously allowed -- reading a protected file this
# way now requires `cat`/`head`/`tail`/`grep`/`rg`/`wc`/`ls`/`jq` instead, all
# confirmed to have no config/env/plugin subprocess-spawning surface. Fail-closed is
# this hook's stated philosophy throughout; a false positive on an unrelated or
# no-longer-fast-pathed command is an acceptable cost, a false negative on a protected
# file is not.
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
# git's log/diff/show/blame/status verbs are handled separately by
# is_safe_git_readonly_command below -- they are NOT in this list (see bypass 5 /
# the STOPPING POLICY's verified-safe-verb checklist in the header comment). bat,
# less, and more are likewise excluded (PAGER/LESSOPEN-driven subprocess-spawning
# surface, precautionary per the same checklist).
READ_ONLY_VERBS="
cat
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
  # $1 = normalized candidate path. Compared case-insensitively (lowercased against
  # PROTECTED_PATHS, which are already all-lowercase) -- see bypass 6 in the header:
  # this machine's default filesystem is case-insensitive-but-preserving, so
  # "claude/agents/PE-Governance.md" resolves to the same real file as the lowercase
  # spelling even though a case-sensitive string compare would miss it.
  local candidate="$1" protected lower_candidate
  lower_candidate="$(printf '%s' "$candidate" | tr '[:upper:]' '[:lower:]')"
  for protected in $PROTECTED_PATHS; do
    [ "$lower_candidate" = "$protected" ] && return 0
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
  # alternate spelling of a protected path can't dodge the substring check below.
  # Portable bash 3.2 parameter-expansion substitution, no sed/external process.
  # Termination is structural: every substitution strictly shortens the string, and
  # the loop only continues while it actually changed last pass.
  local text="$1" prev slash="/"
  while :; do
    prev="$text"
    text="${text//\/\//$slash}"
    text="${text//\/.\//$slash}"
    [ "$text" = "$prev" ] && break
  done
  printf '%s' "$text"
}

contains_cd_token() {
  # $1 = raw command text. True iff "cd", "pushd", or "source" appears anywhere as a
  # whole word, OR a bare "." (the POSIX dot-source alias for "source") appears
  # anywhere as a standalone command word (boundary: preceded by start-of-
  # string/";"/"&"/"|"/whitespace, followed by whitespace or end-of-string -- so it
  # never matches ".claude/settings.json", "./relative/path", or "3.14"). All of these
  # make the command's effective working directory (and therefore what a bare relative
  # filename resolves to) impossible to determine by static substring matching. Note:
  # git's OWN cwd-changing flag (`-C <dir>`) is intentionally NOT handled here -- it's
  # closed by `contains_unsafe_git_invocation` instead, since any `git` invocation
  # outside the safe grammar is denied regardless of which flag it uses.
  local text="$1"
  [[ "$text" =~ (^|[^a-zA-Z0-9_])(cd|pushd|source)([^a-zA-Z0-9_]|$) ]] && return 0
  [[ "$text" =~ (^|[;\&\|[:space:]])\.([[:space:]]|$) ]] && return 0
  return 1
}

contains_disallowed_escape_char() {
  # $1 = raw command text. True iff a backslash, single quote, or double quote
  # character appears anywhere -- these can respell or reconstruct a protected path in
  # ways static substring matching cannot see through (see bypass 4 in the header).
  case "$1" in
    *\\*) return 0 ;;
    *"'"*) return 0 ;;
    *'"'*) return 0 ;;
  esac
  return 1
}

is_safe_git_readonly_command() {
  # $1 = trimmed command text. True iff this is EXACTLY a single "git <verb>
  # [args...]" invocation, where <verb> is one of the verified-read-only verbs
  # (log, diff, show, blame, status), <verb> is the literal token immediately
  # after "git " with nothing else between them (this alone rules out any global
  # flag -- -c, -C, --git-dir=, --work-tree=, --exec-path=, --namespace=, ... --
  # as a CLASS, since none of them can appear between "git" and the verb in a
  # matching command), and no token anywhere else in the command starts with "-"
  # except the literal "--" separator token (this rules out --output and any
  # other flag, before or after the verb, also as a class). This is a positive
  # grammar, not an enumerated flag denylist -- see bypass 5 in the header comment.
  local text="$1" verb rest word
  case "$text" in
    "git log"|"git log "*) verb="log" ;;
    "git diff"|"git diff "*) verb="diff" ;;
    "git show"|"git show "*) verb="show" ;;
    "git blame"|"git blame "*) verb="blame" ;;
    "git status"|"git status "*) verb="status" ;;
    *) return 1 ;;
  esac
  rest="${text#git $verb}"
  for word in $rest; do
    case "$word" in
      --) ;;
      -*) return 1 ;;
    esac
  done
  return 0
}

contains_unsafe_git_invocation() {
  # $1 = raw command text. Only called once a command has already FAILED the fast
  # combined check (is_safe_char_command + (is_read_only_command OR
  # is_safe_git_readonly_command)). True iff the command invokes git AND contains one
  # of git's own dangerous global options -- checked independent of protected-path
  # relevance, because these options are dangerous regardless of what else the
  # command references:
  #   -c <key>=<value>  (folds from -C too, post-lowercasing) -- arbitrary config
  #     injection (diff.external, core.pager, core.editor, credential.helper,
  #     uploadpack.packObjectsHook, ...) usable with ANY git subcommand, not just
  #     diff/log/show.
  #   -C <path>         -- redirects git's cwd/repo, which can point at an
  #     attacker-controlled repo whose own .git/config achieves the same as -c.
  #   --git-dir=/--work-tree=  -- same redirection class as -C.
  #   --exec-path=      -- redirects where git looks for its OWN subcommand
  #     binaries -- can hijack any git subcommand's implementation.
  # This is git's own finite, git-project-defined set of global options with known
  # execution-redirection semantics -- a closed, stable list documented in git(1),
  # not an open-ended shell-obfuscation enumeration. Deliberately narrower than an
  # earlier version of this function (round 6) that denied ANY git subcommand
  # outside a 5-verb read-only grammar -- that blocked ordinary `git add`/`git
  # commit`/`git push` etc. even with zero dangerous flags, which is not this
  # hook's business (its scope is the 6 protected files plus git's
  # independently-dangerous global-flag surface, not general git vetting -- see
  # BUGS.md's round-6 re-review entry for the regression this replaced). A git
  # invocation with none of these flags falls through to the SAME
  # protected-path/cd-token/escape-char relevance checks as any other command --
  # e.g. `git diff --output <protected-path> ...` (no -C) is still caught by the
  # ordinary protected-path substring match below, since the target has to be
  # named directly for this hook to care. Compared case-insensitively (see bypass
  # 6) -- "Git -c diff.external=..." resolves to the same real git binary as
  # "git -c ..." on this machine's case-insensitive-but-preserving default
  # filesystem.
  local text="$1" lower_text
  lower_text="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower_text" =~ (^|[^a-zA-Z0-9_])git([^a-zA-Z0-9_]|$) ]] || return 1
  [[ "$lower_text" =~ (^|[[:space:]])-c([[:space:]]|$) ]] && return 0
  [[ "$lower_text" =~ (^|[[:space:]])--git-dir(=|[[:space:]]) ]] && return 0
  [[ "$lower_text" =~ (^|[[:space:]])--work-tree(=|[[:space:]]) ]] && return 0
  [[ "$lower_text" =~ (^|[[:space:]])--exec-path(=|[[:space:]]) ]] && return 0
  return 1
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

    if is_safe_char_command "$trimmed_command" && { is_read_only_command "$trimmed_command" || is_safe_git_readonly_command "$trimmed_command"; }; then
      : # character-allowlisted, single invocation of a verified-safe read-only verb
        # (or git's own dedicated safe grammar) -- provably cannot write anywhere and
        # cannot invoke an attacker-controlled subprocess, allowed unconditionally
        # regardless of whether a protected path is textually present (see header)
    else
      if contains_unsafe_git_invocation "$command_text"; then
        deny "protect-self-amendment: command invokes git in a form other than this hook's verified-safe read-only grammar (plain 'git log/diff/show/blame/status', no flags before or after the verb except '--'), which can spawn an attacker-controlled subprocess via -c/-C/--output and other config-injection surfaces regardless of whether a protected path is textually present -- failing closed"
      fi

      normalized_command="$(normalize_command_for_matching "$command_text")"
      # Compared case-insensitively (see bypass 6 in the header) -- PROTECTED_PATHS
      # entries are already all-lowercase, so only the command side needs folding.
      lower_normalized_command="$(printf '%s' "$normalized_command" | tr '[:upper:]' '[:lower:]')"
      matched_protected=""
      for protected in $PROTECTED_PATHS; do
        case "$lower_normalized_command" in
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
        deny "protect-self-amendment: command contains cd/pushd/source or a bare dot-source invocation, which makes cwd-relative addressing of the 6 self-amendment-protected files impossible to rule out by static substring matching, and the command did not pass as a single safe read-only invocation -- failing closed"
      fi

      if contains_disallowed_escape_char "$command_text"; then
        deny "protect-self-amendment: command contains a backslash or quote character, which can respell or reconstruct a protected path in ways static substring matching cannot see through, and the command did not pass as a single safe read-only invocation -- failing closed"
      fi
    fi
    ;;
  *)
    : # not a tool this hook cares about -- no opinion
    ;;
esac

exit 0
