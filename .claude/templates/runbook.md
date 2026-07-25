# Runbook: <alert or scenario name>

> One per alert. `reliability.md` `R6`: **an alert without a runbook is an interruption, not an
> alert.** Lives beside the service; updated when the incident it describes happens differently.
>
> Write it for someone woken at 03:00 who did not build this. That is the actual audience, and it
> is why "check the logs" is not a step.

**Alert:** _the exact alert name, so this is findable from the page_
**SLO it protects:** _which SLI is burning — see `slo-register.md`_
**Severity:** — · **Owner:** — · **Last exercised:** _(a runbook nobody has run is a draft)_

## What this means

_One paragraph: what is broken from the user's point of view, and what is not. Include what is
**still working**, so the responder doesn't over-escalate._

## Is it real?

_First question, because acting on a false page is how outages get made. What distinguishes a real
incident from a flapping alert or a monitoring failure._

- [ ] _check 1 — with the exact command or dashboard link_
- [ ] _check 2_

## Mitigate first

_**Restore service, then diagnose** (`reliability.md`). Ordered, most likely first. Each step says
what it does, what it costs, and how to tell whether it worked._

1. **_Action_** — _what it does · risk · how to confirm it worked_
2. **Roll back** — `kubectl rollout undo deploy/<name> -n <ns>` or revert the GitOps commit.
   The reversal is a mechanism, not a plan (`R3`) — if it has never been exercised, say so here.
3. **Shed load / degrade** — _which fallback, and what users will see (`R5`)_

> **Exception:** if this looks like a **security** incident, preserve evidence *before* remediating,
> and page the security owner. That tension is real and the incident commander decides it
> consciously (`R7`).

## Then diagnose

_Where to look, in order. Name the dashboards and the queries — a responder should not have to
invent them._

- Traces: _link / query_
- Metrics: _link / query_
- Logs: _query, with the `trace_id` correlation_
- Recent changes: deploys, config, feature flags, **prompt or model changes** (`M15`, `M14` — a
  provider updating a model underneath you looks exactly like your regression)

## Common causes seen before

| Symptom | Cause | Fix |
|---|---|---|

## Escalate

_When, and to whom. A runbook that never says "stop and get help" produces heroics at 04:00._

- Escalate if: _condition_
- To: _person / rota_

## After

- [ ] Timeline captured (`R7`) — written **as it happened**, not reconstructed
- [ ] Error budget impact recorded in `slo-register.md`
- [ ] Postmortem if above the severity threshold → `/postmortem`
- [ ] **This runbook updated** if reality differed from what it said
