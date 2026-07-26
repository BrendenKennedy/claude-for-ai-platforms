# PROCESS.md — A Hybrid Project Framework for AI Platforms and Models

> **Version:** 1.1.0 · **Last updated:** 2026-07-26 · **Owner:** _(you)_
> **Status:** Living document. Edited after every project retrospective (see Part V).

This is a reusable operating system for running data and AI projects — an AI platform, a model, or both — solo or as a lead. It is a deliberate cross-breed of the proven, published frameworks below, keeping what each does best and discarding what each underemphasizes. Every phase ends in an **exit gate**: questions you must answer in writing before moving on. Gates are the difference between a process and winging it.

**How to use it:** copy this file into the root of every new project repo. Fill the templates in Part IV as you go. Treat unfilled gates as blockers, not suggestions. In this repo, gates are not left to discipline — the `/gate` command walks the current phase's checklist and records the verdict (see §3.8). After shipping, run the retro and edit this document itself.

**Which family you're in** is recorded in `.claude/memory/process/project-definition.md` by `/intake`, and the gates size themselves to it: §3.9's archetype table scales the security and reliability track three ways rather than asking a tabular-regression project about admission control. The phase *names* below lean data-science, for lineage reasons Part I explains; §2.1 maps them onto platform work.

---

## Part I — Lineage: the proven frameworks underneath

Nothing here is invented from scratch. Each element is traceable to a published methodology with decades of industry use. Knowing the names matters — they are interview vocabulary, searchable anchors, and evidence that the process rests on more than one person's habits.

### Source frameworks at a glance

| Framework | Origin | Core contribution | What we adopt | What we leave |
|---|---|---|---|---|
| **KDD** | Fayyad, Piatetsky-Shapiro & Smyth, 1996 (academic) | First formalization: mining is one step inside a larger discovery process; iteration is inherent | The iterative, non-linear mindset | Academic framing; no business or delivery phases |
| **SEMMA** | SAS, mid-1990s | Disciplined technical loop: Sample → Explore → Modify → Model → Assess | EDA rigor before modeling | Tool-centric; skips business understanding and deployment entirely |
| **CRISP-DM** | Industry consortium (SPSS, Daimler, NCR, OHRA), 1999–2000 | The 6-phase backbone: Business Understanding → Data Understanding → Data Preparation → Modeling → Evaluation → Deployment, with explicit back-loops | Phase structure; business-first ordering; iteration arrows | Vague on teams, tooling, QA, and anything after deployment |
| **TDSP** | Microsoft, 2016 | Team operability: defined roles, standardized repo structure, document templates, agile cadence | Roles, standardized repo layout, named documentation artifacts | Fixed-length sprints (poor fit for research uncertainty); Azure tool coupling |
| **CRISP-ML(Q)** | Studer et al., 2021 (arXiv 2003.05155) | Quality assurance loop (identify risk → mitigate) attached to *every* task, plus a dedicated Monitoring & Maintenance phase | Per-phase risk/QA discipline; the monitoring phase; measurable success criteria incl. a non-ML baseline | Heavyweight formality where a solo project needs speed |
| **Agile DS (Scrum/Kanban adaptations)** | Practitioner community, 2010s | Time-boxing, visible backlog, demo cadence | Kanban-style hypothesis backlog; regular demos | Sprint *commitments* for research tasks — experiments don't estimate well |
| **MLOps** | Google ("MLOps levels 0–2"), Sculley et al. "Hidden Technical Debt in ML Systems" (2015) | Reproducibility, versioning of data/models/code, drift monitoring, automation maturity levels | Pinned environments, seeds, data snapshots, experiment tracking, monitoring concepts | Full CI/CD automation — overkill until something is actually deployed |
| **Cookiecutter Data Science** | DrivenData | Standardized repo layout; "notebooks explore, `src/` productionizes" | Directory conventions and the exploration/production split | Nothing — it's small and composable |
| **Lean / hypothesis-driven development** | Lean Startup lineage; Google's "Rules of ML" | Falsifiable hypotheses, kill criteria, simplest-thing-first, baseline-before-model | Kill criteria in Phase 1; baseline-first rule in Phase 5 | Growth-hacking framing irrelevant to modeling work |
| **Data-centric AI / annotation ops** | Practitioner community (label-quality research, e.g. Northcutt et al. on label errors; standard IAA statistics) | Labels are a manufactured artifact with a measurable defect rate, not ground truth by decree | Annotation spec, pilot + inter-annotator agreement, gold sets, label-error audits (P2) | Vendor/platform specifics |

| **Secure SDLC** | NIST SSDF (SP 800-218 v1.1) + SP 800-218A for AI; Microsoft SDL; CISA Secure by Design | Security is a set of development *practices* with owners and evidence, not a review at the end | PS/PW practice shape in P4, RV in P7; 218A's "training data is supply chain" and adversarial-testing-as-a-development-activity | Federal attestation ceremony; acquirer-side guidance |
| **AI risk management** | NIST AI RMF (AI 100-1) + Generative AI Profile (AI 600-1) | GOVERN / MAP / MEASURE / MANAGE as the shape of responsible AI work | The four functions mapped onto the existing phases (§3.9) — not a parallel ceremony | Org-level program structure; the full Playbook checklist |
| **Threat modelling** | STRIDE (Microsoft); LINDDUN; MITRE ATLAS; OWASP ASI/LLM Top 10 | Enumerate what can go wrong against a checklist, per trust boundary, before building | The four-question frame + trust boundaries at P3; ATLAS/ASI ids as the naming convention | Numeric scoring models — fake precision that starts arguments about the number |
| **SRE** | Google (*SRE*, *SRE Workbook*, *Building Secure and Reliable Systems*) | Reliability is a measurable target with an agreed consequence, not an aspiration | SLI/SLO/error budgets, blameless postmortems, graceful degradation; and its claim that security and reliability must be designed *together* | Google-scale org structure; dedicated-SRE-team assumptions |
| **DevSecOps / supply chain** | SLSA (OpenSSF), Sigstore, OWASP CI/CD Top 10 | The build pipeline is production infrastructure, and artifacts need provenance | Build provenance levels, SBOM, sign-and-verify, pipeline least-privilege (P4/P6) | Tool advocacy; maturity-model scoring |

### Why CRISP-DM is the spine

CRISP-DM remains the most widely used data science process framework decades after publication — practitioner polls consistently place it far ahead of alternatives. It earned that position by being industry-agnostic, business-first, and honest about iteration. Its known weaknesses are exactly what the other frameworks patch:

- **No team model** → patched by TDSP (roles, artifacts, repo standards)
- **No QA methodology** → patched by CRISP-ML(Q) (risk identification per task)
- **Nothing after deployment** → patched by CRISP-ML(Q) Phase 6 + MLOps monitoring
- **No reproducibility discipline** → patched by MLOps practices
- **No explicit stopping rule** → patched by Lean kill criteria
- **No labeling discipline** → patched by data-centric AI / annotation-ops practice (no classical framework covers it)

### Design principles of the hybrid

1. **Gates over vibes.** Every phase has written exit criteria. A phase is done when its gate passes, not when it feels done.
2. **Baselines before models.** No trained model is meaningful until compared against the dumbest credible alternative.
3. **Provenance everywhere.** Every data value, decision, and experiment must be traceable to a source, a date, and a rationale.
4. **Scope is a written contract.** v1 is defined in writing; everything else lives in a parking lot and must pass a gate to enter scope.
5. **Leakage is the default failure mode.** Temporal validity is checked explicitly, per feature, in writing.
6. **The process is itself versioned.** This document has a version number and a changelog because it is expected to change.
7. **Label quality is measured, not assumed.** Any label this project *produces* (rather than inherits) gets a written spec, a pilot with inter-annotator agreement, and an audited error rate before a model trains on it.
8. **Gates are enforced by structure, not discipline.** The gate is a checklist file that a tool refuses to pass while items are unchecked (§3.8) — not a habit you promise to keep. A process that depends on remembering to follow it is the failure mode this document exists to prevent.

---

## Part II — The Lifecycle

```
┌────────────┐   ┌────────────┐   ┌──────────────┐   ┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│ P1 Problem │ → │ P2 Data    │ → │ P3 Data      │ → │ P4 Feature  │ → │ P5 Modeling  │ → │ P6 Delivery  │
│ Definition │   │ Discovery  │   │ Architecture │   │ Engineering │   │ & Evaluation │   │ & Retro      │
└────────────┘   └────────────┘   └──────────────┘   └─────────────┘   └──────────────┘   └──────────────┘
      ↑________________↑_________________↑___________________↑_________________│                  │
                        (iteration loops back at any point — CRISP-DM style)                      ▼
                                                                                    ┌─────────────────────────┐
                                                                                    │ P7 Monitoring &         │
                                                                                    │ Maintenance (if deployed)│
                                                                                    └─────────────────────────┘
```

Iteration is expected: evaluation results routinely send you back to features or data. What is *not* allowed is skipping a gate on the way forward.

### 2.1 Reading the phases for a platform project

The phase names come from the data-science lineage in Part I and are deliberately unchanged — every skill in this scaffold cross-references them by number *and* name, so a rename would cost drift across ~50 files for presentational gain. What changes between the two families is what each phase is *about*, not what it demands:

| Phase | On a model project | On a platform project |
|---|---|---|
| **P2** Data Discovery | sources, splits, label quality, class balance | corpora and retrieval sources, model providers, where data crosses a **trust boundary** |
| **P3** Data Architecture | storage layout, immutability, the data pipeline | system architecture **and its trust boundaries** — this is the input `/threat-model` consumes |
| **P4** Feature Engineering | features, leakage discipline, the feature dictionary | controls, policy-as-code, pipeline hardening — the mechanisms that make P3's threats decided rather than noted |
| **P5** Modeling & Evaluation | train, tune, compare against a baseline | agent/system evaluation — trajectories, judges, and a **recorded adversarial run** |

P1, P6 and P7 read the same for both. The exit-gate questions in Part III are written to be answerable either way; where one genuinely does not apply, `N/A — <archetype>` is a valid recorded answer and silence is not.

---

### P1 — Problem Definition
**Provenance:** CRISP-DM Business Understanding · CRISP-ML(Q) success criteria & feasibility · Lean kill criteria

**Purpose:** Lock the target, the consumer, the metric, and the stopping rule before any code exists.

**Key activities**
- Write the one-page problem statement: prediction target, who consumes the output, what decision it informs
- Define constraints: deadline, data access, compute, budget
- Define **measurable** success criteria: metric + threshold + the baseline it must beat
- Name a **non-ML heuristic benchmark** (CRISP-ML(Q) practice) — the simplest rule a human could apply
- Write **kill criteria**: the result that means stop or pivot
- Feasibility sanity check: does the data plausibly exist to answer this?
- **Compute feasibility math:** estimate the cost of one training run (GPU-hours) and the number of runs the plan implies; check the product against the hardware you actually have and the deadline. Order-of-magnitude is fine here — the estimate hardens into a tracked budget in P5. This is the same move as P2's rate-limit math, applied to GPUs: for deep-learning work, compute arithmetic kills projects just as dead as API quotas.

**Outputs:** Problem statement (Template T1) · success metric definition · kill criteria · rough compute budget

**In this repo:** `/intake` opens with exactly this interview (step 0) — archetype + lane fit, T1, and an anti-pattern challenge pass — and writes `.claude/memory/process/project-definition.md`, which doubles as most of this gate's evidence.

**Exit gate**
- [ ] A stranger could read the problem statement and state exactly what "done" means
- [ ] The success metric is computable from data you can actually obtain
- [ ] A baseline is named in writing
- [ ] Kill criteria are written
- [ ] Deadline and constraints are explicit
- [ ] Compute math done: est. GPU-hours per training run × planned runs fits the available hardware and the deadline
- [ ] **Security posture recorded** — data sensitivity, tenancy, exposure, agent autonomy, and human-in-the-loop requirements, from `/intake`'s posture interview
- [ ] **Regulatory exposure asked, not assumed** — does this touch an EU AI Act Annex III use case or ship a GPAI model? A "yes" or "unsure" is in the risk register with counsel flagged (§3.9)

---

### P2 — Data Discovery
**Provenance:** CRISP-DM Data Understanding · TDSP Data Acquisition & Understanding · (labeling: data-centric AI practice — no classical framework covers annotation ops)

**Purpose:** Verify — not assume — that every planned feature has an obtainable, legal, fresh-enough source, and that any labels the project must *produce* can be produced at a measured, acceptable quality.

**Key activities**
- Build the source inventory (Template T2): endpoint, auth, rate limits, licensing/ToS, update cadence
- Pull *sample* data from every source before committing to it
- Data quality audit: missingness, ranges, duplicates, encoding traps, weird distributions
- **First predictive-signal probe** (once a split and any candidate columns exist): a cheap, train-only single-feature-AUC / mutual-information / correlation pass vs the target — an early read on whether the data plausibly carries learnable signal, hardened into the P3 go/no-go (see `eda`)
- Design the acquisition plan: caching strategy, retry/backoff, rate-limit budget math
- Log discovered risks into the risk register

**Labeling & annotation** *(conditional — applies when this project produces labels rather than inherits them; skip and mark N/A otherwise)*
- Write the **annotation spec** (Template T8) *before* anyone labels: class definitions, boundary rules (occlusion, truncation, crowding, ambiguous cases), canonical positive/negative/hard examples, and what explicitly does **not** get labeled
- **Pilot round:** label a small batch with ≥2 annotators (solo: you, twice, a week apart), measure **inter-annotator agreement** (Cohen's κ for class labels; IoU-based agreement for boxes/masks), and revise the spec + re-pilot until agreement clears a threshold you wrote down first
- Build a **gold set** — a re-reviewed, trusted subset — for auditing annotator drift during production labeling
- **Audit delivered labels:** sample, re-review, and record the label error rate. An unmeasured label error rate becomes an invisible ceiling on every model trained downstream

**Outputs:** Source inventory · data quality notes · ingest plan with caching policy · (if labeling) annotation spec + IAA result + label error rate

**Exit gate**
- [ ] Every feature in the plan maps to a verified source (sample actually pulled)
- [ ] ToS / licensing checked and noted per source
- [ ] Rate-limit math done: total calls needed vs. daily budget vs. deadline
- [ ] Caching policy defined (raw responses persisted; nothing fetched twice)
- [ ] Quality risks logged in the risk register
- [ ] *(if labeling)* Annotation spec written and survived a pilot: IAA measured and above the written threshold
- [ ] *(if labeling)* Label error rate estimated from an audited sample and small relative to the margin the success metric needs
- [ ] *(if labeling)* Gold set exists, if labeling continues past this phase
- [ ] **Sensitive-data classes identified** and their lawful basis recorded (`data-governance.md` D1–D2)
- [ ] *(if the project retrieves)* **Retrieval corpus treated as a governed dataset** — per-document provenance, no ingestion from user-writable locations without review (`D7`)

---

### P3 — Data Architecture
**Provenance:** TDSP standardized structure · MLOps versioning & provenance · Cookiecutter Data Science layout

**Purpose:** Make the data layer boring, traceable, and query-friendly before feature work begins.

**Key activities**
- Design the schema (entities, keys, relationships, indexes) around the *queries feature engineering will run*
- Choose storage with a migration path (e.g., SQLite → PostgreSQL via SQLAlchemy)
- Define versioning: snapshot reference data on every upstream version change (e.g., game patch, API schema rev)
- Add provenance columns as standard: `source`, `collected_at`, `source_version`
- Scaffold the repo (see layout below); raw data is **immutable** — transforms write new tables, never overwrite source
- Environment pinned from day one (`pyproject.toml` / lockfile)

**Standard repo layout** *(generic default — **in this repo** the layout is generated by `/bootstrap`
(Hydra `conf/` tree + `train.py`/`eval.py`); defer to it and keep only this section's invariants:
immutable raw data, provenance columns, pinned env)*
```
project/
├── data/          # raw cache, gitignored, immutable
├── db/            # database file(s), gitignored
├── src/
│   ├── ingest/    # API clients, scrapers, parsers
│   ├── schema/    # ORM models / DDL
│   ├── features/  # feature computation
│   └── models/    # training + evaluation
├── notebooks/     # exploration only — logic graduates to src/
├── tests/
├── PROCESS.md     # this file
└── README.md
```

**Outputs:** Schema doc/DDL · repo scaffold · versioning policy

**Exit gate**
- [ ] Any value in the database can be traced to source + collection date + source version
- [ ] Raw data immutability rule is enforced by structure, not discipline
- [ ] Schema supports the aggregate queries Phase 4 will need (tested with one real query)
- [ ] Environment is pinned and reproducible
- [ ] **Threat model written and current** (`.claude/memory/process/threat-model.md`, dated) — trust boundaries named, every threat driven to a decision, gaps in the risk register. **This is the phase where it changes the design cheaply**
- [ ] *(if the system has agents)* **Agent authority declared** — tool grants, human gates, and budget caps in `agent-authority.md` (`ai-security.md` AI2/AI3/AI9)
- [ ] **Predictive-signal go/no-go recorded** (train-only screen — single-feature AUC/MI + a quick multivariate read vs the trivial baseline; see `eda`). An explicit written call that there is enough signal to justify the P4/P5 spend — a weak result is a stop-and-rethink *before* feature engineering, not a discovery deferred to the modeling sweep. (Caveat noted in the record: adversarial targets and split-shift ceilings are the baseline step's job, not the screen's — a strong screen still doesn't excuse skipping baselines.)

---

### P4 — Feature Engineering
**Provenance:** CRISP-ML(Q) per-task QA · hypothesis-driven development · MLOps testing discipline

**Purpose:** Turn raw data into signals, with a written reason and a leakage check for every one.

> **For vision / deep-learning projects:** read "feature" as *any input-representation choice* — crop geometry, resolution, augmentation policy, channel selection, label definition. The discipline is identical: each choice gets a written hypothesis and a leakage/temporal-validity review. (An augmentation or normalization computed from whole-dataset statistics is leakage too — normalization stats come from train only.)

**Key activities**
- Maintain the feature dictionary (Template T5): every feature gets a **hypothesis** — the causal story for why it should carry signal
- **Leakage review per feature:** was this information available at prediction time? Historical aggregates must be computed only from data *before* each training example
- Unit-test feature computations (known input → known output)
- Distribution sanity checks after computation (ranges, nulls, cardinality)
- Aggregations are *computed* in the feature layer, not stored as facts — schema holds truth, features hold signal

**Outputs:** Feature dictionary · tested feature pipeline

**Exit gate**
- [ ] Every feature has a written hypothesis
- [ ] Every feature passed an explicit leakage / temporal-validity review
- [ ] Feature computations have passing unit tests
- [ ] Distributions eyeballed and anomalies explained or fixed
- [ ] **Controls implemented, with mechanisms** — the canon rules this phase's work touches have a hook, policy, or code path, not just prose (`/harden` or `compliance-mapper` produces the evidence)
- [ ] **Policy-as-code green** — manifests and IaC pass `conftest`/Kyverno, and `conftest verify` shows the policies actually reject their bad fixtures
- [ ] **Pipeline hardened** — no long-lived cloud credentials, actions pinned by SHA, fork PRs get no secrets (`supply-chain.md` C6)

---

### P5 — Modeling & Evaluation
**Provenance:** CRISP-DM Modeling + Evaluation · Google "Rules of ML" (start simple) · MLOps experiment tracking

**Purpose:** Beat a defensible baseline on the Phase-1 metric, and know *where* and *why* the model fails.

**Key activities**
- **Baselines first, always:** majority class → simple interpretable model (logistic regression) → domain baseline (e.g., market-implied probabilities). No complex model until these exist
- **Experiment budget:** before the first non-baseline model, harden P1's rough compute estimate into a written plan — the experiments you intend to run, est. GPU-hours each, against the total you have before the deadline. Every experiment gets a written question and a time/compute budget *before* it starts (§3.6); track spend as you go
- Temporal train/test split when data has time structure — random splits leak the future
- Log every run in the experiment log (Template T6): date, data snapshot, features, params, metrics
- Calibrate if probabilities are consumed downstream (log loss / Brier score, `CalibratedClassifierCV`) — an accurate-but-overconfident model is worse than useless when its probabilities feed a downstream decision (e.g. compared against market odds)
- Error analysis: segment the failures. *Where* it fails matters more than how often
- Robustness spot-checks: does performance survive across time slices / subgroups?

**Outputs:** Experiment log · experiment budget with tracked spend · evaluation report vs. baseline · model card-lite (intended use, training data, metrics, known limits)

**Exit gate**
- [ ] Documented comparison against every baseline on the Phase-1 metric
- [ ] Split strategy is temporal (or leakage-safe) and stated in writing
- [ ] Error analysis written: top failure modes identified
- [ ] Calibration checked if probabilities are the product
- [ ] Experiment spend tracked against the written compute budget; overruns were decided in writing (decision log), not drifted into
- [ ] Kill criteria from P1 consulted: continue, pivot, or stop — decided explicitly
- [ ] **Adversarial run recorded** — a dated `/redteam` run with ASI/ATLAS coverage stated, findings triaged, and every fix encoded as a regression case (`model-governance.md` M16)
- [ ] *(if agentic)* **Trajectory evaluated, not just final answers** — tool-call correctness and behaviour under adversarial input (`agent-evaluation`)
- [ ] *(if an LLM judge is used)* **Judge validated against human labels**, with the agreement number reported alongside its scores

---

### P6 — Delivery & Retrospective
**Provenance:** TDSP Customer Acceptance · MLOps reproducibility · the meta-loop (Part V)

**Purpose:** Ship something a stranger — or you in six months — can rerun, then extract the process lessons.

**Key activities**
- Reproducibility pass: pinned env, fixed seeds, data snapshot or deterministic fetch script, one-command run
- README: problem, results, how to reproduce, limitations
- Deliver: demo, report, video walkthrough, or deployment — whatever Phase 1 said the consumer needed
- Run the retrospective (Template T7)
- **Edit this PROCESS.md** based on the retro; bump the version

**Outputs:** Reproducible repo · README · retro doc · updated PROCESS.md

**Exit gate**
- [ ] Clean-environment rerun succeeds (or the gaps are honestly documented)
- [ ] README lets a stranger understand and reproduce the result
- [ ] Retro completed and PROCESS.md updated with at least one change (or a written "no changes needed")
- [ ] **SLOs defined with agreed consequences** — `slo-register.md` has targets, windows, owners, and what happens when the budget is spent (`reliability.md` R1/R2)
- [ ] **Rollback exercised, not just designed** (`R3`) — an untested rollback is a plan, not a capability
- [ ] **Runbook per alert**, and every alert is actionable (`R6`)
- [ ] **Artifacts have an SBOM, a signature, and build provenance** — and something *verifies* the signature (`supply-chain.md` C2–C4)
- [ ] **Control coverage current** (`control-coverage.md`), with expired policy exceptions cleared or re-accepted

---

### P7 — Monitoring & Maintenance *(conditional: deployed systems only)*
**Provenance:** CRISP-ML(Q) Phase 6 · MLOps drift monitoring

**Purpose:** A model in a changing environment degrades by default; this phase makes degradation visible and actionable.

**In this repo:** the `monitoring` skill carries the mechanics (prediction logging, PSI/KS drift stats, reference windows, retrain triggers, shadow eval) — flip it on in `skillOverrides` when deployment happens.

**Key activities**
- Monitor live performance on the Phase-1 metric
- Detect input drift (feature distributions) and concept drift (relationship changes — e.g., a balance patch changes the game)
- Define retraining triggers: schedule-based, drift-based, or upstream-event-based (new patch ⇒ retrain)
- Name an owner and an alerting path

**Exit gate**
- [ ] Staleness criteria written (what measurement means "the model is stale")
- [ ] Retraining trigger defined and tested once
- [ ] An owner is named
- [ ] **Telemetry live** — the three signals plus the agent-specific spans that make a bad run reconstructable (`ai-security.md` AI12)
- [ ] **Audit logging on and shipped off-cluster** (`platform-security.md` P9) — a log the attacker can delete is not evidence
- [ ] **Incident path known** — severity definitions, who is paged, escalation, and the postmortem threshold (`R7`/`R8`)

---

## Part III — The PM Layer (cross-cutting)

These artifacts run through every phase. They are not paperwork *about* the management — they **are** the management. A lead's job is largely keeping these current and enforcing the gates other people want to skip.

### 3.1 Decision Log
One line per decision (Template T3): date, decision, alternatives considered, rationale. Leads get asked "why did we do X?" constantly; this is the answer. It also stops re-litigating settled questions. Log anything you'd have to reconstruct from memory later (storage choice, scope cuts, source selection, metric choice).

**In this repo:** process-level decisions (scope, metric, kill/pivot, gate judgment calls) land in `.claude/memory/process/decision-log.md`, via the `governance` skill's record protocol. Domain-specific calls (data licensing, model release, security) go in that domain's log under `.claude/memory/policy/` — one home per decision, no parallel logs.

### 3.2 Risk Register
Top 3–7 live risks (Template T4), each with likelihood, impact, and a mitigation. Reviewed at every phase gate. New risks discovered mid-phase get logged immediately, not remembered later. (This is CRISP-ML(Q)'s core QA move — identify risk, mitigate risk — generalized to the whole project.)

### 3.3 Scope Ledger
Two lists (the Scope Ledger template, Part IV): **v1 (the contract)** and **the parking lot**. Anything not in v1 goes to the parking lot by default. Promotion from parking lot to scope requires a written gate: what does it add, what does it cost, what does it displace? This is how scope creep dies.

**In this repo:** the v1 contract lives in `.claude/memory/process/scope-ledger.md`; the parking lot **is** `.claude/memory/roadmap.md` — one backlog, not two. Promotions get a line in the decision log.

### 3.4 Experiment Log
Every model run: date, data snapshot ID, feature set, params, metrics, one-line takeaway. A spreadsheet is fine; MLflow is fine; a markdown table is fine. What is not fine is "I think the third run was the good one."

**In this repo:** the experiment log **is** the tracker (`/intake`'s choice — MLflow by default — via its tracking skill: params, metrics, config snapshot, takeaway as a run note). T6 is the fallback for pre-tracking spikes only; two experiment logs is how one goes stale.

### 3.5 Feature Dictionary
Every feature: name, formula/source, hypothesis, leakage review result, added date. Doubles as documentation for the video/report and as the leakage audit trail.

### 3.6 Cadence
- **Solo mode:** a weekly self-review against the current phase gate + risk register. Timebox exploration: any experiment gets a written question and a time budget before it starts.
- **Team mode:** short standups; phase-gate reviews as scheduled checkpoints with stakeholders; demo at every phase exit. Prefer **Kanban with a hypothesis backlog** ("test whether X improves metric Y") over fixed sprint commitments — research tasks estimate poorly, which is the known friction point of forcing Scrum onto DS work.

### 3.7 Roles (team mode, adapted from TDSP)
- **Project lead** — owns the gates, the decision log, and stakeholder communication
- **Data scientist(s)** — own features, models, experiment log
- **Data engineer** — owns ingest, schema, pipeline reliability
- **Stakeholder / product owner** — signs off on the problem statement (P1 gate) and acceptance (P6 gate)

Solo projects: you hold all four hats — the framework's value is forcing you to *switch hats deliberately* instead of letting the data-scientist hat silently overrule the project-lead hat.

### 3.8 Gate Enforcement
Principle 8 made mechanical. "Treat unfilled gates as blockers" is exactly the kind of rule that survives only as long as motivation does — the same failure mode P3 refuses for data immutability ("enforced by structure, not discipline"). So gates get structure:

- **The gate is a file.** The current phase and every gate checklist live in a **phase-state file** in the repo, as literal checkboxes filled in writing — in this repo, `.claude/memory/process/phase-state.md`. "We passed P2" is a claim about that file, not a recollection.
- **Transitions happen only through a gate review.** A forward phase transition is performed by an explicit review that walks the checklist item by item, demanding *evidence* (a file, a number, a link) rather than assent — in this repo, the `/gate` command. It refuses to advance the phase while any non-N/A item is unchecked.
- **The risk register is reviewed at every gate review** (§3.2) — same mechanism, so it actually happens.
- **Unchecked items are gate debt.** They are recorded by name in the phase-state file, visible at the next session's start — not silently forgotten. Working *inside* a phase with open debt is fine; moving *forward* past it is not.
- **Conditional items** (e.g., the labeling items in P2, P7 entirely) may be marked **N/A with a written reason** — a reason, not a shrug.

### 3.9 The security & reliability track
Security and reliability are not a phase. They are a track that runs *through* the phases, with
items on every gate (Part II) — because the cheapest place to fix either is the design, and a
security review bolted on at P6 finds problems whose fix is a rewrite.

**The track scales with the archetype; it does not switch off.** A model-building project and an
agent platform carry very different surfaces, and pretending otherwise produces a checklist people
route around. `/gate` reads the archetype from `project-definition.md` and sizes the track:

| Archetype | The track is | Which reduces to |
|---|---|---|
| **Any platform lane** | the full track as written below | threat model at P3, controls + policy-as-code at P4, recorded adversarial run at P5, SLOs + exercised rollback at P6, telemetry + incident path at P7 |
| **Model-building, with an LLM or agent in it** (incl. LLM fine-tuning) | full on the AI surface, light on the cluster surface | threat model covering training-data provenance, model supply chain, and inference-time injection; the adversarial run at P5; `M`-canon release gates. Cluster and network items are **N/A, recorded as such** |
| **Model-building, no LLM or agent** (cv · tabular · time-series) | the data and model-governance floor only | data provenance and licensing (`D`), leakage discipline, PII handling, dependency and weight provenance (`C`), model card and release decision (`M`). Threat model required only if the data is regulated or personal |

**"N/A for this archetype" is a valid gate answer and must be written down as one.** What is not
valid is silence — an item that was never considered reads identically to one that was considered
and dismissed, and only one of those is safe.

The track maps onto NIST AI RMF's four functions without adding a parallel ceremony:

| AI RMF function | Where it already lives | Enforced by |
|---|---|---|
| **GOVERN** | the policy canon in `.claude/memory/policy/` + its decision logs | `governance` skill · `/gate` |
| **MAP** | P1 security posture · P3 threat model | `/threat-model` · `threat-modeler` |
| **MEASURE** | P5 evaluation + adversarial run | `/redteam` · `agent-evaluation` |
| **MANAGE** | P6 SLOs and controls · P7 monitoring and incidents | `/slo` · `/compliance` · `/postmortem` |

Four rules make it mechanical rather than aspirational, mirroring §3.8:

- **The threat model is a file, and it is dated.** `.claude/memory/process/threat-model.md`. A
  threat model predating the current architecture is **unchecked, not checked** — and
  `session-orient.py` surfaces its age at every session start so it cannot quietly rot.
- **A control is a mechanism, not a sentence.** "We validate input" does not check a box; a canon
  rule plus a file, a hook, a policy, or a test does. `control-coverage.md` records which, and
  **"not evidenced" is an honest and expected status** — an overclaimed control is worse than a
  missing one, because it stops anyone looking.
- **An expired exception is gate debt.** Every entry in a `*-decision-log.md` carries a review date.
  Past it, the exception was accepted as temporary and has become permanent by default — which is
  precisely what a gate exists to catch.
- **Evidence is dated.** A red-team run, an exercised rollback, a control assessment: each is
  evidence of a moment, not a permanent property. Old evidence is re-gathered, not re-cited.

**Guardrails vs boundary, restated because it governs how to read all of the above:** the hooks in
`.claude/hooks/` stop the common accident cheaply and loudly; they are not a sandbox against an
adversary. The boundaries are the permission system, the IAM policy, the RBAC binding, and admission
control. Never treat a green hook as clearance (`security.md` S1).

### 3.10 Incidents
An incident is a phase interrupt, not a phase. It suspends forward gate movement and has its own
loop — `reliability.md` `R7`/`R8` carry the rules, `/postmortem` produces the record:

1. **Mitigate first, diagnose second.** Restore service, then find out why. **The exception is a
   security incident**, where evidence is preserved before remediating — a real tension the incident
   commander resolves consciously rather than by default.
2. **One named commander**, roles named explicitly, and a timeline written *as it happens* — it will
   not be reconstructable afterwards.
3. **Postmortem above the agreed severity**, blameless, producing actions with owners tracked in the
   risk register. Actions without an owner and a tracking entry are wishes.
4. **The loop closes back into the process:** postmortem actions become risk-register rows; security
   findings feed `/threat-model`; a missed detection becomes an observability gap; and if the same
   class recurs, Part V says amend this document.

---

## Part IV — Templates (copy-paste)

### T1 — Problem Statement (one page, Phase 1)
```
PROJECT: ____________________  DATE: ________  OWNER: ________
PREDICTION TARGET: What exactly is being predicted, at what moment in time?
CONSUMER & DECISION: Who uses the output, and what decision does it change?
CONSTRAINTS: Deadline / data access / compute / budget
SUCCESS METRIC: Metric + threshold + baseline it must beat
NON-ML BENCHMARK: The simplest heuristic a human could apply
KILL CRITERIA: The result that means stop or pivot
COMPUTE BUDGET: GPU-hours available before deadline · est. cost of one training run · runs the plan implies
FEASIBILITY NOTES: Why the data plausibly supports this
```

### T2 — Source Inventory (Phase 2, one row per source)
```
| Source | What it provides | Access/auth | Rate limits | License/ToS | Update cadence | Verified (date) |
|--------|------------------|-------------|-------------|-------------|----------------|-----------------|
```

### T3 — Decision Log
```
| Date | Decision | Alternatives considered | Rationale |
|------|----------|-------------------------|-----------|
```

### T4 — Risk Register
```
| # | Risk | Likelihood | Impact | Mitigation | Status |
|---|------|-----------|--------|------------|--------|
```

### T5 — Feature Dictionary (one row per feature)
```
| Feature | Definition / formula | Source tables | Hypothesis (why signal?) | Leakage review | Added |
|---------|---------------------|---------------|--------------------------|----------------|-------|
```

### T6 — Experiment Log
```
| Date | Data snapshot | Feature set | Model + params | Metric(s) | Takeaway |
|------|--------------|-------------|----------------|-----------|----------|
```

### T7 — Retrospective (Phase 6)
```
WHAT THE PROCESS CAUGHT: gates that saved us from something
WHAT THE PROCESS MISSED: problems no gate covered
WASTED MOTION: work that a better process would have prevented
GATE EDITS: specific changes to PROCESS.md (add/modify/remove a gate or template)
CARRY-FORWARD: parking-lot items promoted to the next project
VERSION BUMP: old → new, one-line changelog entry
```

### T8 — Annotation Spec (Phase 2, when this project produces labels)
```
TASK: What is being labeled (classes / boxes / masks / …), on what data
CLASSES: One-line definition per class — sharp enough that two strangers agree
BOUNDARY RULES: Rulings for occlusion, truncation, crowding, and each known ambiguous case
DO NOT LABEL: Explicit exclusions
EXAMPLES: Links to canonical positive / negative / hard examples
IAA PILOT: Batch size · annotators · agreement metric (κ / IoU-agreement) · threshold (written BEFORE measuring) · measured value + date
LABEL AUDIT: Sample size · label error rate · date · verdict (acceptable vs. the success-metric margin?)
GOLD SET: Where it lives · size · how drift is checked against it
```

### Scope Ledger
```
V1 (CONTRACT):
- ...

PARKING LOT (requires written promotion gate):
- ...
```

---

### T9 — Threat Model (P3, refreshed when the design moves)
```
Version / date:      (undated == assumed current == wrong)
Scope:               what is modelled
OUT of scope:        say it — an unstated exclusion reads as an oversight

Trust boundaries:    # | boundary | what crosses | who can write on the untrusted side
Assets:              asset | where it lives | why an attacker wants it
Threats:             # | boundary | threat | framework id | likelihood | impact |
                     detectable? | decision | control LOCATION (canon rule + file)
Gaps:                threats with no control  <- the section that gets acted on
Accepted risks:      risk | why | owner | review by   (mirrored to the risk register)
Changed since:       what moved, and why
```
Every threat ends in mitigated / accepted / transferred / eliminated. A threat with none of those is
an unfinished sentence.

### T10 — SLI / SLO Sheet (P6)
```
Service | SLI | measured where | target | window | owner | CONSEQUENCE when the budget is spent
```
The consequence column is the one that matters: an SLO with no agreed consequence is a dashboard.
Agree it when the SLO is set — the conversation is uncomfortable enough that it never happens later.
For an LLM-backed service the minimum set is availability, latency p95/p99, time-to-first-token
(separately, for streaming), and a **quality** SLI — a 200 with degraded output is a failure that
looks healthy.

### T11 — Incident Postmortem (blameless)
```
Date | severity | duration | commander | detected by
Impact:               who, how long, how badly — quantified
Timeline:             from evidence, incl. TIME TO DETECTION
Contributing factors: what made it possible / slow to detect / hard to fix
What went well:       incl. the controls that worked — they need defending
Actions:              action | prevent-detect-reduce | owner | tracked as
```
No names attached to mistakes. **"Human error" is not a root cause** — it is the starting point for
asking what made the error easy and why nothing caught it.

### T12 — Control Coverage (P6, refreshed before any assessment)
```
Rule | status | evidence (path / mechanism) | notes
status ∈ Enforced | Implemented | Documented | Not applicable (with reason) | Not evidenced
```
A rule is only Implemented if you can point at something. This is the file a questionnaire gets
answered from; the crosswalk is only an index. Nothing here has been certified against any framework.

### T13 — Agent Authority Declaration (P3, reviewed whenever a tool is added)
```
Agent | identity | tool | scope/constraint | REACHES (blast radius) | reversible? | human gate
Actions requiring a human:  action class | why irreversible | approver | what the prompt must show
Budgets:                    tokens | cost | wall-clock | tool calls | depth — each failing CLOSED
MCP servers:                server | pin | tools exposed | tools GRANTED | creds+scope | last review
```
If you cannot fill "reaches", the grant is not understood well enough to make. This is the file the
`guard-agent-config.py` hook checks tool-granting edits against — which is what makes least agency
erode visibly, as a diff, instead of silently.

---

## Part V — The Meta-Loop

The artifact of any single project is disposable. The asset is the process that produced it. So the process must improve on the same cadence as the projects:

1. Ship (P6 gate passes)
2. Retro (T7)
3. **Edit this document** — add, sharpen, or delete gates based on what actually happened
4. Bump the version, one-line changelog entry below
5. Next project starts from the improved version

Run this loop across three or four projects and the result is a personal methodology with provenance — which is precisely the artifact that distinguishes a lead from a senior IC. In interviews, this document *is* the answer to "how do you run a project?"

### Changelog
```
1.1.0 (2026-07-26) — The §3.9 security & reliability track scales by archetype instead of applying
                      uniformly: a table sizes it three ways (any platform lane; model-building with
                      an LLM or agent in it; model-building without one), and `N/A — <archetype>`
                      becomes a valid recorded gate answer that /gate writes explicitly. A uniform
                      track asks a CV project about admission control, which is how a checklist loses
                      legitimacy; silence, however, is still not an answer. Adds §2.1, mapping the
                      data-science phase names onto platform work, and retitles the document and
                      Appendix A to name both families.
1.0.0 (2026-07-25) — AI-platform layer. Security & reliability become a track through every phase
                      (§3.9) rather than a late review: threat model at P3, controls + policy-as-code
                      at P4, recorded adversarial run at P5, SLOs + exercised rollback + signed
                      artifacts at P6, telemetry + incident path at P7. Adds §3.10 (incidents as a
                      phase interrupt) and T9-T13 (threat model, SLO sheet, postmortem, control
                      coverage, agent authority). Part I gains five lineage rows: NIST SSDF/800-218A,
                      NIST AI RMF, STRIDE/ATLAS/OWASP threat modelling, Google SRE, DevSecOps/SLSA.
                      Phase numbers and names are deliberately UNCHANGED — the lifecycle was already
                      archetype-agnostic, and renaming would have broken every cross-reference in the
                      skills for no gain. Also corrects the header version, which read 0.2.0 while
                      this changelog was at 0.3.0.
0.3.0 (2026-07-19) — Predictive-signal go/no-go: a train-only single-feature-AUC / MI /
                     multivariate screen becomes a P2 key activity + a P3 exit-gate item, so
                     "is there enough signal to fund P4/P5?" is answered in writing before the
                     modeling spend, not discovered after it (dota2 dogfood lesson; see `eda`).
0.2.0 (2026-07-18) — Gap fixes: labeling & annotation discipline (P2 conditional activities +
                     gate items, template T8, principle 7, data-centric AI lineage row);
                     compute budgeting (P1 feasibility math + gate + T1 line, P5 experiment
                     budget + gate); gate enforcement made mechanical (§3.8, principle 8 —
                     phase-state file + /gate review); CV reading of "feature" noted in P4.
0.1.0 (2026-07-18) — Initial synthesis: CRISP-DM spine + TDSP team layer +
                     CRISP-ML(Q) QA/monitoring + MLOps reproducibility +
                     Lean kill criteria + Cookiecutter layout.
```

---

## Appendix A — Worked example (Platform family): internal document-QA agent platform (v1)

A partial fill to show intended use. Note that the security artifacts (T9, T13) are filled at P3
alongside the architecture, not retrofitted before launch.

**T1 Problem Statement (abridged)**
- **Target:** answer employee questions from the internal wiki + policy docs, with citations, and
  file a ticket when it cannot answer
- **Consumer/decision:** internal staff; replaces the search-then-skim loop. Success is measured by
  *deflected support tickets*, not by answer plausibility
- **Constraints:** one quarter; two engineers; the wiki is 40k pages across 6 spaces with per-space
  access control that the platform **must** honour
- **Success metric:** ≥70% task success on a 150-question hand-built eval set, **0 cross-space
  disclosures**, p95 time-to-first-token < 2s
- **Non-ML benchmark:** existing wiki keyword search, scored on the same eval set — if RAG cannot
  beat it, the retrieval layer is the problem, not the model
- **Kill criteria:** if v1 cannot beat keyword search on the eval set, stop and fix retrieval before
  adding an agent loop or a bigger model

**Risk register (top entries)**
| # | Risk | Source | Mitigation | Review by |
|---|------|--------|------------|-----------|
| 1 | Cross-space disclosure — a user sees a document their wiki permissions forbid | Threat model | Tenant/space filter in the retrieval query, not the prompt (`D8`); cross-space negative tests in CI | ongoing |
| 2 | Indirect injection via a wiki page anyone can edit | Threat model | Least agency — the agent has no write tools (`AI2`); retrieved content delimited and labelled (`AI1`) | ongoing |
| 3 | Answers confidently wrong on policy questions with legal weight | P1 framing | Groundedness metric + mandatory citations; refusal path when context is insufficient | P5 gate |
| 4 | Embedding model updated by the provider, silently changing retrieval | Threat model | Pin the model version (`M14`); reindex is a planned migration, not a surprise | P6 gate |

**Scope ledger**
- **v1:** read-only Q&A over 2 of the 6 spaces, citations required, no write actions
- **Parking lot:** ticket filing (needs `AI3` human gate), the remaining 4 spaces, conversational
  memory (adds `ASI06` surface), Slack integration, multi-step research agent

**T9 Threat model (abridged — the top three, each driven to a decision)**
| # | Boundary | Threat | Framework | Decision | Control location |
|---|---|---|---|---|---|
| 1 | retrieved document → prompt | A wiki page containing instructions redirects the agent | LLM01 / ASI01 | **Mitigated** | `AI2` (no write tools) + delimiting in `src/rag/prompt.py:40` |
| 2 | retriever → user | Retrieval returns a document from a space the user cannot read | ASI03 / LLM02 | **Mitigated** | `D8`, filter in `src/rag/retrieve.py:22`; negative test `tests/test_space_isolation.py` |
| 3 | agent → wiki API | The agent's service account can read all 6 spaces, not just the user's | ASI03 | **Accepted, v1** | Owner: platform lead. Compensating: query-time filter (#2). Review by: before space 3 is added |

*Out of scope for v1: the wiki itself (upstream system), and the identity provider.*

**T13 Agent authority**
| Agent | Tool | Scope | Reaches | Reversible | Human gate |
|---|---|---|---|---|---|
| `wiki-qa` | `search_wiki(query, space_ids)` | space_ids from the caller's session, never a parameter | wiki read API, 2 spaces | yes (read-only) | no |
| `wiki-qa` | `get_page(page_id)` | re-checks the caller's permission server-side (`I4`) | wiki read API | yes | no |

Budgets: 8k tokens/run · $0.05/run · 30s wall-clock · 6 tool calls · depth 1 — all failing **closed**.
No write tools in v1; ticket filing is parked precisely because it would need an `AI3` human gate.

---

## Appendix B — References & further reading

- CRISP-DM 1.0: Chapman et al., *CRISP-DM Step-by-Step Data Mining Guide* (2000)
- Fayyad, Piatetsky-Shapiro, Smyth — *From Data Mining to Knowledge Discovery in Databases*, AI Magazine (1996) — the KDD process
- Microsoft — *Team Data Science Process* documentation (Microsoft Learn, Azure Architecture Center) and the Azure/Microsoft-TDSP GitHub repo
- Studer et al. — *Towards CRISP-ML(Q): A Machine Learning Process Model with Quality Assurance Methodology* (arXiv:2003.05155; MDPI MAKE, 2021); practitioner summary at ml-ops.org
- Sculley et al. — *Hidden Technical Debt in Machine Learning Systems* (NeurIPS 2015)
- Northcutt, Athalye, Mueller — *Pervasive Label Errors in Test Sets Destabilize Machine Learning Benchmarks* (NeurIPS 2021) — why label error rates get measured
- Google — *MLOps: Continuous delivery and automation pipelines in machine learning* (maturity levels 0–2); *Rules of ML*
- DrivenData — *Cookiecutter Data Science* (repo layout convention)
- datascience-pm.com — framework adoption surveys and framework summaries (CRISP-DM, TDSP, SEMMA comparisons)
