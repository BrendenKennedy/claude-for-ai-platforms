---
description: >
  Define or review service level objectives — pick SLIs users actually feel, set targets with a
  window and an agreed consequence, and record them in the SLO register.
argument-hint: "[service name, or 'review' to assess current status]"
---

Define or review SLOs. Target: **$ARGUMENTS**

@.claude/memory/process/slo-register.md

## Defining a new SLO

1. **Pick SLIs the user experiences**, measured as close to them as possible — not CPU, not queue
   depth, which are causes. For an LLM-backed service the minimum set:
   - **Availability** — non-5xx / valid requests
   - **Latency p95 and p99** — a mean is meaningless on a heavy-tailed distribution
   - **Time-to-first-token**, separately, for anything streaming
   - **Quality** — task success or judge score from `agent-evaluation`. **A 200 with degraded
     output is a failure that looks healthy**, and this is the SLI teams skip
   - **Cost per request** — tracked alongside, because unbounded consumption is both an
     availability and a budget incident

2. **Set the target from what users need**, not from what you currently achieve. If there's a gap,
   name it — closing it and lowering the target are both legitimate, and pretending there's no gap
   isn't. Each additional nine costs roughly an order of magnitude more.

3. **Ask the question that gets skipped: what happens when the budget is spent?** Get an answer
   before writing the SLO. `reliability.md` `R2` requires the consequence to be agreed in advance —
   an SLO with no consequence is a dashboard, and this conversation is uncomfortable enough that it
   never happens later.

4. **Name an owner and a window** (28 days is the usual default).

5. **Check it's measurable today.** If the telemetry to compute the SLI isn't being emitted, the
   first action is instrumenting it (`observability`) — an SLO you can't measure is a wish. Say so
   rather than writing an aspirational row.

## Reviewing status

Dispatch the `sre-analyst` agent. For each SLO report: current value, budget consumed and
remaining, burn rate, and trend. Then apply `R2` — if a budget is exhausted, say plainly that
reliability work takes priority, and what that means for what's currently planned.

Flag: SLOs with no owner, no consequence, or no telemetry backing them; services with **no** SLO;
and any LLM-backed service with no quality SLI.

## Recording

Write `.claude/memory/process/slo-register.md` (template T10 in `PROCESS.md`) — one row per SLI with
its target, window, owner, consequence, and where it's measured. Any deliberate exception (shipping
with the budget spent, launching without a quality SLI) goes in the `reliability` decision log with
a review date.
