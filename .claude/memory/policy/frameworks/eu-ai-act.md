# EU AI Act — the regulation, and when it bites

**Identity:** European Union · Regulation (EU) 2024/1689 · entered into force 2024-08-01 ·
https://eur-lex.europa.eu/eli/reg/2024/1689/oj
**Verified:** 2026-07-25. Timeline below reflects the **Digital Omnibus on AI provisional agreement
of May 2026**, which deferred the Annex III high-risk obligations. Timelines under active political
revision — **re-verify before relying on any date here.**
**Canon citing it:** `compliance-crosswalk.md` · `model-governance.md` (awareness only)

> ⚠️ **This is not legal advice, and this document does not make anyone compliant.** It exists so that
> a team building an AI platform knows which obligations might apply and roughly when — early enough
> to involve someone qualified, rather than discovering it at launch.

## The risk tiers

| Tier | Treatment |
|---|---|
| **Prohibited** | Banned outright — social scoring, certain biometric categorisation, emotion recognition in workplaces and schools, untargeted facial-image scraping, some manipulative systems. Applicable since 2025-02-02. |
| **High-risk (Annex III)** | Permitted with substantial obligations: risk management, data governance, technical documentation, record-keeping, transparency, human oversight, accuracy/robustness/cybersecurity, conformity assessment, CE marking, post-market monitoring |
| **Limited risk** | Transparency obligations — disclose that a user is interacting with an AI system; label synthetic content |
| **Minimal risk** | No specific obligations |
| **GPAI models** | A separate track for general-purpose models: technical documentation, a public summary of training data, copyright policy, and — for models with systemic risk — evaluation, adversarial testing, incident reporting, and cybersecurity protection |

## The timeline

| Date | What applies |
|---|---|
| 2024-08-01 | Regulation entered into force |
| 2025-02-02 | Prohibited practices; AI literacy obligations |
| **2025-08-02** | **GPAI provider obligations begin** |
| 2026-08-02 | Commission enforcement powers for GPAI; transparency rules |
| **2027-08-02** | GPAI models placed on the market before 2025-08-02 must comply |
| **2027-12-02** | **Annex III high-risk obligations** — deferred from 2026-08-02 by the May 2026 Digital Omnibus provisional agreement, to let technical standards and Commission guidance catch up |

The deferral is the reason this document carries a stronger re-verification warning than any other in
this directory: the dates have already moved once.

## What we adopt

- **Awareness, placed early.** `/intake`'s security-posture interview asks whether the system touches
  an Annex III use case (employment, education, essential services, law enforcement, biometrics,
  critical infrastructure) or ships a GPAI model. A "yes" is recorded in the risk register at P1 —
  because a high-risk classification changes the architecture, and finding out at P6 is the expensive
  path.
- **The obligations that are good engineering regardless of jurisdiction**, which is most of them:
  technical documentation, record-keeping, data governance, human oversight, accuracy and robustness
  testing, and cybersecurity. `model-governance.md` (model cards, eval-before-release, provenance)
  and `PROCESS.md`'s gates already produce these artifacts. A project that follows this scaffold has
  much of the *evidence* even if it never engages with the regulation.
- **The transparency obligation as a default.** Disclosing that a user is interacting with an AI
  system, and labelling synthetic output, are cheap and correct everywhere.
- **ISO/IEC 42001 as the practical scaffold** for teams that do need to demonstrate AI governance —
  see `iso-27001-42001.md`.

## What we leave

- **Legal interpretation, classification decisions, and conformity assessment.** A scaffold cannot
  determine whether a system is Annex III high-risk. That is a legal question with legal consequences
  and it needs qualified counsel; what this repo does is make sure the question gets *asked* at P1.
- **Member-state implementation detail** and national competent-authority procedure.
- **Any compliance claim.** `compliance-crosswalk.md` maps to AI Act articles for orientation and
  asserts nothing.

## How it lands here

| Element | Mechanism |
|---|---|
| Ask the classification question at P1 | `/intake` security-posture interview · `risk-register.md` |
| Technical documentation + record-keeping | `model-governance.md` (model cards) · `PROCESS.md` gates · tracker runs |
| Data governance | `data-governance.md` |
| Human oversight | `AI3` (irreversible actions need a human) · `agent-authority.md` |
| Accuracy, robustness, cybersecurity | `agent-evaluation` · `llm-red-teaming` · all security canon |
| Transparency / synthetic-content labelling | `guardrails` · `serving` |
| Article-level crosswalk | `compliance-crosswalk.md` |

## Gotcha

**Provider vs deployer changes everything, and teams routinely assume the wrong one.** Obligations
differ sharply depending on whether you place a system on the market, deploy someone else's under
your own name, or substantially modify a third-party model — and fine-tuning a GPAI model can move
you from deployer to provider. If a project is anywhere near a regulated use case, that determination
is the first question for counsel, not the last.
