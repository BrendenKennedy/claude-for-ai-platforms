# Google SRE — the reliability practice canon

**Identity:** Google · *Site Reliability Engineering* (2016), *The Site Reliability Workbook* (2018),
*Building Secure and Reliable Systems* (2020) · https://sre.google/books/
**Verified:** 2026-07-25. Books, not a versioned standard — freely readable at the publisher. The
mechanics below (SLI/SLO/error budget, blameless postmortem, toil) are stable and widely adopted
beyond Google.
**Canon citing it:** `reliability.md` (R1–R8)

> Where the other documents in this directory tell you how to keep a system from being attacked, this
> one tells you how to keep it from falling over — and, more usefully, how to decide how much
> reliability is enough. It is the source of essentially every mechanism in `reliability.md`.

## The mechanics we take

| Mechanic | What it is |
|---|---|
| **SLI** | A quantitative measure of service behaviour users actually experience — availability, latency at a percentile, correctness, freshness. Measured at the point closest to the user. |
| **SLO** | A target for an SLI over a window: *99.9% of requests succeed over 28 days*. The commitment. |
| **Error budget** | `1 − SLO`. The permitted unreliability. Budget remaining → ship features. Budget exhausted → reliability work takes priority. |
| **Blameless postmortem** | A written account of an incident focused on the systemic causes, producing tracked actions. Blame suppresses the reporting the process depends on. |
| **Toil** | Manual, repetitive, automatable, tactical work that scales with load. Bounded deliberately, because unbounded toil consumes the capacity that would remove it. |
| **Graceful degradation** | Shed load and reduce function rather than fail wholesale — serve stale, serve smaller, serve fewer. |
| **Defense in depth / no single point of failure** | From *Building Secure and Reliable Systems*, the volume that argues security and reliability are the same discipline seen from two sides. |

**The error budget is the important idea**, and the one most often adopted in name only. It converts
"how reliable should we be?" from a standing argument between engineering and product into an
arithmetic fact with an agreed consequence. An SLO with no consequence attached when it is missed is
a dashboard, not an objective.

## Why an AI platform needs this specifically

LLM-backed services fail in ways classic web services do not, and the SRE mechanics need translating
rather than copying:

- **Latency is heavy-tailed and multi-modal.** A mean is meaningless; SLIs are p95/p99, and streaming
  services need time-to-first-token as a separate SLI from total completion time.
- **"Available" is insufficient.** A service returning 200 with degraded output is failing while
  looking healthy. Quality is an SLI (`agent-evaluation` supplies the measurement).
- **Cost is a reliability concern.** Unbounded token consumption is `LLM10`, and it is also how a
  budget disappears overnight. Cost per request belongs alongside latency.
- **Dependencies are third-party model APIs** with their own outages and rate limits, which makes
  `R4` (timeouts, backoff with jitter, circuit breakers) and `R5` (degrade — fall back to a smaller
  model, a cached answer, or an honest refusal) load-bearing rather than theoretical.

## What we adopt

- **SLI/SLO/error-budget mechanics in full** (`R1`, `R2`), including the consequence: the budget
  governs release velocity, and that is written into the P6 gate.
- **Blameless postmortems producing tracked actions** (`R8`) — `/postmortem` and
  `memory/incidents/`. Actions with no owner and no tracking are the failure mode.
- **Every alert points to a runbook** (`R6`). An alert without one is an interruption.
- **Incident command with a written timeline** (`R7`).
- **Graceful degradation as a design requirement** (`R5`), not an incident-time improvisation.
- ***Building Secure and Reliable Systems*'s central claim** — that security and reliability trade
  against each other and must be designed together — is the reason this scaffold puts `reliability.md`
  in the policy canon alongside the security domains rather than treating SRE as a separate concern.

## What we leave

- **Google-scale organisational structure.** Dedicated SRE teams, the error-budget-triggered handback
  between SRE and dev, and the 50% cap on operational work assume an org shape most projects don't
  have. The mechanics survive without the org chart; canon takes the mechanics.
- **Specific tooling.** Borgmon, and its descendants, are not the point.
- **Toil measurement as a gate.** Real discipline, but it needs a team and a quarter to mean
  anything.

## How it lands here

| Mechanic | Canon rule | Mechanism |
|---|---|---|
| SLI definition and measurement | `R1` | `observability` · `reliability-sre` · `/slo` |
| SLO + error budget | `R1`, `R2` | `memory/process/slo-register.md` · P6 exit gate |
| Reversible change | `R3` | `gitops` · `kubernetes` (rollout/rollback) |
| Timeouts, retries, circuit breakers | `R4` | `reliability-sre` · `serving` |
| Graceful degradation | `R5` | `reliability-sre` · `guardrails` (fallback paths) |
| Runbook per alert | `R6` | `templates/runbook.md` · `observability` |
| Incident command | `R7` | `reliability-sre` · `sre-analyst` agent |
| Blameless postmortem | `R8` | `/postmortem` · `templates/postmortem.md` · `memory/incidents/` |

## Gotcha

**An SLO nobody is willing to act on is worse than none** — it manufactures the appearance of a
reliability practice while every decision continues to be made on vibes. Before writing an SLO, get
agreement on what happens when the budget is spent. `/slo` asks for that consequence explicitly, and
`reliability.md` `R2` states it as a rule, because the question is uncomfortable enough to be skipped
every time it isn't forced.
