# Universal engineering principles

Not gateflow-specific and not stack-specific — the baseline every codebase benefits from regardless of
language or domain. `gateflow-init` offers this catalog **only when it can't confirm the user's global
Claude Code config already covers it** (see the detection rule in `gateflow-init/SKILL.md`) — for a
config that already has these (like this repo's own author's), injecting them again would be the same
duplicate-source-of-truth problem `gateflow` avoids everywhere else. This exists so the baseline is
still transmitted to whoever DOESN'T already have it — a fresh machine, a different user, gateflow used
by someone else entirely.

Offered as one block, not item-by-item like `claude-md-suggestions.md` — these aren't optional stylistic
picks, they're the floor.

---

### SOLID (object-oriented / typed codebases)

Single responsibility, open for extension, substitutable interfaces, small focused contracts over one
god-interface, depend on abstractions not concretions. Apply where the codebase's paradigm makes it
meaningful — don't force it onto plain functional/procedural code that doesn't need it.

### DRY — eliminate duplication, don't chase it prematurely

Real, repeated logic gets extracted once its repetition causes an actual maintenance cost (a bug fixed
in one copy and not the other). Two similar-looking blocks that happen to coincide today aren't
automatically duplication — extracting too early creates the wrong abstraction, which costs more to
undo than the duplication would have.

### YAGNI — build for the requirement in front of you

Don't add configurability, abstraction layers, or generality for a need that's hypothetical. A feature
built for "might need this later" is code someone has to maintain today for a benefit that may never
arrive.

### KISS — the simplest solution that's actually correct

Prefer the boring, obvious approach over the clever one. Clever code is a tax paid by every future
reader, including you in six months.

### Testing pyramid

Unit tests are the majority — fast, isolated, one behavior per test. Integration tests cover real
boundaries (DB, external APIs) that mocks would hide bugs in. End-to-end tests are the fewest — reserved
for critical user-facing paths, because they're slow and brittle. A test suite inverted the other way
(mostly E2E, few units) is slow to run and slow to tell you what actually broke.

### Tests are the safety net, not a formality

Never delete or weaken a test to make code pass — if a test fails, the code is wrong, or the test was
already wrong (and that's a distinct, deliberate finding, not an assumption). Add a test whenever new
logic is introduced, not after the fact "if there's time."

### Refactor and feature work don't mix in one change

Changing structure without changing behavior is refactoring; it needs passing tests before AND after,
and nothing else riding along in the same change. If a change *feels* like both, split it.
