# VCS adapter contract

Every op is invoked as `bash _gateflow-shared/adapters/vcs-<backend>.sh <op> [args...]`, prints a single
JSON object to stdout on success, and exits non-zero with a one-line human-readable error on stderr on
failure — never a stack trace, never silent failure. Plain `git` operations (branch, commit, push, log,
diff) are NOT part of this contract — they're already host-agnostic via the `git` CLI itself, and skills
call `git` directly.

| Op | Args | Returns | Purpose |
|---|---|---|---|
| `current-user` | — | `{"login": "..."}` | Identity, used to derive Gate 2 (never chosen manually — see `gate-model.md`) |
| `default-branch` | — | `{"branch": "..."}` | Base branch when config doesn't override it |
| `open-pr` | `--base B --head H --title T --body-file F [--reviewers a,b]` | `{"number": N, "url": "..."}` | Create the PR |
| `get-pr` | `<branch\|number>` | `{"number","url","author","base","head","state"}` | Read back for Gate 2 derivation, drift checks |
| `comment-pr` | `<number> --body-file F` | `{"ok": true}` | Post a review verdict as a PR comment |
| `add-reviewers` | `<number> <a,b,...>` | `{"ok": true}` | Fallback if `open-pr`'s reviewer flag is rejected |

## Failure convention

An op that can't complete (auth, network, not-found) must fail with a **specific** message naming what
was tried — "gh pr view 42: no such PR" not "error". Never retry silently, never fall back to a guess.

## Concrete backend: GitHub (`adapters/vcs-github.sh`)

Implemented via the `gh` CLI (`brew install gh`, then `gh auth login`). Auth lives entirely in `gh`'s own
credential store — this script never touches a token.

| Op | `gh` command |
|---|---|
| `current-user` | `gh api user --jq .login` |
| `default-branch` | `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` |
| `open-pr` | `gh pr create --base B --head H --title T --body-file F [--reviewer a,b]` |
| `get-pr` | `gh pr view <ref> --json number,url,author,baseRefName,headRefName,state` |
| `comment-pr` | `gh pr comment <number> --body-file F` |
| `add-reviewers` | `gh pr edit <number> --add-reviewer a,b` |

## Adding a second backend

New file `adapters/vcs-<name>.sh` implementing the same six ops, same JSON shapes. Flip
`.gateflow/config.json`'s `vcs.backend` — no skill changes.
