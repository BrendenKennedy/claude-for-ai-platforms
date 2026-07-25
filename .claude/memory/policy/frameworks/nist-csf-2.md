# NIST Cybersecurity Framework 2.0 — the crosswalk spine

**Identity:** NIST · **CSF 2.0** (February 2024) · https://www.nist.gov/cyberframework
**Verified:** 2026-07-25. CSF 2.0 released February 2024, adding GOVERN as a sixth Function and
broadening scope beyond critical infrastructure to organisations of all sizes and sectors.
**Canon citing it:** `reliability.md` (R7, R8) · `compliance-crosswalk.md` (spine)

> The vocabulary almost every other control framework maps to, which is exactly what a crosswalk
> needs. We carry it as the organising spine of `compliance-crosswalk.md` rather than as a source of
> rules — CSF says *what outcomes* to achieve, and the prescriptive documents in this directory say
> how.

## The six Functions

| Function | Outcome |
|---|---|
| **GOVERN** *(new in 2.0)* | Cybersecurity risk strategy, expectations, roles, and policy are established and monitored |
| **IDENTIFY** | Assets, risks, and the current posture are understood |
| **PROTECT** | Safeguards are in place — identity and access, data security, platform security, awareness |
| **DETECT** | Adverse events are found and analysed |
| **RESPOND** | Incidents are managed, contained, communicated, and mitigated |
| **RECOVER** | Assets and operations are restored |

Functions contain Categories (`GV.PO`, `PR.AA`, `DE.CM`, `RS.MA`, …) and Subcategories, which are the
IDs a crosswalk actually targets. **GOVERN's addition in 2.0 is the substantive change** — it
elevated policy, roles, and supply-chain risk management from scattered categories to a first-class
function, which is why it maps so directly onto a policy canon.

## Why it is the crosswalk spine

`compliance-crosswalk.md` maps this repo's rule IDs to external frameworks. It needs one organising
axis, and CSF is the pragmatic choice: SP 800-53, ISO 27001 Annex A, SOC 2 Trust Services Criteria,
and most vendor questionnaires already publish CSF mappings, so a rule mapped to a CSF Subcategory is
transitively mapped to the rest. Choosing CSF as the spine means the crosswalk has one authored
column and several derived ones, instead of six authored columns that drift apart.

## What we adopt

- **The six Functions as the crosswalk's top-level organisation**, and Subcategory IDs as the
  mapping targets.
- **GOVERN as the recognition that the policy canon *is* a control.** `memory/policy/` plus the
  `governance` skill plus `/gate` are what GOVERN asks for; naming that correspondence lets a project
  answer the governance half of an assessment with files rather than assertions.
- **RESPOND and RECOVER as the source of the incident rules** (`R7`, `R8`). CSF is where the
  obligation to have a managed, communicated, documented incident process comes from; Google SRE
  supplies the mechanics.
- **DETECT as the security justification for `observability`.** Continuous monitoring is a control,
  not an operations convenience — which is the argument for why telemetry survives a scope cut.

## What we leave

- **Tiers and Profiles.** CSF's implementation Tiers (Partial → Adaptive) and Current/Target Profile
  assessment are an organisational maturity exercise. A project scaffold has phase gates; running
  both would mean two homes for the same judgment.
- **CSF as a source of specific rules.** Its Subcategories are outcomes — *"PR.AA-05: access
  permissions… incorporate the principles of least privilege"* — not configurations. Canon states the
  configuration; CSF is what it maps to.
- **Any claim of CSF conformance.** CSF has no certification. The crosswalk is for orientation and
  for answering questionnaires honestly, including where coverage is partial.

## How it lands here

| Function | Canon | Mechanism |
|---|---|---|
| GOVERN | all of `memory/policy/` | `governance` skill · `/gate` · decision logs |
| IDENTIFY | `PROCESS.md` P1/P3 | `threat-modeling` · `/threat-model` · `risk-register.md` |
| PROTECT | `platform-security.md`, `identity-and-access.md`, `ai-security.md`, `supply-chain.md` | guard hooks · `policy-as-code` · `templates/k8s/` |
| DETECT | `AI12`, `P9` | `observability` · audit logging off-cluster |
| RESPOND | `R6`, `R7` | `reliability-sre` · `sre-analyst` · runbooks |
| RECOVER | `R3`, `R8` | `gitops` (rollback) · `/postmortem` |

## Gotcha

**CSF is an outcome framework, and outcome frameworks are easy to claim and hard to fail.** "We
identify assets" is true of almost any team. It earns its place here as a *mapping* target — the
thing that lets one crosswalk answer many questionnaires — and it is a poor choice as the primary
source of engineering rules. If a decision in this repo cites only a CSF Subcategory and no
prescriptive framework, the decision is probably underspecified.
