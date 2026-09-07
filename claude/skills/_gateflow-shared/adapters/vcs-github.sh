#!/usr/bin/env bash
# VCS adapter — GitHub backend. Contract: ../vcs-adapter-contract.md
# Every op prints one JSON object to stdout on success, exits non-zero with a
# one-line error on stderr on failure. Never touches auth directly — `gh`
# owns its own credential store.
set -euo pipefail

die() { echo "vcs-github: $1" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "gh CLI not found — install with 'brew install gh' then 'gh auth login'"

op="${1:-}"; shift || true

case "$op" in
  current-user)
    login=$(gh api user --jq .login) || die "gh api user failed — run 'gh auth login'"
    printf '{"login":"%s"}\n' "$login"
    ;;

  default-branch)
    branch=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name) || die "gh repo view failed — not a GitHub repo, or not authenticated"
    printf '{"branch":"%s"}\n' "$branch"
    ;;

  open-pr)
    base="" head="" title="" body_file="" reviewers=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --base) base="$2"; shift 2 ;;
        --head) head="$2"; shift 2 ;;
        --title) title="$2"; shift 2 ;;
        --body-file) body_file="$2"; shift 2 ;;
        --reviewers) reviewers="$2"; shift 2 ;;
        *) die "open-pr: unknown arg $1" ;;
      esac
    done
    [ -n "$base" ] && [ -n "$head" ] && [ -n "$title" ] && [ -n "$body_file" ] || die "open-pr requires --base --head --title --body-file"
    args=(pr create --base "$base" --head "$head" --title "$title" --body-file "$body_file")
    [ -n "$reviewers" ] && args+=(--reviewer "$reviewers")
    url=$(gh "${args[@]}") || die "gh pr create failed"
    number=$(gh pr view "$head" --json number --jq .number)
    printf '{"number":%s,"url":"%s"}\n' "$number" "$url"
    ;;

  get-pr)
    ref="${1:-}"; [ -n "$ref" ] || die "get-pr requires <branch|number>"
    gh pr view "$ref" --json number,url,author,baseRefName,headRefName,state \
      --jq '{number,url,author:.author.login,base:.baseRefName,head:.headRefName,state}' \
      || die "gh pr view $ref failed — no such PR"
    ;;

  comment-pr)
    number="${1:-}"; shift || true
    body_file=""
    while [ $# -gt 0 ]; do
      case "$1" in --body-file) body_file="$2"; shift 2 ;; *) shift ;; esac
    done
    [ -n "$number" ] && [ -n "$body_file" ] || die "comment-pr requires <number> --body-file"
    gh pr comment "$number" --body-file "$body_file" >/dev/null || die "gh pr comment failed"
    echo '{"ok":true}'
    ;;

  add-reviewers)
    number="${1:-}"; reviewers="${2:-}"
    [ -n "$number" ] && [ -n "$reviewers" ] || die "add-reviewers requires <number> <a,b,...>"
    gh pr edit "$number" --add-reviewer "$reviewers" >/dev/null || die "gh pr edit --add-reviewer failed"
    echo '{"ok":true}'
    ;;

  *)
    die "unknown op '$op' — see vcs-adapter-contract.md"
    ;;
esac
