---
name: reliability-sre
description: >
  Site reliability engineering for LLM-backed platforms — defining what "working" means, then
  keeping it that way. Carries: writing an SLI that reflects user experience, SLOs with windows and
  an agreed consequence, error budgets that govern release velocity, the resilience patterns
  (timeouts, bounded retries with backoff+jitter, circuit breakers, bulkheads, load shedding),
  LLM-specific degradation (smaller-model and cached fallbacks, token budgets, queueing), safe
  change and rollback, alerting on burn rate not causes, incident command, and blameless
  postmortems. Load when defining SLOs, hardening a service against dependency failure, designing
  rollback, writing alerts or runbooks, or running/reviewing an incident. Triggers: SLO, SLI,
  error budget, reliability, uptime, availability, latency budget, circuit breaker, retry, backoff,
  timeout, rate limit, graceful degradation, fallback, load shedding, capacity, on-call, alert
  fatigue, runbook, incident, postmortem, outage, rollback, canary, blast radius, SRE. Telemetry
  itself is `observability`; the musts are `policy/reliability.md`.
---

# reliability-sre — deciding how reliable is enough, then engineering to it

> On-demand: load this when reliability is the question. What a system *emits* belongs to
> `observability`; what a model *scores* belongs to `agent-evaluation`; the non-negotiable rules are
> canon at `.claude/memory/policy/reliability.md` (`R1`–`R8`). Security and reliability trade against
> each other constantly — that's why they share a canon directory, and why a rate limit shows up in
> both.

## When this applies

Before shipping to users: defining what working means. During design: what happens when a dependency
fails. During an incident. After one. Whenever someone says "it should be reliable" without a number.

## SLIs, SLOs, error budgets

**SLI** — a ratio of good events to valid events, measured where the *user* experiences it. Not CPU,
not queue depth: those are causes.

**SLO** — a target for an SLI over a window, with an owner. *99.5% of requests succeed over 28 days.*

**Error budget** — `1 − SLO`. At 99.5% over 28 days, that's ~3.4 hours of failure you are *permitted*.
Budget left → ship. Budget spent → reliability work takes priority (`R2`).

**The consequence is agreed when the SLO is set, not when it's first breached.** An SLO with no
agreed consequence is a dashboard. `/slo` asks for it explicitly because the conversation is
uncomfortable enough to be skipped every time it isn't forced.

### SLIs for LLM-backed services

The generic set is insufficient here. The minimum:

| SLI | Why this one |
|---|---|
| **Availability** — non-5xx / valid requests | The baseline |
| **Latency p95 and p99** | Means are meaningless on a heavy-tailed, multi-modal distribution |
| **Time-to-first-token** (streaming) | What users actually feel; total completion time hides it |
| **Quality** — task success or judge score, from `agent-evaluation` | **A 200 with degraded output is a failure that looks healthy.** This is the SLI teams skip and the one that matters most |
| **Cost per request** | Not availability, but it's how unbounded consumption (`LLM10`) becomes visible before the invoice |

Set targets from what users need, not from what you currently achieve — then close the gap or change
the target deliberately. Nines are expensive and each one costs roughly an order of magnitude more
than the last; 99.9% is a real commitment, 99.999% is a different company.

## Resilience patterns

Every remote call: a timeout, bounded retries, a circuit breaker (`R4`). No exceptions, and "the
client library has defaults" is not an answer — check them, they're usually infinite.

| Pattern | Rule |
|---|---|
| **Timeout** | Always set, always shorter than the caller's. Cascading timeouts must shrink inward or the outer one is meaningless. |
| **Retry** | Only idempotent operations. Capped attempts. **Exponential backoff with jitter** — without jitter you build a synchronised retry storm. Never retry a request that failed for being too expensive. |
| **Circuit breaker** | After N failures, stop calling and fail fast for a cooldown. Protects the *dependency* as much as you — retrying into a struggling service is how you keep it down. |
| **Bulkhead** | Bounded concurrency per dependency, so one slow backend can't consume every worker. |
| **Load shedding** | Reject early with a clear signal when overloaded. Uniform slowness is worse than fast failure for a subset. |
| **Hedged requests** | For latency-critical paths: issue a second request at p95 and take the first response. Costs throughput, buys tail latency. |

**Retries plus a circuit breaker is not optional — it's one pattern.** Retries without a breaker
amplify an outage.

## Degrading instead of collapsing

`R5`: every service has a *defined* behaviour when its dependencies fail. Name the fallback; don't
let it be whatever the exception handler does.

The LLM-specific ladder, in preference order:

1. **Retry with backoff** — for transient provider errors and 429s (respect `Retry-After`).
2. **Fail over to another provider or region** — if the prompt is portable and you've evaluated the
   alternate model, not assumed it's equivalent.
3. **Fall back to a smaller/cheaper model** — degraded quality, honestly labelled.
4. **Serve a cached or precomputed answer** — with its staleness visible.
5. **Queue it** — if the workflow tolerates asynchrony.
6. **Refuse honestly** — "this is unavailable right now" beats a confidently wrong answer.

**Label degraded responses**, in the response and in telemetry. A silent quality drop is an outage
you don't measure — and for an agent system it can look like a security incident.

Token and cost budgets are reliability controls as much as security ones: a per-request, per-tenant,
and per-day ceiling that fails closed (`ai-security.md` `AI9`).

## Safe change

`R3` — every production change is reversible and the reversal has been exercised.

- **Versioned artifacts + declared desired state**, so rollback is a mechanism, not a re-deploy and
  a prayer. `gitops` carries the how.
- **Progressive delivery** — canary or blue/green with automatic rollback on SLO burn. Roll forward
  by preference, roll back by capability.
- **Backward-compatible migrations** for at least one release; expand-migrate-contract, never a
  destructive change in the same deploy as the code that needs it.
- **Config and feature flags are changes.** They cause outages at the same rate as code and get
  reviewed and rolled back the same way.
- **Prompt and model changes are changes** (`model-governance.md` `M15`) — evaluated before release,
  and rollable back.

## Alerting

Alert on **symptoms users feel**, via SLO burn rate — not on every cause. Multi-window burn-rate
alerting (a fast window for sharp breakage, a slow one for slow bleeds) gives you urgency without
flapping.

Every alert: points to a runbook, is actionable, and is worth waking someone for (`R6`). If it isn't
all three, it's a dashboard entry. **Alert fatigue is the failure mode** — an ignored page is worse
than no page because it's ignored *reliably*.

## Incidents

`R7` — one named commander, roles named explicitly (comms, investigation), and a **timeline written
as it happens**, because it will not be reconstructable afterwards.

Order of operations: **mitigate first, diagnose second** — restore service, then find out why. The
exception is a security incident, where evidence is preserved before remediating; that's a real
tension and the commander decides it consciously.

`R8` — a blameless postmortem for every incident above the agreed severity. Systemic causes: what
made this possible, what made it slow to detect, what made it hard to fix. Actions get an owner and a
`risk-register.md` entry — actions without both are wishes. `/postmortem` drafts it into
`memory/incidents/`.

## Gotchas

- **Copying nines from a slide.** 99.99% for an internal tool is a cost with no beneficiary.
- **An SLO nobody will act on** manufactures the appearance of a reliability practice while every
  decision is still made on vibes.
- **Measuring at the server.** Server-side latency omits queueing, network, and cold starts — the
  parts users feel.
- **Retry storms.** No jitter, no cap, no breaker: your recovery becomes your second outage.
- **Untested rollback.** A rollback path first exercised during an incident is a plan, not a
  capability.
- **Ignoring cost as a reliability signal.** A runaway agent loop is an availability incident and a
  budget incident simultaneously, and the cost graph usually notices first.
