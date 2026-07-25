# SLO register

> Live state for `PROCESS.md` T10 and canon `reliability.md` `R1`/`R2`. Written by `/slo`, read by
> `sre-analyst` and `session-orient.py`, and demanded as evidence by the P6 gate.
>
> **The consequence column is the one that matters.** An SLO with no agreed consequence is a
> dashboard — it manufactures the appearance of a reliability practice while every decision is still
> made on vibes. `R2` requires it to be agreed when the SLO is set, because the conversation is
> uncomfortable enough that it never happens later.

**Last reviewed:** _Not yet written — run `/slo`._

## Objectives

| Service | SLI | Measured where | Target | Window | Owner | Consequence when the budget is spent |
|---|---|---|---|---|---|---|

_For an LLM-backed service the minimum set is availability, latency p95/p99, **time-to-first-token**
(separately, for streaming), and a **quality** SLI from `agent-evaluation` — a 200 with degraded
output is a failure that looks healthy. Track cost per request alongside them._

## Current status

_Filled by `/slo review` (dispatches `sre-analyst`)._

| Service | SLI | Current | Budget consumed | Burn rate | Status |
|---|---|---|---|---|---|

## Not yet measurable

_SLIs we want but cannot compute because the telemetry isn't emitted. An SLO you can't measure is a
wish — these are instrumentation work (`observability`), tracked here so they aren't quietly
dropped._

_None recorded._

## Services with no SLO

_Named deliberately. A service that genuinely doesn't need one (an internal batch job, a
throwaway) is fine — recorded, not forgotten._

_None recorded._
