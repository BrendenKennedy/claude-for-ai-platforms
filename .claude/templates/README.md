# templates — delivery files for the TARGET project

These are not scaffold config — they're starter files for the *project being scaffolded*.
`/bootstrap` (§3d) copies the delivery rows below to their destinations and fills the marked slots
(never-clobber applies). `aws-iam-policy.json` is the exception: the `infra-aws` lane consumes it at
role-setup time — the human reviews and attaches it; nothing copies it automatically.

| Template | Destination in the target | What it is |
|---|---|---|
| `dot-env.example` | `.env.example` | the env vars the entry points read (copy to `.env`, fill in; synced with the resource matrix) |
| `pre-commit-config.yaml` | `.pre-commit-config.yaml` | ruff + nbstripout + gitleaks on human commits (`uvx pre-commit install`) |
| `project-ci.yml` | `.github/workflows/ci.yml` | offline tier in CI: uv sync --frozen → ruff → pytest |
| `aws-iam-policy.json` | (not copied — attached in AWS by the human) | least-privilege starter policy for the `claude-for-ml-platforms` role (`infra-aws` skill) |

## `memory/` — blank stores seeded at install time (not by `/bootstrap`)
`memory/roadmap.md` and `memory/scaffold-journal.md` are the **empty** versions `install.sh` drops
into a fresh project's `.claude/memory/` (never-clobber applies). This repo's *live* roadmap and
journal carry its own dev history and are deliberately **excluded** from shipping — a new project
must start with empty stores, not the scaffold-maker's backlog. Dated session notes are excluded the
same way (only `sessions/README.md` + `_template.md` ship). Keep these blanks' structure in sync with
the live files' headers when the store format changes.
