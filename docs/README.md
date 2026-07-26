# docs/

Documentation for the scaffold itself. **None of this ships into an installed project** —
`install.sh` copies `.claude/`, `CLAUDE.md`, and `PROCESS.md` only, so this directory is the manual
you come back to rather than one you carry around.

| File | What it's for | Who reads it |
|---|---|---|
| [`TUTORIAL.md`](TUTORIAL.md) | First project, hands-on: install → `/setup` → pick your family | Anyone starting out |
| [`tutorial-platform.md`](tutorial-platform.md) | The Platform path — manifests, RAG tenancy, `/redteam`, `/slo`, `/compliance` | Platform family |
| [`tutorial-model.md`](tutorial-model.md) | The Model path — splits, the signal screen, leakage tests, baselines, model cards | Model family |
| [`REFERENCE.md`](REFERENCE.md) | Every skill, command, agent, and hook, one line each. **Generated** — edit the frontmatter, never this file | Looking something up |

Not here, and deliberately: [`../README.md`](../README.md) (what this is and whether you want it),
[`../PROCESS.md`](../PROCESS.md) (the phase framework — that one *does* ship),
[`../CONTRIBUTING.md`](../CONTRIBUTING.md) (extending the scaffold), and
[`../.claude/memory/policy/`](../.claude/memory/policy/) (the canon).

`check-scaffold.sh` asserts every file in this directory appears in the table above — an
undocumented doc is one nobody finds.
