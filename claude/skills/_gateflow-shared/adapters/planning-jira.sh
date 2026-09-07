#!/usr/bin/env bash
# Planning adapter — Jira backend. Contract: ../planning-adapter-contract.md
# Every op prints one JSON object to stdout on success, exits non-zero with a
# one-line error on stderr on failure. ensure-account is fail-closed: acli has
# ONE global active account, so every other op calls it first.
set -euo pipefail

die() { echo "planning-jira: $1" >&2; exit 1; }

command -v acli >/dev/null 2>&1 || die "acli not found — install the Atlassian CLI"
command -v jq >/dev/null 2>&1 || die "jq not found — brew install jq"

CONFIG=".gateflow/config.json"
[ -f "$CONFIG" ] || die "no $CONFIG in the current project — see config-schema.md"

expected_site=$(jq -r '.planning.settings.site' "$CONFIG")

ensure_account() {
  local status active_site
  status=$(acli jira auth status 2>&1) || die "acli jira auth status failed — run 'acli jira auth login --site $expected_site'"
  active_site=$(echo "$status" | awk -F': ' '/^ *Site:/{print $2}')
  [ "$active_site" = "$expected_site" ] || die "acli is authenticated to '$active_site', this project needs '$expected_site' — run 'acli jira auth switch --site $expected_site' first (never auto-switched, see planning-adapter-contract.md)"
}

op="${1:-}"; shift || true
[ "$op" = "ensure-account" ] || ensure_account

case "$op" in
  ensure-account)
    ensure_account
    echo '{"ok":true}'
    ;;

  get-ticket)
    key="${1:-}"; [ -n "$key" ] || die "get-ticket requires <KEY>"
    # Field paths (fields.status.name / .statusCategory.key) follow the standard
    # Jira Cloud REST shape — confirm against a real ticket during Step 0 setup.
    acli jira workitem view "$key" --fields "summary,description,status" --json \
      | jq '{key: .key, summary: .fields.summary, description: .fields.description, statusCategory: .fields.status.statusCategory.key, status: .fields.status.name}' \
      || die "acli jira workitem view $key failed — not found, or wrong account (run ensure-account)"
    ;;

  transition-to)
    key="${1:-}"; target="${2:-}"
    [ -n "$key" ] && [ -n "$target" ] || die "transition-to requires <KEY> <semanticTarget>"

    category=$(acli jira workitem view "$key" --fields "status" --json | jq -r '.fields.status.statusCategory.key')
    case "$target" in
      activeWork|inReview) want_category="indeterminate" ;;
      done) want_category="done" ;;
      *) die "transition-to: unknown semantic target '$target' — expected activeWork|inReview|done" ;;
    esac

    if [ "$category" = "$want_category" ] || { [ "$want_category" = "indeterminate" ] && [ "$category" = "done" ]; }; then
      echo '{"status":"already-there"}'
      exit 0
    fi

    mapfile -t candidates < <(jq -r ".jiraStatusCandidates.${target}[]" "$CONFIG")
    [ "${#candidates[@]}" -gt 0 ] || die "no jiraStatusCandidates.$target configured in $CONFIG"

    for name in "${candidates[@]}"; do
      if acli jira workitem transition --key "$key" --status "$name" --yes >/dev/null 2>&1; then
        printf '{"status":"%s"}\n' "$name"
        exit 0
      fi
    done

    echo "planning-jira: could not transition $key to '$target' — none of [${candidates[*]}] were reachable." >&2
    echo "  Manual fallback: acli jira workitem transition --key $key --status \"${candidates[0]}\" --yes --web" >&2
    echo '{"status":"manual-fallback-required"}'
    ;;

  add-comment)
    key="${1:-}"; shift || true
    body_file=""
    while [ $# -gt 0 ]; do case "$1" in --body-file) body_file="$2"; shift 2 ;; *) shift ;; esac; done
    [ -n "$key" ] && [ -n "$body_file" ] || die "add-comment requires <KEY> --body-file"
    acli jira workitem comment create --key "$key" --body-file "$body_file" >/dev/null || die "acli comment create failed"
    echo '{"ok":true}'
    ;;

  create-ticket)
    type="" summary="" desc_file="" parent=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --type) type="$2"; shift 2 ;;
        --summary) summary="$2"; shift 2 ;;
        --description-file) desc_file="$2"; shift 2 ;;
        --parent) parent="$2"; shift 2 ;;
        *) die "create-ticket: unknown arg $1" ;;
      esac
    done
    [ -n "$type" ] && [ -n "$summary" ] && [ -n "$desc_file" ] || die "create-ticket requires --type --summary --description-file"
    project=$(jq -r '.planning.settings.projectKey' "$CONFIG")
    args=(jira workitem create --project "$project" --type "$type" --summary "$summary" --description-file "$desc_file" --json)
    [ -n "$parent" ] && args+=(--parent "$parent")
    key=$(acli "${args[@]}" | jq -r '.key') || die "acli workitem create failed"
    printf '{"key":"%s"}\n' "$key"
    ;;

  get-children-status)
    epic="${1:-}"; [ -n "$epic" ] || die "get-children-status requires <EPIC-KEY>"
    rows=$(acli jira workitem search --jql "parent = $epic" --fields "summary,status" --json) || die "acli search failed for parent = $epic"
    echo "$rows" | jq '{
      total: (.workItems | length),
      done: [.workItems[] | select(.fields.status.statusCategory.key == "done")] | length,
      children: [.workItems[] | {key, summary: .fields.summary, status: .fields.status.name}]
    }'
    ;;

  *)
    die "unknown op '$op' — see planning-adapter-contract.md"
    ;;
esac
