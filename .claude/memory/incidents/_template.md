# Incident: <short title>

> Copy to `YYYY-MM-DD-<slug>.md`. `PROCESS.md` T11, canon `reliability.md` `R7`/`R8`.
> Written by `/postmortem`. **Blameless: no names attached to mistakes.** Blame suppresses the
> reporting this whole process depends on.

**Date:** — · **Severity:** — · **Duration:** — · **Commander:** —
**Detected by:** _(alert / user report / someone noticed)_

## Impact

_Who was affected, for how long, how badly. Quantified — requests failed, users affected, error
budget consumed, cost incurred. "Some users saw errors" is not impact._

## Timeline

_Written from evidence, not memory. Include the **time to detection** — the gap between "it broke"
and "we knew" is usually the most actionable number in this document._

| Time (UTC) | What happened / what was observed | What was done |
|---|---|---|

## Contributing factors

_Systemic. **"Human error" is not a root cause** — it is the starting point for asking what made
the error easy and why nothing caught it._

- **What made this possible?** _(the design or configuration that permitted it)_
- **What made it slow to detect?** _(missing alert, wrong SLI, alert fatigue, no telemetry)_
- **What made it hard to fix?** _(no runbook, untested rollback, unclear ownership)_

## What went well

_Including the controls that worked — they need defending in the next prioritisation round, and a
postmortem that only lists failures gets them cut._

## If this was a security incident

- Was evidence preserved before remediation?
- Was a credential involved? **Rotated, not deleted** (`security.md` `S4`) — and checked for use?
- Does the threat model need updating? → `/threat-model`

## Actions

_Each needs an **owner** and a row in `risk-register.md`. Actions without both are wishes (`R8`).
Cover all three categories — a postmortem that only produces prevention actions has ignored two
thirds of the options._

| # | Action | Category (prevent / detect / reduce impact) | Owner | Tracked as |
|---|---|---|---|---|
