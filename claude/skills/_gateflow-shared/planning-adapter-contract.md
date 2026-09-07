# Planning adapter contract

Every op is invoked as `bash _gateflow-shared/adapters/planning-<backend>.sh <op> [args...]`, prints a
single JSON object to stdout on success, exits non-zero with a one-line error on failure.

| Op | Args | Returns | Purpose |
|---|---|---|---|
| `ensure-account` | `<expectedSite>` | `{"ok": true}` | **Mandatory first call in every other op.** Fails closed if the active account isn't the expected one — see below |
| `get-ticket` | `<KEY>` | `{"key","summary","description","statusCategory"}` | Full ticket read |
| `transition-to` | `<KEY> <semanticTarget>` | `{"status": "..."}` or a printed manual fallback | State-machine walk — see below |
| `add-comment` | `<KEY> --body-file F` | `{"ok": true}` | Leave a trace (branch/PR link) |
| `create-ticket` | `--type Epic\|Story --summary S --description-file F [--parent KEY]` | `{"key": "..."}` | Used only by `gateflow-plan` |
| `get-children-status` | `<EPIC-KEY>` | `{"done": N, "total": M, "children": [...]}` | Epic progress rollup, used only by `gateflow-plan status` |

## `ensure-account` — why every op depends on it

A single Claude Code account can have both work and personal ticket-tracker credentials active at
different times, with no per-command way to scope one call to one account. **Fail closed, never
auto-switch**: if the active account isn't the one this project's config expects, refuse with a clear
message rather than risk operating against the wrong tracker. The cost is a manual account switch
before/after a gateflow session — accept it, it's cheaper than cross-contamination.

## The status-transition walk — never hardcode status names

Ticket-tracker workflows are project-configurable; two projects on the same tool can use completely
different status names for "in progress." So:

1. Read the ticket's *category* (trackers that support it standardize a small fixed set — e.g. new /
   in-progress / done — regardless of the project's custom status names). Short-circuit immediately if
   already at or past the target category.
2. Otherwise, walk a **configured** candidate-name list for that semantic target, one attempt at a time,
   letting the tracker's own validation reject an unreachable name.
3. Stop at the first success, or after the candidate list is exhausted.
4. On total failure: print the exact manual command plus a web link, and continue — **never block the
   calling skill** on a transition failure.

## Concrete backend: Jira (`adapters/planning-jira.sh`)

Implemented via `acli` (already installed). Auth is `acli`'s own global active-account model —
`ensure-account` parses `acli jira auth status`'s `Site:` line and compares it to config.

| Op | `acli` mapping |
|---|---|
| `ensure-account` | parse `acli jira auth status` |
| `get-ticket` | `acli jira workitem view <KEY> --fields "summary,description,status,statusCategory" --json` |
| `transition-to` | repeated `acli jira workitem transition --key <KEY> --status "<candidate>" --yes`, short-circuited by `statusCategory.key` (Jira's standardized `new`/`indeterminate`/`done`) |
| `add-comment` | `acli jira workitem comment create --key <KEY> --body-file F` |
| `create-ticket` | `acli jira workitem create --project P --type T --summary S --description-file F [--parent KEY]` |
| `get-children-status` | `acli jira workitem search --jql 'parent = <EPIC-KEY>' --fields "summary,status,statusCategory" --json`, rolled up client-side |

## Adding a second backend

New file `adapters/planning-<name>.sh` implementing the same six ops. Flip
`.gateflow/config.json`'s `planning.backend` — no skill changes.
