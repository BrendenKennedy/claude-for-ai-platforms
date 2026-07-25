# OWASP Top 10 CI/CD Security Risks — the pipeline threat vocabulary

**Identity:** OWASP · 2022 · https://owasp.org/www-project-top-10-ci-cd-security-risks/
**Verified:** 2026-07-25. Still the current edition — **no revision published since 2022**. The
risk set has aged well; the tooling examples in the project's write-ups have not.
**Canon citing it:** `supply-chain.md` (C1, C3, C6) · `identity-and-access.md` (I3, I5)

> The list that treats the build pipeline as what it is: a production system with credentials to
> everything, usually less hardened than the application it builds. For an AI platform this matters
> twice over, because the pipeline also touches model weights and training data.

## The controls

| ID | Title | In one line |
|---|---|---|
| CICD-SEC-1 | Insufficient Flow Control Mechanisms | Code or artifacts reach production without required review or approval |
| CICD-SEC-2 | Inadequate Identity and Access Management | Too many identities, over-permissioned, poorly deprovisioned |
| CICD-SEC-3 | Dependency Chain Abuse | Dependency confusion, typosquatting, and substitution attacks |
| CICD-SEC-4 | Poisoned Pipeline Execution (PPE) | Attacker-controlled repository content executes in the build environment |
| CICD-SEC-5 | Insufficient PBAC (Pipeline-Based Access Controls) | Pipeline jobs can reach far more than the job needs |
| CICD-SEC-6 | Insufficient Credential Hygiene | Long-lived secrets, over-scoped tokens, credentials in logs or history |
| CICD-SEC-7 | Insecure System Configuration | Weak configuration of the CI/CD systems and their hosts |
| CICD-SEC-8 | Ungoverned Usage of 3rd Party Services | Unreviewed marketplace actions and integrations with repo access |
| CICD-SEC-9 | Improper Artifact Integrity Validation | Artifacts move through the pipeline without verification |
| CICD-SEC-10 | Insufficient Logging and Visibility | Pipeline activity is not recorded well enough to detect or investigate abuse |

## What we adopt

- **CICD-SEC-4 (PPE) as the reason for the pull-request trigger rules** in `secure-cicd`: workflows
  triggered by untrusted forks never receive secrets, and never run repository-supplied build scripts
  with elevated identity. This is the highest-impact, most commonly-missed control on the list.
- **CICD-SEC-6 → no long-lived cloud credentials in CI** (canon `C6`, `I3`). OIDC federation from the
  CI platform to the cloud provider replaces stored keys entirely; this is also what makes SLSA L2
  keyless signing work, so one change buys two controls.
- **CICD-SEC-8 → third-party actions pinned by commit SHA, not tag** (`C1`). A tag is mutable; an
  action referenced by tag is an unpinned dependency with write access to your build.
- **CICD-SEC-9 → verify artifacts between stages** (`C3`), which is the same cosign verification the
  admission controller does, applied earlier.
- **CICD-SEC-2 and -5 → the pipeline's identity is least-privilege and scoped per job** (`I3`, `I5`).
- **CICD-SEC-10 → pipeline logs are telemetry** and go to the same place application telemetry does
  (`observability`).

## What we leave

- **Its platform-specific hardening guides** (Jenkins, GitLab, and so on). `secure-cicd` carries the
  current how-to for the platform in use; canon states the invariant.
- **CICD-SEC-7 as canon.** Securing the CI *system itself* is the platform team's job on
  self-hosted runners, and the vendor's on hosted ones; we record which applies in
  `control-coverage.md` rather than assert a rule a project often cannot implement.
- **Its 2022 tooling examples.** Dated; superseded by what `secure-cicd` pins.

## How it lands here

| Framework ID | Canon rule | Mechanism |
|---|---|---|
| CICD-SEC-1 | — (process) | branch protection · required review · `/gate` |
| CICD-SEC-2, -5 | `I3`, `I5`, `C6` | `authn-authz` · per-job scoped tokens |
| CICD-SEC-3 | `C1` | `env-uv` lockfile · `guard-pyproject.py` · registry pinning |
| CICD-SEC-4 (PPE) | `C6` | `secure-cicd` (trigger rules, no secrets on fork PRs) |
| CICD-SEC-6 | `C6`, `I3`, `I9` | OIDC federation · `guard-secrets.py` · gitleaks |
| CICD-SEC-8 | `C1`, `C8` | actions pinned by SHA · `mcp-security` for agent-side equivalents |
| CICD-SEC-9 | `C3`, `C4` | cosign verify between stages · SLSA provenance |
| CICD-SEC-10 | `AI12`, `R6` | `observability` (pipeline telemetry) |

## Gotcha

**The pipeline is usually the most over-privileged identity in the system** — it can write to
production, read every secret, and push images — and it is the one nobody threat-models. When
`/threat-model` runs, CI is an actor with its own trust boundary, not infrastructure in the
background. An agent that can trigger a pipeline inherits everything the pipeline can do, which is
where CICD-SEC-5 and canon `AI2` (least agency) meet.
