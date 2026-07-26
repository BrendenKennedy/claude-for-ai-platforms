---
description: >
  One-time onboarding — the "what are we building?" definition interview (archetype, T1,
  anti-pattern challenge), then the stack interview — write skillOverrides and fill the
  answerable <PLACEHOLDER>s.
disable-model-invocation: true
---

Onboard this scaffold to the user's actual project and stack. This is a **one-time** run: define the
project, interview for the stack, flip the tool-skill profile, resolve the placeholders the answers
determine, then report. Work through the steps in order; don't skip ahead.

## 0. Project definition — "so what are we building?" (before any stack question)

The stack must serve the project, so the project gets defined first. **Load the `process` skill**;
the canon for what a definition contains is `PROCESS.md` P1 + template T1. This step is a
**conversation, not a form**. (Re-run of intake to change stacks? If
`.claude/memory/process/project-definition.md` already exists, skip to step 1 — revisit the
definition only on a genuine pivot, which also means a decision-log entry.)

- **Open question.** "What are we building?" in plain conversation — not AskUserQuestion. Let the
  user talk; follow up until you can state in your own words what is produced, for whom, and what
  decision it changes. Reflect it back and get a "yes, that's it."
- **Ask which family first, then the lane** (AskUserQuestion once you have context). This is *the*
  question the whole scaffold configures itself from — the two families are equal citizens, so do
  not present one as the default:
  - **Are we building a platform, or building a model?** (Or both — a project that trains a model
    *and* ships it is legitimate and gets both blocks on; say so rather than forcing a pick.)
  - **Platform lanes:** **agent platform** (an agentic system with tools and memory) · **RAG
    service** · **inference platform** (serving models at scale) · **eval harness** (measuring
    models/agents) · **MLOps/data platform** (the pipeline substrate).
  - **Model-building lanes:** computer vision · classical DS on structured/tabular data ·
    time-series/forecasting · LLM fine-tuning.
  - Also possible: analytics & reporting · autonomous systems/robotics.

- **Then ask the one question that does not follow from the lane: is there an LLM or an agent in
  this at all?** It decides `agent-security`, and the archetype does not imply it — a "tabular"
  project that calls a model has an agentic surface, and an "inference platform" serving a
  classifier may not. Record the answer in `project-definition.md`; a later `/gate` reads it.

  **Be honest about lane fit, out loud.** The chassis and the `PROCESS.md` phases are
  archetype-agnostic; **everything else is gated, including the DS core and the security spine**, so
  what you set here is what the project gets. Platform lanes get the platform skills plus
  `/bootstrap` deploy/policy/observability/eval skeletons; model-building lanes get the DS core plus
  their own skills and skeletons. Out of lane (autonomous systems, pure analytics): the chassis still
  holds — there is still data discovery, a baseline, and eval — but no lane skills or skeleton back
  it. State exactly what fits and what doesn't, and ask whether to proceed with the gaps recorded —
  never silently pretend covered.
- **Run the security-posture interview** (AskUserQuestion, batched). These answers set the
  enforcement tier, seed the threat model, and decide several `skillOverrides` — they are not
  paperwork:
  - **Data sensitivity** — public / internal / confidential / regulated (PII, PHI, financial).
  - **Tenancy** — single-tenant / multi-tenant. Multi-tenant makes `platform-security.md` `P10` and
    `identity-and-access.md` `I4` load-bearing rather than theoretical.
  - **Exposure** — internal-only / authenticated external / public internet.
  - **Agent autonomy** — read-only / writes to scoped systems / takes irreversible actions. Anything
    past read-only makes `ai-security.md` `AI2`/`AI3` and `agent-authority.md` mandatory.
  - **Human-in-the-loop** — which action classes require an approving human.
  - **Regulatory exposure** — does this touch an EU AI Act Annex III use case (employment,
    education, essential services, law enforcement, biometrics, critical infrastructure), or ship a
    GPAI model? **A "yes" or "unsure" is recorded in the risk register at P1 and needs qualified
    counsel** — classification is a legal determination this scaffold cannot make, and finding out
    at P6 is the expensive path. See `policy/frameworks/eu-ai-act.md`.

  Record the answers in the definition doc under **Security posture**; `/threat-model` starts from
  them.
- **Fill T1 conversationally:** prediction target · consumer & the decision it changes ·
  constraints (deadline, data access, budget, and the **compute math** — est. cost of one training
  run × runs implied, vs. hardware and deadline) · success metric + threshold + the baseline it
  must beat · non-ML benchmark · **kill criteria** · feasibility notes. An unanswerable field is
  recorded as an open question — an honest blank beats an invented answer; the P1 gate will catch it.
- **The challenge pass — the reason this step exists.** Before anything is set in stone, examine
  the plan for anti-patterns: no baseline / straight to the deep model · metric mismatch (accuracy
  on imbalance, no calibration where probabilities are consumed) · leakage baked into the framing
  (inputs not actually available at prediction time) · data assumed rather than verified
  (licensing/ToS, access) · no kill criteria / unfalsifiable goal · scope with no v1 contract.
  Where you're unsure of current best practice — or the archetype is fast-moving (LLM apps, agents)
  — **WebSearch before opining**; don't challenge from stale memory. Then push back specifically:
  *"are you sure about X? The typical approach is Y because Z — here's what I found."* The user
  decides; your job is making sure it's a decision, not a default. Every challenge that changes (or
  deliberately doesn't change) the plan gets a line in `.claude/memory/process/decision-log.md`,
  alternatives included.
- **Write the definition doc** at `.claude/memory/process/project-definition.md`, sections:
  **Archetype & lane fit** (incl. skill/skeleton gaps) · **Problem definition (T1)** ·
  **Challenged decisions** (one line each, pointing at the decision log) · **Setup implications**
  (suggested pre-answers for the stack interview below and for `/bootstrap`'s interview — task
  type, dataset slug, backbone/method family) · **Open questions**. Seed the v1 contract into
  `scope-ledger.md` and framing-level risks into `risk-register.md` — they were just discussed;
  don't make the user restate them at the first `/gate`.

## 1. Stack interview (use the **AskUserQuestion** tool)

Ask these — one question each, with the defaults marked. Batch them into a single AskUserQuestion call
where the tool allows. The definition doc's **Setup implications** may already answer some:
present those as the pre-selected option and confirm, don't re-ask blind:

- **Experiment tracker** — MLflow *(default)* / Weights & Biases / none.
- **Config system** — Hydra *(default)* / plain OmegaConf (backed by `config-omegaconf`; warn that
  `/bootstrap`'s skeleton is Hydra-shaped, so its entry points need adapting to that skill's
  pattern) / argparse (no skill backs argparse; config-over-constants still applies).
- **Data versioning** — DVC *(default)* / git-lfs / none.
- **Baseline confirm — MANDATORY, ask it; never infer it from the plan doc.** This is the one
  question in this interview you must not skip or pre-answer from prose — a definition doc's stated
  hardware is often aspirational or stale, and getting it wrong mis-pins the whole environment. Even
  when `uv` has already reported the arch, **confirm the real box out loud** with an explicit
  AskUserQuestion. Capture: (a) env manager is **uv** (scaffold baseline); (b) is there an **NVIDIA
  GPU** (local or over SSH), or is this **CPU-only**?; (c) is the box **aarch64/ARM** (e.g. a
  Grace-Blackwell / DGX Spark) — ARM needs the ARM torch index placeholder filled in `env-uv`; (d)
  if the GPU is remote, the **SSH host alias** (fills the `notebooks` port-forward example); (e) the
  **storage backend** (local files / SQLite / Postgres / S3 / MinIO / …) — it drives the resource
  matrix and `.env` keys. *(Dogfood lesson: intake once inferred "CPU laptop / SQLite" from the plan
  when the real box was a DGX Spark ARM+GPU with Postgres — confirm hardware even when the plan
  states it.)*
- **Landing convention** — merge branches into `main` locally *(default)* / push + open a PR. And:
  required commit trailer — none *(default)* / a custom line (e.g. a `Co-Authored-By`). Fills the
  `memory` skill's commit/land placeholders, which `/wrapup` runs against.
- **Version-control scope of the process backbone** — is `PROCESS.md` + the `.claude/memory/process/`
  records (definition, phase-state, decision log, risk register) part of the tracked **deliverable**,
  or kept **all-local**? Ask up front, because it decides `.gitignore`: the common default Python
  `.gitignore` swallows `.claude/` and sometimes `PROCESS.md`, so a project that means to commit its
  process record silently doesn't — and `/setup`'s checkpoint commits come up empty. If tracked,
  ensure the project `.gitignore` does **not** ignore `PROCESS.md` or `.claude/memory/process/`
  (only truly-local state like `settings.local.json`). Two operational notes to pass on either way:
  (1) a decision to publish process snapshots into a `docs/` tree means **one canonical home** —
  the `.claude/memory/process/` copies — regenerated into `docs/`, never hand-mirrored (double-entry
  drift was the dogfood's highest-frequency friction); (2) **never compound-stage a `.claude/` path
  with tracked files in one `git add … && git commit`** — if `.claude/` is gitignored, `git add`
  returns non-zero and the `&&` silently skips the commit.
- **LLM fine-tuning** — ask **only if** the definition doc's archetype involves LLM work: Unsloth
  *(default when applicable)* / none. Flips `finetune-unsloth` **and** `llm-eval` together (a
  fine-tune you can't measure isn't a deliverable).
- **HPO** — Hydra multirun grids only *(default)* / Optuna (continuous spaces, pruning, resumable
  search). Flips `hpo-optuna`.

**Platform stack** — ask these for any platform-lane archetype; skip for a pure model-building lane
(and say you're skipping them, so the user can override):

- **Orchestration** — Kubernetes *(default for platform lanes)* / Docker Compose only / serverless /
  none yet. Flips `kubernetes` and `policy-as-code`.
- **Cloud** — AWS / GCP / Azure / on-prem / none. Only `infra-aws` exists as a lane today; for the
  others, say so plainly rather than implying coverage.
- **Infrastructure as code** — Terraform/OpenTofu *(default when there's a cloud)* / cloud console /
  none. Flips `iac-terraform`.
- **Delivery** — GitOps with Argo CD or Flux *(default with Kubernetes)* / CI pushes with `kubectl` /
  manual. Flips `gitops`. Note that the GitOps default exists for a security reason: it means CI
  never holds cluster credentials.
- **Identity provider** — which IdP for human access, and whether workload identity is available
  (IRSA / GKE Workload Identity / SPIFFE). Flips `authn-authz`.
- **Secrets backend** — External Secrets Operator / Vault / cloud secret manager / SOPS / `.env`
  only. Flips `secrets-management`. If the answer is `.env` only *and* the project deploys, say that
  `.env` is a development convenience and `platform-security.md` `P7` will bite at deploy time.
- **Observability stack** — OpenTelemetry + Prometheus/Grafana *(default)* / a vendor / none yet.
  `observability` is always-on; this fills the collector endpoint in `.env.example`.
- **Model providers** — which third-party model APIs, if any. Records the egress destinations
  (`security.md` `S7`) and the pinning obligation (`model-governance.md` `M14`).
- **Agent tooling** — will this project connect MCP servers or third-party agent tools? Flips
  `mcp-security`.
- **Adversarial testing** — will there be a red-team suite? *(default yes for any agent platform,
  since `model-governance.md` `M16` makes a recorded run part of release evidence.)* Flips
  `llm-red-teaming`.

**Data tier** — ask which stores the project will actually run. Each is off unless named; a store
nobody uses is free context, so don't turn one on speculatively:

- **Transactional database** — Postgres *(default)* / MySQL / none. Flips `relational-stores`.
- **Vector search** — pgvector *(default if Postgres)* / Qdrant / Weaviate / Milvus / a managed
  service / none. Flips `vector-stores`. **Say out loud that pgvector on an existing Postgres is
  usually the right first answer** — it is one fewer system to operate, secure, and back up.
- **Graph** — none *(default)* / Apache AGE in Postgres / Neo4j. Flips `graph-stores`.
- **Cache / queue / stream** — none *(default)* / Redis / Kafka / a managed queue. Flips
  `caching-and-queues`.
- **Object storage + table formats** — object storage only *(default when there's a cloud)* /
  Iceberg or Delta / none. Flips `object-and-lakehouse`.
- **Workflow orchestration** — none *(default — a `CronJob` plus good logging handles a surprising
  amount)* / Airflow / Dagster / Prefect / Temporal / Argo Workflows. Flips
  `workflow-orchestration`. Note this is **not** the same as `pipelines`, which is ML-cascade seams.

Capture the answers before touching any file.

## 2. Write `settings.json` `skillOverrides`

Edit `.claude/settings.json` — set each key to `"on"` or `"off"` from the answers. Only these keys:

| Key | On when… |
|---|---|
| `env-uv` | always `on` (baseline) |
| `tracking-mlflow` | tracker = MLflow |
| `tracking-wandb` | tracker = W&B |
| `config-hydra` | config = Hydra |
| `config-omegaconf` | config = plain OmegaConf |
| `data-dvc` | data versioning = DVC |
| `finetune-unsloth` | LLM fine-tuning = Unsloth |
| `llm-eval` | LLM fine-tuning = Unsloth (flips with it) |
| `hpo-optuna` | HPO = Optuna |
| `annotation` | archetype = computer vision AND the project produces labels |
| `pipelines` | archetype = computer vision with a multi-stage cascade |
| `training` | the archetype trains neural networks (CV, deep time-series, custom torch work) |
| `tabular` | archetype = classical DS on structured data |
| `timeseries` | archetype = time-series / forecasting |
| `wrangling` | flips with `tabular` or `timeseries` (the pandas-heavy lanes) |
| `sql` | the definition doc says data lives in a database / warehouse |
| `data-acquisition` | the definition doc says data is pulled from APIs or scraped |
| `serving` | the project ships a scorer/endpoint — usually flipped at P6, not at intake |
| `monitoring` | the project is deploying — usually flipped later, at P7, not at intake |
| `infra-aws` | cloud = AWS (from the definition doc) — remind the user the IAM starter policy (`.claude/templates/aws-iam-policy.json`) needs *their* review + attachment |
| `containers` | the project builds images (training/serving) or runs local support services via Compose |
| `local-stack` | services must run self-hosted/offline — local annotation (CVAT), S3-compatible blob store (MinIO), local Postgres (+extensions). Flips `containers` with it (Compose underpins it) |
| `kubernetes` | orchestration = Kubernetes. Flips `containers` with it |
| `policy-as-code` | orchestration = Kubernetes AND the cluster is one we configure (not a managed sandbox) — admission control is where the platform rules become enforceable |
| `authn-authz` | the project authenticates anyone or anything: a user-facing endpoint, service-to-service calls, or an agent acting for a user. **On by default for every platform lane** |
| `secrets-management` | a secrets backend was chosen, or any workload needs a credential at runtime |
| `supply-chain-security` | the project builds and ships an artifact (image, model, package). **On by default for every platform lane** |
| `secure-cicd` | the project has a CI pipeline. **On by default** — CI is the most over-privileged identity in most systems |
| `iac-terraform` | IaC = Terraform/OpenTofu |
| `gitops` | delivery = Argo CD / Flux |
| `guardrails` | the project runs a model in front of users — input/output filtering, structured-output validation, PII redaction. **On by default for agent-platform and RAG lanes** |
| `mcp-security` | the project connects MCP servers or third-party agent tools. **On by default for the agent-platform lane** |
| `llm-red-teaming` | there will be an adversarial suite — on by default for any agent platform (`M16`) |
| `infra-gcp` | cloud = GCP |
| `infra-azure` | cloud = Azure |
| `relational-stores` | the project runs a transactional database (as opposed to only querying a warehouse — that's `sql`) |
| `vector-stores` | the project does vector/semantic retrieval. **On by default for the RAG-service and agent-platform lanes** |
| `graph-stores` | the project uses a graph store or builds a knowledge graph |
| `caching-and-queues` | the project runs a cache, a queue, or a stream |
| `object-and-lakehouse` | the project stores data in object storage, or uses Parquet/Iceberg/Delta |
| `workflow-orchestration` | the project runs scheduled or event-driven workflows on a real engine |

### The two wings — both gate, so ask before assuming

Only the chassis (`process`, `governance`, `testing`, `memory`, `wave-planning`) is always-on.
Everything else below is yours to set, including skills that used to be free.

| Skill | Turn on when |
|---|---|
| `agent-security` | **the project involves an LLM or an agent at all** — every platform lane, and LLM fine-tuning. Key it off *that* question, not the archetype: a "tabular" project that calls a model is still an agentic surface. Ask it explicitly if the definition doc is ambiguous. |
| `threat-modeling` | any platform lane, or a model-building project handling regulated/personal data. Needed by P3. |
| `observability` | the project runs a service anyone depends on. On for every platform lane. |
| `reliability-sre` | the project has users who notice when it breaks — i.e. it ships. On for every platform lane; off for a research/notebook project. |
| `agent-evaluation` | the thing being measured is an agent or LLM system (trajectories, judges, safety suites) rather than a classifier. Pairs with, not replaces, `evaluation`. |
| `datasets` `evaluation` `statistics` | **on by default in both families** — any project with data defines splits, measures something, and has to say whether a difference is real. Turn off only for a pure-infrastructure project with no model in it. |
| `eda` `visualization` `notebooks` `reporting` | the project explores data, produces figures, or writes findings up. On for every model-building lane; usually off for an inference-platform or MLOps lane, which consumes models rather than building them. |

**Platform-lane defaults**, unless the interview says otherwise: the five spine skills above, plus
`kubernetes`, `authn-authz`, `supply-chain-security`, `secure-cicd`, `guardrails`, `mcp-security`,
`containers`, `serving` on; `policy-as-code`, `secrets-management`, `iac-terraform`, `gitops`,
`llm-red-teaming` on when their question said yes. `eda`/`visualization`/`notebooks`/`reporting`
off unless the project also builds models.

**Model-building-lane defaults:** the DS core (`datasets`, `eda`, `evaluation`, `statistics`,
`visualization`, `notebooks`, `reporting`) on, plus the lane's own skills; the platform block off.
`agent-security` still **on** for LLM fine-tuning. `threat-modeling` on if the data is regulated.

**Do not turn `agent-security` off to save context without saying so out loud.** The security floor
is the hooks plus the canon, both of which hold regardless — but the skill is what makes the design
ladder available, and a project that adds an agent later will not notice it is missing. Record the
answer in `project-definition.md` so a later `/gate` can see it.

**Budget note:** `skillListingBudgetFraction` is `0.03`. It was `0.04` when the security spine and
the DS core were both always-on; gating both wings bought that back. If a project genuinely doesn't
need a lane, turning it **off** is free context — say so in the report rather than leaving
everything on "just in case."

Exactly one tracker key and one config key should be `on`; the unchosen siblings go `off`. If the tracker
or data-versioning answer is "none", leave all keys in that group `off`. **Lane skills flip from the
archetype in the definition doc (step 0) — no extra question needed; the mapping is the lane rows in the table above.**

> **`skillOverrides` flips need a session boundary before they can be *invoked*.** Editing this file
> mid-session immediately surfaces a newly-`on` skill's *description* in the listing, but the **Skill
> tool may still refuse to invoke it** (the invocation gate reads the pre-edit state). Since intake is
> one-time and `/bootstrap` follows, this rarely bites here — but if a flipped skill won't invoke,
> that's why: start a fresh session, or read its `SKILL.md` directly in the meantime.

## 3. Fill the answerable `<PLACEHOLDER>`s

Run `grep -rn "<PLACEHOLDER" .claude/ CLAUDE.md README.md` to list every one. Resolve **only** those the
interview now answers; leave the rest for the user. The answer-determined ones:

- **MLflow experiment + run naming** — `.claude/skills/tracking-mlflow/SKILL.md` (the
  `set_experiment("<PLACEHOLDER: ...>")` and `run_name` placeholders). Fill from the definition doc's
  project name. The tracking URI itself has no placeholder — it flows through `MLFLOW_TRACKING_URI`
  in `.env` (note the value for `/bootstrap` if the user gave one). Skip if the tracker isn't MLflow.
- **Project name in the agents** — `.claude/agents/*.md` carry a `<PROJECT NAME>` token (it sits
  outside the `<PLACEHOLDER` grep — this bullet is its claim). Fill from the definition doc's project
  name; always answerable, step 0 produced it.
- **W&B project name** — `.claude/skills/tracking-wandb/SKILL.md` (`wandb.init(project=...)`). Fill if
  the user named a project; otherwise leave and flag it. Skip entirely if the tracker isn't W&B.
- **DVC remote URL** — `.claude/skills/data-dvc/SKILL.md` (`dvc remote add -d storage ...`). Fill with the
  user's remote if given; else flag. Skip if data versioning isn't DVC.
- **Policy canon org values** — the security-posture and platform-stack answers fill these directly.
  Fill what the interview answered; leave the rest as explicit open questions in the report:
  - `.claude/memory/policy/security.md` — org secret manager; approved egress destinations + approver.
  - `.claude/memory/policy/ai-security.md` — the org's agent **autonomy tiers** (which action classes
    may run unattended, and who approves a promotion between them). From the autonomy + HITL answers.
  - `.claude/memory/policy/platform-security.md` — approved container registries + who approves a new
    one; the cluster's tenancy model and which sensitivity classes may share a node pool.
  - `.claude/memory/policy/identity-and-access.md` — the IdP and the groups/claims that map to
    administrative access; the secrets backend and how workload credentials are issued; rotation
    intervals per credential class and their owners.
  - `.claude/memory/policy/supply-chain.md` — approved package registries and model hubs + approver;
    the artifact/attestation store; the CVE severity threshold that blocks a release.
  - `.claude/memory/policy/reliability.md` — SLO targets and windows per service + who agrees them;
    severity definitions, on-call rotation, escalation path; the severity above which a written
    postmortem is required.

  These are the placeholders most likely to be left blank, and they are the ones that make canon
  enforceable rather than aspirational. **An unfilled one is reported, never invented** — guessing a
  rotation interval or an approver is worse than an honest blank.
- **ARM torch index** — `.claude/skills/env-uv/SKILL.md` (`<PLACEHOLDER: ARM torch index for your box>`).
  Fill **only if** the box is aarch64/ARM; on x86 leave the surrounding note as-is and note it's N/A.
- **Dataset path placeholders** — e.g. `data/<PLACEHOLDER: dataset dir>` / `<PLACEHOLDER: dataset_name>`
  in `data-dvc` and `datasets`. Fill if the user named a dataset/path during intake; otherwise leave.
- **`memory` skill commit/land placeholders** — `.claude/skills/memory/SKILL.md` (the commit-trailer
  line and the landing-convention line). The landing-convention question always answers these — the
  defaults ("merge locally", "no trailer") resolve them too, so this bullet always completes; never
  leave them blank, because `/wrapup` runs the memory skill verbatim and hits them.
- **`notebooks` gpu-host** — `.claude/skills/notebooks/SKILL.md` (`ssh -L ... <PLACEHOLDER: gpu-host>`).
  Fill **only if** the GPU box is remote (from the baseline confirm); if local, leave the example
  as-is and note it's N/A — same pattern as the ARM torch index.

Don't invent values. If an answer wasn't given, leave the placeholder and list it in the summary.

**Out of scope on purpose — say so, don't silently skip.** Two other classes of placeholder exist, and the
user WILL assume this command handled them unless step 4 tells them otherwise:
- **Code-dependent** (the `conf/` tree, the train/eval entry points, the seed helper, the dataset slug).
  These can't be filled until the project skeleton exists — that's **`/bootstrap`**, the next command.
- **Human-decision** (data-remote URL, `governance` policy domains, `software-architect` architecture
  principles, the org rules in `memory/policy/`). These need the user, not an agent. Leave and list them.

## 4. Template-mode cleanup (only when the repo IS the scaffold)

Two ways this scaffold arrives: `install.sh` into an existing project (leaves a `.claude/scaffold-version`
stamp), or GitHub's **"Use this template"** (the repo *is* a copy of claude-for-ai-platforms — no stamp, and it
carries the scaffold's own delivery files, which are about the scaffold, not the user's project).

**Detect template mode:** `install.sh` **and** `.claude/scripts/check-scaffold.sh` exist at repo root
**and** there is no `.claude/scaffold-version`. If that doesn't hold, skip this step silently.

If detected, **offer** the cleanup (AskUserQuestion — never do this silently; it deletes files):

- Delete `install.sh` + `VERSION` (this repo won't be installing itself anywhere), and write the
  scaffold's version + SHA into `.claude/scaffold-version` so the provenance survives the cleanup.
- Replace `.github/workflows/ci.yml` (the *scaffold's* self-consistency CI — it would fail against a
  real project) with `.claude/templates/project-ci.yml`.
- Replace `README.md` (the scaffold's own) with a minimal project stub: project title, quick start,
  and a "configured by claude-for-ai-platforms vX" line. Keep `CHANGELOG.md` only if the user wants one.
- Optionally delete `.claude/scripts/check-scaffold.sh` — it checks the scaffold, not the project.

If declined, note in the report that the scaffold's own delivery files are still in place.

## 5. Report

Print a short summary:

- **Skills on:** the `skillOverrides` keys now `on`. **Skills off:** the rest.
- **Placeholders filled:** file + what each became.
- **Still needs you:** every `<PLACEHOLDER` left unresolved (from the step-3 grep), **split into the two
  classes above** — "will be filled by `/bootstrap`" vs. "needs your decision". A flat list reads as a
  to-do the user must do by hand, which is wrong and makes it look like intake failed.

Then: **this command is one-time** — re-run only to change stacks (the definition step is skipped on
re-runs; see step 0). **Next step is `/bootstrap`**, which builds the skeleton (`conf/` +
`train.py`/`eval.py`) that every skill's examples assume — it reads the definition doc's Setup
implications, so its interview should mostly be confirmation. Say this explicitly — the scaffold is
not usable until it's run. After `/bootstrap`: run **`/gate`** — the definition doc is most of P1's
gate evidence, so the review should be quick.
