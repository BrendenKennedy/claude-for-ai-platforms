---
name: workflow-orchestration
description: >
  Scheduled and event-driven workflow engines — Airflow, Dagster, Prefect, Temporal, Argo Workflows —
  and which is actually for what. Carries: choosing between them honestly, DAG design with idempotent
  tasks so a rerun is safe, backfills, why time-based dependencies rot and sensors beat sleeps,
  retries held to the R4 discipline, task-level resource and concurrency limits, and **the
  orchestrator as a high-privilege system that runs arbitrary code on a schedule** — per-task
  least-privilege identity, secrets never as task parameters, and the executor as a trust boundary
  the threat model must include. Load when scheduling recurring work, building an ingestion or
  retraining pipeline, choosing an engine, or debugging a stuck/duplicated/silently-failing run.
  Triggers: airflow, dagster, prefect, temporal, argo workflows, DAG, workflow engine, scheduler,
  cron job, backfill, task dependency, sensor, idempotent task, pipeline run, ETL schedule,
  retraining pipeline, stuck task, catchup, executor. ML-cascade seams are `pipelines`; CI pipelines
  are `secure-cicd`; queues are `caching-and-queues`.
---

# workflow-orchestration — scheduled work, and the privileged system that runs it

**Pinned:** airflow, dagster, prefect, temporal, argo-workflows — unpinned · authored 2026-07 · run
`/skill-update workflow-orchestration` once an engine is chosen. These APIs move; verify against the
installed version before copying anything.

> On-demand: load this when work runs on a schedule or in response to an event. **`pipelines` is a
> different thing** — it covers ML *cascade seams*, where one model's output feeds the next; this
> covers the engine that runs jobs. CI/CD pipelines are `secure-cicd`; message-driven work is
> `caching-and-queues`; running tasks as k8s pods is `kubernetes`. Canon: `identity-and-access.md`
> `I3` (per-task identity), `security.md` `S2`/`S7`, `reliability.md` `R4`/`R6`.

## When this applies

Scheduling recurring work. Building ingestion, indexing, or retraining pipelines. Choosing an engine.
Debugging a run that is stuck, duplicated, or failing silently.

## First: do you need one?

A `CronJob` in Kubernetes plus good logging handles a surprising amount. An orchestrator earns itself
when you have **dependencies between tasks**, **backfills**, **retries with state**, or **enough jobs
that "which one failed and what did it block?" is a real question**. One nightly script does not
need Airflow.

## Choosing an engine

| Engine | Actually for | Watch out for |
|---|---|---|
| **Airflow** | Scheduled batch ETL. The incumbent — largest ecosystem, most operators, most hiring pool | Heavy to operate; scheduling semantics (`catchup`, `execution_date`) surprise everyone once |
| **Dagster** | Data platforms where **assets**, not tasks, are the unit. Strong typing, lineage, and local testability | Asset-centric model is a genuine rethink if you arrive from Airflow |
| **Prefect** | Python-native workflows with minimal ceremony; dynamic, runtime-determined DAGs | Less opinionated, so conventions are yours to enforce |
| **Temporal** | **Durable execution** — long-running, stateful, resumable workflows measured in hours or months. Not a batch scheduler | Different mental model entirely: code is the workflow, and it must be deterministic |
| **Argo Workflows** | Container-native DAGs on Kubernetes. Every step is a pod | YAML-defined; k8s-only; you own the cluster concerns |

**For agentic platforms specifically:** Temporal is worth serious consideration where a workflow
involves long-running agent runs, human approval steps (`ai-security.md` `AI3`), and resumption after
failure — its durable-execution model fits that shape far better than a batch scheduler retrying a
task from the start.

## DAG design

**Idempotency is the whole discipline.** Every task must be safe to rerun, because it *will* be
rerun — by a retry, a backfill, or a human clicking the button.

- **Parameterise by the data interval, never by "now".** `datetime.now()` inside a task means a
  rerun processes different data than the original, which silently breaks backfills and makes
  failures unreproducible.
- **Overwrite or upsert; don't append.** An appending task run twice doubles the data. Write to a
  partition keyed by the interval and replace it, or upsert on a natural key
  (`relational-stores`).
- **Write atomically.** Stage to a temporary location, then move or commit — a task that fails
  halfway should leave no partial output for a downstream task to consume.
- **Tasks are small and single-purpose.** A 400-line task that does everything can only be retried as
  a unit, and its failure tells you nothing.
- **Pass references, not data.** Move a path or a key between tasks, not a DataFrame — the metadata
  database is not a data store.

**Sensors and events beat sleeps.** "Run at 02:00 because upstream usually finishes by 01:30" is a
dependency encoded as a guess, and it rots the first time upstream is slow. Wait for the actual
signal — and give the sensor a **timeout**, or a stuck upstream becomes a worker held forever.

**Backfills** need the same care as the forward path: bound concurrency (a backfill that runs 90 days
in parallel will take down whatever it reads), and understand your engine's catchup semantics before
you deploy a DAG with a start date in the past — an accidental backfill of a year is a rite of
passage worth skipping.

## Retries — the R4 discipline, applied per task

Exponential backoff **with jitter**, a bounded attempt count, and a task-level timeout. Retry only
what is idempotent, and never retry a failure that will fail identically — a bad config or a schema
mismatch just burns the retry budget and delays the alert.

Set **concurrency limits** per task and per pool. An unbounded fan-out that opens 500 database
connections or 500 concurrent LLM calls is a self-inflicted outage
(`relational-stores`, `ai-security.md` `AI9`).

## The security part — this is why the skill exists

**An orchestrator is one of the most privileged systems you will run**: it executes arbitrary code,
on a schedule, unattended, with credentials to every system in the pipeline. It is also, reliably,
one nobody threat-models. Treat it the way `secure-cicd` treats CI (`supply-chain.md` `C6`), because
the threat is the same shape.

- **Per-task least-privilege identity** (`I3`). Not one omnipotent service account for every DAG. On
  Kubernetes, a ServiceAccount per workflow with IRSA / Workload Identity; the ingestion task should
  not hold the deployment credential.
- **Secrets from the secret backend at runtime, never as task parameters or DAG-file literals.**
  Parameters are rendered into the UI, the logs, and the metadata database
  (`secrets-management`, `S2`).
- **The DAG directory is executable code.** Anyone who can write to it can run anything as the
  orchestrator. Version-control it, review it, and deploy it like application code — not by editing
  files on the scheduler.
- **The web UI is an admin console.** Authenticated (`I2`), authorized by role, never
  internet-exposed (`P11`). It can trigger runs, read logs and variables, and often edit connections.
- **Task logs are telemetry with the same rules as any other** (`S6`) — they routinely capture
  credentials and PII from exceptions.
- **The executor is a trust boundary.** Note it in `/threat-model`: what can a compromised task
  reach? On a shared worker, tasks share a host and often a filesystem; the k8s executor gives each
  task a pod boundary, which is a real security argument for it beyond scaling.

## Operating

- **Every DAG has an owner and an alert route.** A failing DAG nobody is paged for is a data outage
  discovered by a downstream consumer, days later (`reliability.md` `R6`).
- **Alert on the right things**: task failure, but also **SLA/freshness misses** — a DAG that
  succeeds while producing nothing is the failure mode dashboards hide.
- **A runbook per DAG** (`templates/runbook.md`): what it does, what breaks it, whether it is safe to
  rerun, and how to backfill.
- **The metadata database needs care** — it grows, and log retention needs a policy. An unmaintained
  Airflow metadata DB is a common self-inflicted incident.

## Gotchas

- **`datetime.now()` in a task.** The single most common source of unreproducible pipeline runs.
- **Accidental catchup.** A start date in the past plus catchup enabled schedules everything since.
- **Top-level code in a DAG file.** The scheduler parses DAG files constantly — an API call or a
  database query at module level runs every parse, not every run.
- **Passing DataFrames between tasks.** Pass paths.
- **Sensors without timeouts**, quietly occupying every worker slot.
- **One service account for everything.** Convenient, and it means a compromise of the least
  important task owns the most important credential.
- **Retrying a non-idempotent task.** Duplicate rows, double charges, double emails.
- **Treating a DAG's success as data correctness.** It ran. That is all it means — freshness and
  row-count checks are separate assertions, and they belong in the DAG.
