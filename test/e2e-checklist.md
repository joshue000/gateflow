# End-to-end verification

Run in order, against a real toy Jira project and a scratch personal GitHub repo. Check each box before
trusting the corresponding skill.

## Step 0 — setup (manual, one-time)

- [ ] `brew install gh` && `gh auth login` (personal GitHub account)
- [ ] Personal Atlassian site created (Jira Software Free + Confluence Free)
- [ ] `acli jira auth login --site <personal-site>` — confirm with `acli jira auth status`
- [ ] `./install.sh` run, `ls -la ~/.claude/skills ~/.claude/agents` shows the new symlinks resolving
- [ ] A real toy ticket exists with a `## Test Plan` heading in its description — confirms
      `testPlanSource`'s default assumption, or reveals it needs to change

## SDD -> gateflow-plan

- [ ] `/sdd-new <toy-change>` produces `proposal`/`spec`/`design`/`tasks` per the configured
      `sddPersistence` mode
- [ ] `/gateflow-plan create-from-sdd <toy-change>` creates one Epic + N Stories in the real Jira project
- [ ] Each Story's description contains real spec-scenario content — not invented
- [ ] `/gateflow-plan status <EPIC-KEY>` reflects live done/total

## gateflow-implement

- [ ] Ticket read succeeds; Jira flips to the active-work status
- [ ] Plan doc is produced at `docs/gateflow/plans/<KEY>-plan.md`
- [ ] The run genuinely halts at the approval gate — assert zero code written pre-approval
- [ ] Post-approval, TDD commits land with conventional messages referencing the ticket key
- [ ] (GTF-20) Right after approval, the plan's full content appears as a Jira comment on the ticket —
      not paraphrased, and `git status` shows `docs/gateflow/plans/<KEY>-plan.md` as untracked
- [ ] (GTF-20) Trigger a scope-growth re-plan mid-Phase-4 — the SAME Jira comment updates in place
      (same comment ID, new body) rather than a second comment appearing

## gateflow-review

- [ ] Seed one deliberate code issue and one doc-clarity issue in the same branch
- [ ] Round 1 finds both (the doc one via `tech-writer`) and reports "changes requested"
- [ ] Fix-loop remediates + re-reviews
- [ ] Gate reports **locked only after the 2nd consecutive clean round at the same SHA**
- [ ] A fresh commit after a clean round resets the counter to zero

## gateflow-ship

- [ ] Push succeeds
- [ ] All four PR sections populate — spot-check the Test Plan section is verbatim, not paraphrased
- [ ] Jira flips to the in-review status
- [ ] (GTF-20) Right after the PR opens, the full local review file's content (all rounds) appears as
      a PR comment
- [ ] (GTF-20) The local review file (`docs/gateflow/reviews/<KEY>-review.md`) still exists on disk
      afterward — untouched, not deleted
- [ ] (GTF-20) The local plan file (`docs/gateflow/plans/<KEY>-plan.md`) is gone from disk afterward
- [ ] (GTF-20) Neither file shows up in `git status` at any point in this whole flow — confirm
      `gateflow-init`'s `.gitignore` (or this repo's own, if dogfooding) actually excludes both paths

## gateflow-docs

- [ ] Ask it to draft a README section for a real piece of shipped code
- [ ] Confirm it reads the actual code rather than inventing behavior
- [ ] Ask it to do an sdd-archive-shaped task — confirm it redirects instead of duplicating

## Negative / degrade paths

- [ ] `/gateflow-ship` with Gate 1 deliberately left open — must demand the full
      restated-findings-plus-reason override, never proceed silently
- [ ] `acli jira auth switch` back to a different (e.g. work) site, then invoke any gateflow Jira op —
      `ensure-account` must fail closed with a clear message
- [ ] Break one candidate status name in `.gateflow/config.json` — the manual-fallback command must
      print, the skill must not crash
