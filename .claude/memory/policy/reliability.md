# Reliability policy — objectives, change, degradation, and incidents

The canon for the `reliability` domain (registered in the `governance` skill). Universal rules are
concrete; org-specific values are marked `<PLACEHOLDER: …>`. Load this before shipping a service to
users, defining what "working" means for it, changing production, or responding to an incident.

Rules are named (`R1`, `R2`, …) so a gate item or a decision-log entry can cite one. Each carries a
one-line **why**. Bracketed IDs cite the motivating framework — `[SRE]`, `[CSF RS]` — and resolve in
`frameworks/`.

**Why reliability is in the policy canon rather than treated as an operations concern:** security and
reliability trade against each other constantly — rate limiting is both, a circuit breaker is both,
an audit log is both, and a rushed rollback bypasses both. Keeping them in one canon is how those
trades get made deliberately instead of discovered during an incident.

Sibling canon: what to emit is the `observability` skill; what a model *scores* is `agent-evaluation`
and `evaluation`; the phase gates that enforce these rules are `PROCESS.md` §3.9.

## Objectives

**R1 — Every user-facing service has at least one SLI and a written SLO.** The SLI is measured where
the user experiences it, not at the process boundary, and is expressed as a ratio of good events to
valid events. For LLM-backed services the minimum set is **availability, latency at p95/p99 (with
time-to-first-token as a separate SLI for streaming), and a quality SLI** supplied by
`agent-evaluation`. Cost per request is tracked alongside them. SLOs live in
`memory/process/slo-register.md` with their window and their owner.
*Why: without a defined objective, every reliability discussion is an argument about anecdotes, and
"is it fast enough?" has no answer. [SRE]*

**R2 — The error budget governs release velocity, and the consequence is agreed in advance.** Budget
remaining → ship. Budget exhausted → reliability work takes priority over features until it recovers.
The consequence is written down *when the SLO is set*, not negotiated when it is first breached.
*Why: an SLO with no agreed consequence is a dashboard — it manufactures the appearance of a
reliability practice while every decision continues to be made on vibes. [SRE]*

**R5 — Degrade, don't collapse.** Every service has a defined behaviour for when its dependencies
are slow, rate-limited, or down. For LLM-backed paths, name the fallback explicitly: a smaller or
cheaper model, a cached response, a reduced feature, a queued job, or an honest refusal — chosen
deliberately, not whatever the exception handler happens to do. Load shedding is preferable to
uniform slowness. A degraded response is labelled as degraded, including in telemetry.
*Why: third-party model APIs have outages and rate limits you do not control, so the behaviour under
their failure is a design decision you make either deliberately or by accident. [SRE][ASI08]*

## Change

**R3 — Every change to production is reversible, and the reversal has been exercised.** Deployments
roll back by mechanism, not by "redeploy the previous commit and hope": versioned artifacts, declared
desired state, and a tested rollback path. Database migrations are backward-compatible for at least
one release. Configuration and feature flags are changes too, and get the same treatment. An
untested rollback is a plan, not a capability.
*Why: the ability to undo is what converts an incident into an inconvenience, and it is the control
most often assumed rather than verified. [SRE][CSF RC]*

**R4 — Every remote call has a timeout, bounded retries with backoff and jitter, and a circuit
breaker.** No unbounded waits. Retries are only for idempotent operations, are capped, and never
retry a request that is failing because it is too expensive. Concurrency to each dependency is
bounded. Where an agent calls tools or other agents, the same limits apply and compose with
`ai-security.md` `AI9`.
*Why: retry storms and unbounded concurrency turn a dependency's degradation into your outage, and
in a multi-agent system they are also the mechanism by which one failure cascades. [SRE][ASI08]*

## Operations

**R6 — Every alert points to a runbook, and every alert is actionable.** An alert that fires without
a documented response is an interruption. Alerts are on symptoms users feel — SLO burn rate — not on
every cause. Runbooks live beside the service and are updated when the incident they describe
happens differently.
*Why: unactionable alerts train responders to ignore the page, which is the failure mode that makes
the next real one worse. [SRE]*

**R7 — Every incident has a named commander and a written timeline kept as it happens.** One person
coordinates; roles for communication and investigation are named explicitly. The timeline is recorded
live, because it will not be reconstructable afterwards. Severity determines who is told and how
fast. Security incidents follow the same structure, with the additional obligation to preserve
evidence before remediating.
*Why: an uncoordinated response duplicates work, misses handoffs, and produces a postmortem nobody
can write. [SRE][CSF RS][800-53 IR]*

**R8 — Postmortems are blameless, written for every incident above the agreed severity, and produce
tracked actions with owners.** They analyse the systemic causes — what made this possible, what made
it hard to detect, what made it hard to fix — not who typed the command. Actions have an owner and a
tracking entry in `memory/process/risk-register.md`; actions without both are wishes. Postmortems
live in `memory/incidents/`.
*Why: blame suppresses the reporting the process depends on, and untracked actions mean the same
incident recurs having been thoroughly documented. [SRE][CSF RC][800-53 IR-4]*

`<PLACEHOLDER: SLO targets and windows per service, and who agrees them>`
`<PLACEHOLDER: severity definitions, the on-call rotation, and the escalation path>`
`<PLACEHOLDER: the severity threshold above which a written postmortem is required>`

## Recording a judgment call

Irreducible judgment calls — shipping with the error budget spent, an accepted single point of
failure, a service launched without a quality SLI — go in `reliability-decision-log.md` beside this
file. Append-only: *what / which rule / why / review date*. A reversal is a new entry. Created on the
first call; absence means no exception has ever been granted.
