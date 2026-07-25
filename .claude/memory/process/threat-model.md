# Threat model

> Live state for the `threat-modeling` skill and `PROCESS.md` T9. Written by `/threat-model` (via
> the `threat-modeler` agent), read at every session start by `session-orient.py`, and demanded as
> evidence by the P3 gate onward.
>
> **A threat model with no date is assumed current and isn't.** Keep the version line accurate;
> the orientation hook surfaces its age precisely so it can't quietly rot.

**Version:** _Not yet written — run `/threat-model` (P3, or earlier during `/setup`)._
**Scope:** —
**Out of scope:** —

## Trust boundaries

_Every place data or control crosses between differently-trusted zones. The ones most often missed
in an AI platform: application→model, model→tool execution, retrieved document→prompt, agent→agent,
CI/CD→production, third-party model API._

| # | Boundary | What crosses it | Who can write on the untrusted side |
|---|---|---|---|

## Assets

_Concrete. "The system" is not an asset. Model weights, retrieval corpus, customer data,
credentials, the system prompt, the audit log._

| Asset | Where it lives | Why an attacker wants it |
|---|---|---|

## Threats

_Every threat ends in a decision. Control location must name a canon rule **and** a place —
`identity-and-access.md I4, enforced in api/authz.py:42`, never "we validate input"._

| # | Boundary | Threat | Framework id | Likelihood | Impact | Detectable? | Decision | Control location |
|---|---|---|---|---|---|---|---|---|

## Gaps

_Threats with no control. This is the section that gets acted on — keep it sharp._

_None recorded yet._

## Accepted risks

_Mirrored into `risk-register.md`; each needs an owner and a review date. An accepted risk past its
review date is gate debt (`/gate` step 3)._

| # | Risk | Why accepted | Owner | Review by |
|---|---|---|---|---|

## Changes since the last version

_—_
