# Control coverage

> Live state for `PROCESS.md` T12. Written by `/compliance` (via the `compliance-mapper` agent).
> **This is the honest file** — `compliance-crosswalk.md` maps rules to frameworks, this records
> what is actually implemented, with evidence. A questionnaire gets answered from here, not there.
>
> ⚠️ **A mapping is not an implementation, and an implementation is not a certification.** Nothing
> in this repo has been certified against any framework. A rule is only recorded as implemented if
> you can point at a file, a hook, a policy, a test, or a configuration — **reporting a rule as
> implemented because canon says it should be is the failure this file exists to prevent.** An
> overclaimed control is worse than a missing one, because it stops anyone looking.

**Last assessed:** _Not yet assessed — run `/compliance`._

## Status legend

| Status | Means |
|---|---|
| **Enforced** | A hook, admission policy, CI gate, or deny-list blocks the violation |
| **Implemented** | Real in the code/config, but nothing stops it regressing |
| **Documented** | Canon states it; nothing implements it |
| **Not applicable** | With a written reason — an unstated N/A is a gap in disguise |
| **Not evidenced** | Looked for it; could not find it |

## Coverage

| Rule | Status | Evidence (path / mechanism) | Notes |
|---|---|---|---|

## Provider-owned controls

_On managed infrastructure, some controls are the provider's (CIS Kubernetes §1–4 on a managed
control plane, physical security, host OS patching). Record **which**, and what they have actually
attested to — "the provider handles it" is only true for the parts they handle._

| Control area | Provider | Their attestation | Verified |
|---|---|---|---|

## Gaps

_Rules that are Documented or Not evidenced, ordered by the severity of what they guard._

_None assessed yet._

## Framework-side gaps

_Controls in the crosswalk that no canon rule addresses. These are the ones a self-assessment
always misses — you can only evidence rules you thought to write._

_None assessed yet._

## Exception register

_Every entry in `.claude/memory/policy/*-decision-log.md` is a coverage caveat. **Expired ones are
gate debt** — they were accepted as temporary and have become permanent by default._

| Rule | Exception | Compensating control | Owner | Review by | Expired? |
|---|---|---|---|---|---|
