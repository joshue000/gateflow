# `.gateflow/config.json` — field reference

Lives at the **consumer project's** repo root (not in the gateflow tool repo). Every gateflow skill
reads it first and fails with a specific missing-field error — never guesses a backend.

| Field | Required | Meaning |
|---|---|---|
| `version` | yes | Schema version, currently `1` |
| `vcs.backend` | yes | `"github"` (MVP — only backend implemented) |
| `vcs.settings.owner` / `.repo` | yes | GitHub owner/repo |
| `vcs.settings.defaultBaseBranch` | no | Default `"main"` |
| `planning.backend` | yes | `"jira"` (MVP — only backend implemented) |
| `planning.settings.site` | yes | e.g. `yoursite.atlassian.net` |
| `planning.settings.projectKey` | yes | Jira project key tickets are created under |
| `planning.settings.testPlanSource` | no | Where scenario text lives on a ticket. Default assumes a `## Test Plan` heading in the Description — confirm once against your real Jira Free tier and adjust if it's actually a custom field |
| `sddPersistence` | yes if using `gateflow-plan` | `engram \| openspec \| hybrid` — must match what `/sdd-init` chose for this project. Start with `openspec` (real files, git-tracked, cheap to re-read) — `hybrid`'s cross-session recall costs double reads/writes per SDD op and isn't worth it until you actually feel the pain of re-reading files. Nothing is lost switching later |
| `contentLanguage` | no | Default `"en"`. Language for END-USER-facing content only: Jira ticket text, `proposal.md`/`spec.md`/`tasks.md` (verbatim into tickets, no translation step), `gateflow-docs` product docs. Does NOT affect code/comments/commits/config keys/`design.md` — those are always English, every project, no exception. Set this explicitly the moment a project's audience doesn't read English |
| `peRoster.fallback` | yes | Agent used when no `pathRules` entry matches a changed file (`"pe-general"`) |
| `peRoster.pathRules` | yes | Ordered `{pattern, agent}` list — first match wins |
| `reviewers` | no | Plain GitHub usernames, default `[]`. Non-empty → `gateflow-ship` passes them to `open-pr` automatically; empty → no-op, nothing to configure separately |
| `jiraStatusCandidates.activeWork` / `.inReview` / `.done` | yes | Ordered candidate status names per semantic target — see `planning-adapter-contract.md`'s status walk. **Never assume a language** — verify against a real ticket on your actual site (`acli jira workitem create` a throwaway one and check `status.name`). A renamed/recreated project can silently flip this; don't trust an old check |
| `tierClassifier.*` | no | Thresholds for `tier-classifier.md`'s deterministic floor; sane defaults apply if omitted |

## Example

```jsonc
{
  "version": 1,
  "vcs": { "backend": "github", "settings": { "owner": "you", "repo": "my-app" } },
  "planning": {
    "backend": "jira",
    "settings": { "site": "you.atlassian.net", "projectKey": "GATE" }
  },
  "sddPersistence": "openspec",
  "contentLanguage": "es",
  "peRoster": {
    "fallback": "pe-general",
    "pathRules": [
      { "pattern": "apps/api/**", "agent": "pe-typescript" },
      { "pattern": "apps/*-ui/**", "agent": "pe-react" },
      { "pattern": "**/*.ts", "agent": "pe-typescript" },
      { "pattern": "**/*.tsx", "agent": "pe-react" }
    ]
  },
  "reviewers": [],
  "jiraStatusCandidates": {
    "activeWork": ["In Progress"],
    "inReview": ["In Review"],
    "done": ["Done"]
  }
}
```
