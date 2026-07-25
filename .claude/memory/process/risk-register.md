# Risk register

> `PROCESS.md` §3.2 / Template T4 — the top 3–7 live risks, reviewed at every `/gate` review. New
> risks discovered mid-phase get logged here immediately, not remembered later. Retired risks move
> to the bottom table (they're the retro's raw material), never deleted.

## Live

| # | Risk | Source | Likelihood | Impact | Mitigation | Owner | Review by | Status |
|---|------|--------|------------|--------|------------|-------|-----------|--------|
| 1 | **Allow-list scoping may be bypassable via a compound command.** Every entry in `settings.json` `permissions.allow` is scoped to a non-mutating subcommand, but it is unverified whether Claude Code splits a compound command (`<allowed tool> && <arbitrary command>`) before prefix-matching. If it does not split, the scoping is necessary but not sufficient and the allow list grants shell. | Increment 4 review of `settings.json`; recorded verbatim in the file's `_allow_scoping_comment` | Unknown | High — an allow-listed prefix would grant arbitrary command execution with no prompt | Scoping done (removes the *direct* paths); `validate-bash.sh` deny patterns still fire on the dangerous second command since it scans the whole string. **Needs a live permission-system test to close.** Ships as a stated unknown rather than an implied guarantee. | Scaffold maintainer | Next `/gate` | Open — unverified |
| 2 | **`kustomize build` / `kubectl kustomize` accept a remote URL and can exec a plugin under explicit alpha flags**, so they are allow-listed while not being strictly read-only. | Increment 4 review | Low — the exec path needs deliberate alpha flags | Medium — arbitrary execution during a render step | **Accepted, not mitigated.** Rendering overlays is the core platform workflow and removing it would make the allow list useless for the thing it exists for. The `_allow_scoping_comment` states the residual instead of claiming read-only. | Scaffold maintainer | Next `/gate` | Open — accepted |

## Retired

| # | Risk | Outcome (hit / mitigated / expired) | Date |
|---|------|-------------------------------------|------|
