# CLAUDE.md — index of this repo's `.claude/` config

The map of the Claude configuration here: what lives under `.claude/` and when to reach for it.
Depth deliberately lives in the skills/docs this points to — skills auto-surface by description;
this file is for the always-on conventions and registration. Project details: the skills + `README.md`.

> **Not configured yet?** If `memory/process/phase-state.md` says the project hasn't started, run
> **`/setup`** — it walks the whole one-time sequence in one session. Everything below assumes it ran.
>
> **The rest of the documentation stays upstream** — the README, the tutorials, and `docs/` are not
> installed into a project: <https://github.com/BrendenKennedy/claude-for-ai-platforms>. Two things
> that do ship and are worth knowing: `bash .claude/scripts/check-scaffold.sh` verifies this config
> is internally consistent, and `python3 .claude/scripts/build-reference.py docs/REFERENCE.md`
> generates a component index from *this* project's `skillOverrides`.

> **claude-for-ai-platforms** — one scaffold, two families of work, chosen at `/intake`:
> **build an AI platform securely** (agent and LLM security, Kubernetes, SRE, observability,
> identity, supply chain) or **build a model** (CV · tabular · time-series · LLM fine-tuning).
> Neither is bolted on: the platform family needs the DS fundamentals that eval work rests on, and
> a model that ships eventually needs somewhere to run. Only the five-skill chassis is always-on —
> **both families gate**, so you pay context for the one you picked.
> Archetypes (agent platform · RAG service · inference platform · eval harness · MLOps platform ·
> cv / tabular / time-series / LLM model-building) are lanes, flipped by
> what you're building. One-time setup, in order: **`/intake`** (the "what are we building?"
> interview + the **security-posture interview** → `memory/process/project-definition.md`, then the
> stack → `settings.json` `skillOverrides` + placeholders), then **`/bootstrap`** (builds the
> `deploy/` · `policies/` · `observability/` · `evals/` tree, or the `conf/` + `train.py`/`eval.py`
> tree for a model-building lane). **`/setup`** runs the whole sequence + `/threat-model` + the P1
> `/gate` in one session.

## Always-on conventions
The rules that apply to essentially every change (fuller policy via the `governance` skill →
`.claude/memory/policy/`):
- **Work advances through phase gates** — the project runs on `PROCESS.md` (repo root); no forward
  phase transition without a passed `/gate` review recorded in `memory/process/phase-state.md`.
  The operating loop is the `process` skill. Governs **project work** — one-off ad-hoc analysis
  asks are served directly, no gate ceremony.
- **Security and reliability are a track through every phase, not a review at the end**
  (`PROCESS.md` §3.9): threat model at P3, controls + policy-as-code at P4, a recorded adversarial
  run at P5, SLOs + exercised rollback at P6, telemetry + an incident path at P7.
- **Design so a successful prompt injection is boring.** The question for any agentic design is
  *if an attacker fully controlled the model's output, what could they reach?* Prefer removing a
  capability to constraining it, and constraining it to detecting misuse of it. Filters are the last
  layer, never the boundary (`agent-security`, `policy/ai-security.md`).
- **Least agency by default** — a tool is granted explicitly, per agent, for a reason, and declared
  in `memory/process/agent-authority.md`. Irreversible actions need a human who is shown the
  concrete consequence.
- **A control is a mechanism, not a sentence.** "We validate input" checks no box; a canon rule plus
  a hook, a policy, a test, or a code path does. **"Not evidenced" is an honest status** — an
  overclaimed control stops anyone looking.
- **Hardened is the first draft.** Generated manifests are Pod Security `restricted`, digest-pinned,
  resource-limited, default-deny networked, least-privilege RBAC. The guard hooks block the diff
  that removes any of it.
- **Match the surrounding code** — mirror its structure, naming, and comment density.
- **Reproducibility is non-negotiable** — seed every RNG, pin versions, never let an experiment
  depend on un-recorded state; document any deliberate nondeterminism.
- **Never leak the eval set** — no fitting, tuning, or feature-selection on val/test; splits are
  defined once and respected everywhere (see `datasets` + `data-governance`).
- **Config over constants** — hyperparameters and paths flow through the config system, never
  hardcoded or read from the environment mid-logic.
- **Deps via `uv add`** — never hand-edit `pyproject.toml` (the `guard-pyproject` hook enforces).
- **Don't hand-format** — the ruff hooks own style. Bite: `ruff check --fix` runs after *every*
  Edit/Write, so write an import and its usage in the **same** edit or F401 deletes it between.
- **Terse working output** — status updates and findings, not narration; every reply becomes
  context re-read on all later turns, so brevity compounds. Full prose belongs only in
  deliverables (reports, gate reviews, explanations the user asked for).
- **Finish before handing back** — don't return a half-done task. Before ending a turn: the ask is
  actually satisfied (not "mostly"); code with runtime surface was exercised (`verify` / the
  `testing` ladder), not just written; any decision/risk/scope change was recorded in its one home
  as you went, not deferred. When a coherent unit of work closes with edits or decisions,
  **proactively offer `/wrapup`**. (The `SessionStart` hook handles the mirror at the other end.)

## Skills — `.claude/skills/<name>/SKILL.md`
Auto-surface by description (that text is the entire routing surface — see
`memory/reference/authoring-extensions.md` before adding one). Tiers:
<!-- always-on:start -->
- **Always-on chassis — the only tier that is never gated:** `process` · `governance` · `testing` ·
  `memory` · `wave-planning`. Five skills, both families, every project.
<!-- always-on:end -->
- **Gated** (`/intake` flips via `skillOverrides`; off = zero context cost). **Both wings gate**, so
  a tabular-regression project never pays for the agentic threat surface and an inference platform
  never pays for `eda` and `notebooks`:
  - *security & platform spine:* `agent-security` (the agentic threat surface + the design ladder
    that bounds it) · `threat-modeling` (the artifact) · `observability` (OTel + agent telemetry) ·
    `reliability-sre` (SLOs, resilience, incidents) · `agent-evaluation` (trajectories, judges,
    safety suites). **`agent-security` keys off "is there an LLM or agent in this at all?", not the
    archetype** — on for every platform lane *and* LLM fine-tuning. The security floor does not
    depend on it: the floor is the **hooks** (always on, zero context) plus the **canon**
    (on-demand). See `settings.json` `_security_floor_comment`.
  - *DS core:* `datasets` · `evaluation` · `statistics` (on by default — any project with data
    measures something) · `eda` · `visualization` · `notebooks` · `reporting`
  - *platform:* `kubernetes` · `policy-as-code` · `authn-authz` · `secrets-management` ·
    `supply-chain-security` · `secure-cicd` · `iac-terraform` · `gitops` · `containers` ·
    `serving` · `monitoring`
  - *cloud:* `infra-aws` · `infra-gcp` · `infra-azure` · `local-stack` — each cloud skill carries
    the same six sections (identity + workload identity · managed k8s · serverless · managed DBs ·
    native CI/CD · AI services) so they're diffable when moving between them
  - *data & workflow:* `vector-stores` · `graph-stores` · `relational-stores` ·
    `caching-and-queues` · `object-and-lakehouse` · `workflow-orchestration`
  - *AI security:* `guardrails` · `mcp-security` · `llm-red-teaming`
  - *tools:* `env-uv` (on) · `tracking-mlflow` (on) · `config-hydra` (on) · `data-dvc` ·
    `tracking-wandb` · `config-omegaconf` · `hpo-optuna`
  - *model-building lanes:* `training` · `annotation` · `pipelines` · `tabular` · `timeseries` ·
    `wrangling` · `sql` · `data-acquisition` · `finetune-unsloth` · `llm-eval`

  Tool skills carry a `**Pinned:**` version line — `/skill-update` keeps the facts true for the
  version the project actually runs.

## Subagents — `.claude/agents/<name>.md`
`security-reviewer` (diff/config review, AI-platform lens, findings cite canon rules) ·
`threat-modeler` (read-only; builds the threat model) · `platform-engineer` (manifests, IaC, CI,
telemetry — hardened on the first draft) · `sre-analyst` (read-only; SLOs, incident triage,
postmortems) · `red-teamer` (adversarial suites against **this project only**) ·
`compliance-mapper` (read-only; control coverage vs the crosswalk) · `code-reviewer` (correctness,
ML lens) · `software-architect` (read-only planning) · `data-engineer` (data layer) ·
`ml-engineer` (models + train/eval loops) · `eval-analyst` (read-only error/trajectory analysis)

## Commands — `.claude/commands/<name>.md`
| Command | Does |
|---|---|
| `/setup` | full one-time setup: git preflight → `/intake` → `/bootstrap` → `/threat-model` → `/gate` (P1) → `/wrapup`, checkpoint commit per stage |
| `/intake` | one-time: project-definition + **security-posture** interview, then stack → `skillOverrides` + placeholders |
| `/bootstrap` | one-time, after `/intake`: generate + prove the project skeleton (platform: `deploy/` `policies/` `observability/` `evals/`; model-building: `conf/` + entry points) |
| `/threat-model` | build or refresh `memory/process/threat-model.md` — trust boundaries, STRIDE + ASI/ATLAS, every threat driven to a decision |
| `/sec-review` | security review of the current diff (dispatches `security-reviewer`); the counterpart to `/review` |
| `/harden` | audit an existing surface (manifests, IaC, agent tools, pipeline) against canon → prioritised remediation |
| `/redteam` | adversarial campaign against this project's own agent system; findings become regression cases |
| `/slo` | define or review SLIs/SLOs/error budgets → `memory/process/slo-register.md` |
| `/postmortem` | blameless postmortem from records → `memory/incidents/` |
| `/compliance` | control-coverage + gap report against the crosswalk → `memory/process/control-coverage.md` |
| `/gate` | phase-gate review per `PROCESS.md` §3.8 + the §3.9 security track — evidence per item, records pass/debt, refuses to advance unchecked |
| `/review` | review the current `git diff` for bugs + cleanups |
| `/report` | draft a deliverable assembled from the repo's records — claims cite run ids; evidence gaps flagged, never filled |
| `/skill-update` | sync a tool skill to the installed version — pin-vs-lock drift check, changelog research, fact updates, pin bump |
| `/upgrade` | upgrade an installed project's scaffold to a newer release — three-way file plan; state and profiles never clobbered |
| `/wrapup` | close out the session — record note (incl. phase + gate debt + scaffold check) → (commit) → land |
| `/scaffold-retro` | assess the scaffold itself — cluster `memory/scaffold-journal.md` into themes, promote worth-acting-on ones |

## Hooks — `.claude/hooks/` (wired in `settings.json`)
Guardrails against agent *mistakes*, not a sandbox against an adversary (`policy/security.md` S1).
All fail open; every one has block/allow/**fail-open** cases in `.claude/scripts/check-hooks.py`.

| Hook | Event | Does |
|---|---|---|
| `session-orient.py` | SessionStart (startup·clear) | "where are we" briefing — phase, gate debt, **threat-model age, error-budget attention, expired policy exceptions**, last session, roadmap next |
| `validate-bash.sh` | Pre · Bash | blocks root/home wipes, `.env` + kubeconfig + Secret reads, curl-pipe-to-shell; confirm dialog on destructive ops (recursive deletes, git/dvc discards, `kubectl delete`/`drain`/`exec`, `helm uninstall`, `terraform apply`/`destroy`, argocd/flux delete, vault delete, AWS + cluster RBAC mutation) |
| `guard-pyproject.py` | Pre · Edit/Write | dependency edits go through `uv add`/`uv remove` |
| `guard-notebook-outputs.py` | Pre · Edit/Write | `.ipynb` must commit output-stripped |
| `guard-secrets.py` | Pre · Edit/Write | blocks credential-shaped writes — provider keys, JWTs, kubeconfig material, cloud SA keys |
| `guard-k8s-manifests.py` | Pre · Edit/Write | blocks privileged/host-namespace/`hostPath`/root pods, missing resource limits, `:latest`, wildcard RBAC, Secret literals — honours recorded exceptions |
| `guard-iac.py` | Pre · Edit/Write | blocks public buckets, `0.0.0.0/0` on sensitive ports, wildcard IAM, unencrypted storage, hardcoded credentials |
| `guard-agent-config.py` | Pre · Edit/Write | blocks unpinnable MCP servers; **asks** on server additions, permission widening, granting a subagent write/shell |
| `validate-python.py` | Post · Edit/Write | `ruff format` + `ruff check --fix` on edited `.py` |
| `validate-manifests.py` | Post · Edit/Write | `terraform fmt`; `kubeconform` on manifests. Advisory, never blocks |
| `scan-untrusted-content.py` | Post · WebFetch/Read | annotates injection-shaped fetched/read content — makes S1/AI1 mechanical. Never blocks |
| `run-leakage-tests.sh` | Stop | leakage tests gate session end |
| `run-security-tests.sh` | Stop | policy self-tests, manifest conformance, and the injection regression suite gate session end |

## Memory — `.claude/memory/`
On-demand store, never auto-loaded; read/write process is the `memory` skill.
`sessions/` (dated summaries) · `incidents/` (postmortems, T11) · `reference/` (how-we-do-X notes,
incl. `authoring-extensions.md` — read it before extending `.claude/` — plus
`architecture-skills-vs-agents.md`, `architecture-security-layers.md`, and
`remote-gpu-workflow.md`) · `roadmap.md` (backlog;
doubles as the scope parking lot) · `scaffold-journal.md` (observed quality of the scaffold itself;
harvested by `/scaffold-retro`) ·
**`policy/`** (governance canon, 8 domains with citable rule ids: `security.md` `S#` (the dev loop) ·
`ai-security.md` `AI#` · `platform-security.md` `P#` · `identity-and-access.md` `I#` ·
`supply-chain.md` `C#` · `reliability.md` `R#` · `data-governance.md` `D#` ·
`model-governance.md` `M#`; plus `compliance-crosswalk.md` and **`frameworks/`** — 20 published
standards with versions and verification dates. **Canon cites framework control ids
(`[LLM01]`, `[CIS 5.2]`); the framework text lives only in `frameworks/`.**) ·
`process/` (live `PROCESS.md` state: `project-definition.md`, `phase-state.md`, `risk-register.md`,
`scope-ledger.md`, `decision-log.md`, `resources.md`, **`threat-model.md`** (T9),
**`slo-register.md`** (T10), **`control-coverage.md`** (T12), **`agent-authority.md`** (T13))

## Other config
`settings.json` (permissions + hooks + `skillOverrides` + skill-listing budget) ·
`scripts/` (`check-scaffold.sh` self-consistency, `check-hooks.py` guard behaviour,
`build-reference.py` doc generation) · `templates/` (k8s baseline, Kyverno + conftest policies,
security CI, OTel collector, runbook, `.mcp.json` example, agent RBAC, IAM policy) ·
`.mcp.json` (MCP wiring — not shipped; create at repo root when needed, and read `mcp-security` first)
