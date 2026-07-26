# templates — delivery files for the TARGET project

These are not scaffold config — they're starter files for the *project being scaffolded*.
`/bootstrap` copies them to their destinations and fills the marked slots (never-clobber applies):
§3d for the rows every project gets, §3h for the platform lanes. A few are consumed on demand by a
skill or a canon rule instead — those are called out below.

`check-scaffold.sh` check 14 walks this directory with `find` and asserts every file is named
somewhere in this README — including anything added under a new subdirectory. Where two files share
a basename (both `kustomization.yaml`s), it requires the parent directory too, so one row can't
satisfy both. An undocumented template is one `/bootstrap` will never reach for.

### Every project (`/bootstrap` §3d)

| Template | Destination in the target | What it is |
|---|---|---|
| `dot-env.example` | `.env.example` | the env vars the entry points read (copy to `.env`, fill in; synced with the resource matrix) |
| `pre-commit-config.yaml` | `.pre-commit-config.yaml` | ruff + nbstripout + gitleaks on human commits (`uvx pre-commit install`) |
| `project-ci.yml` | `.github/workflows/ci.yml` | offline tier in CI: uv sync --frozen → ruff → pytest |
| `aws-iam-policy.json` | (not copied — attached in AWS by the human) | least-privilege starter policy for the `claude-for-ai-platforms` role (`infra-aws` skill) |

### Platform lanes (`/bootstrap` §3h)

Hardened on the first draft — Pod Security `restricted`, digest-pinned, resource-limited,
default-deny networking, least-privilege RBAC. The guard hooks block the diff that removes any of it,
so these are **load-bearing exemplars**, not just starting points: `check-scaffold.sh` asserts the
`k8s/` baseline passes the `policies/` shipped beside it, and that those policies reject their own
bad fixtures.

`/bootstrap` §3h instantiates these into `deploy/`, `policies/`, `observability/`, and
`.github/workflows/` — it splits and renames as that section specifies (the combined
`namespace-and-network.yaml` becomes separate `namespace.yaml` + `networkpolicy-default-deny.yaml`,
and so on), so the destinations below are the tree, not exact filenames.

| Template | Instantiated into | What it is |
|---|---|---|
| `k8s/base/deployment.yaml` | `deploy/base/` | the hardened Deployment — the shape `guard-k8s-manifests.py` enforces |
| `k8s/base/kustomization.yaml` | `deploy/base/` | ties the base together |
| `k8s/base/namespace-and-network.yaml` | `deploy/base/` | namespace (PSS `restricted` labels) + default-deny NetworkPolicy |
| `k8s/base/rbac-and-service.yaml` | `deploy/base/` | least-privilege ServiceAccount/Role + Service |
| `k8s/overlays/prod/kustomization.yaml` | `deploy/overlays/prod/` | the prod overlay (image digest, replicas, PDB, resource bumps) |
| `policies/kyverno-baseline.yaml` | `policies/` | admission policy — the cluster-side enforcement of the platform canon (`policy-as-code`) |
| `policies/conftest/platform.rego` | `policies/` | the same rules for CI, over rendered manifests and Terraform plans |
| `policies/conftest/platform_test.rego` | `policies/` | the bad fixtures those rules must reject — `conftest verify` discovers `*_test.rego` by convention |
| `security-ci.yml` | `.github/workflows/security.yml` | the gate ladder: gitleaks, Trivy, Syft SBOM, kubeconform, conftest, cosign |
| `otel-collector.yaml` | `observability/` | OTel collector config, redaction processor wired, incl. the LLM/agent spans nothing else emits |

Three more are consumed by a skill or canon rule on demand rather than copied by `/bootstrap`:

| Template | Consumed by | What it is |
|---|---|---|
| `k8s-rbac-agent.yaml` | `policy/security.md` `S9` | the RBAC an agent workload gets in-cluster — `agent-authority.md`'s grant in Kubernetes terms |
| `runbook.md` | `reliability.md` `R6` · `workflow-orchestration` | the per-alert (and per-DAG) runbook: what it does, what breaks it, whether it's safe to re-run |
| `mcp-json.example` | `mcp-security` · `guard-agent-config.py` | pinned MCP server wiring — the guard blocks the unpinned `npx -y @vendor/srv` form and asks on the pinned one |

## `memory/` — blank stores seeded at install time (not by `/bootstrap`)
`memory/roadmap.md` and `memory/scaffold-journal.md` are the **empty** versions `install.sh` drops
into a fresh project's `.claude/memory/` (never-clobber applies). This repo's *live* roadmap and
journal carry its own dev history and are deliberately **excluded** from shipping — a new project
must start with empty stores, not the scaffold-maker's backlog. Dated session notes are excluded the
same way (only `sessions/README.md` + `_template.md` ship). Keep these blanks' structure in sync with
the live files' headers when the store format changes.
