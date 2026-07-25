# NIST AI Risk Management Framework — the risk-management spine

**Identity:** NIST · AI 100-1 (AI RMF 1.0, January 2023) + AI 600-1 (Generative AI Profile, July
2024) · https://www.nist.gov/itl/ai-risk-management-framework
**Verified:** 2026-07-25. AI 100-1 and the AI 600-1 generative-AI companion profile confirmed;
NIST's AI guidance continues to evolve under the current federal posture, so re-verify before
citing AI RMF in an external compliance claim.
**Canon citing it:** `model-governance.md` · `ai-security.md` (AI12) · `compliance-crosswalk.md` ·
shapes `PROCESS.md` Part I and the phase gates

> The framework that says *how to think about AI risk*, rather than what a specific attack looks
> like. We carry it because it is the closest thing to a neutral, widely-accepted answer to "were you
> responsible about this?", and because its four functions map cleanly onto phase gates.

## The structure

Four functions, each with categories and subcategories:

| Function | What it asks |
|---|---|
| **GOVERN** | Is there a culture, policy, and accountability structure for AI risk? (cross-cutting — applies during all others) |
| **MAP** | What is the context, and what could go wrong in it? |
| **MEASURE** | Can you quantify, test, and monitor the risks you mapped? |
| **MANAGE** | Are risks prioritised, treated, and monitored over time? |

The framework also names seven characteristics of trustworthy AI: valid & reliable, safe, secure &
resilient, accountable & transparent, explainable & interpretable, privacy-enhanced, and fair with
harmful bias managed.

**AI 600-1 (the Generative AI Profile)** overlays generative-AI-specific risks onto those functions —
including confabulation, dangerous or violent content recommendation, data privacy, information
security, and the risks introduced by long context and third-party model dependencies.

## What we adopt

- **The four functions as the shape of the process, not a parallel workflow.** GOVERN is the policy
  canon plus `/gate`; MAP is P1 and P3 (problem framing and threat model); MEASURE is P5 (evaluation
  and red-team); MANAGE is P7 (operate, monitor, respond). We did not add an AI-RMF-shaped ceremony —
  we recognised that `PROCESS.md` already had this shape and made the correspondence explicit.
- **"Trustworthy characteristics" as gate vocabulary.** The P5 and P6 gates ask for evidence against
  named characteristics rather than a single aggregate quality claim.
- **AI 600-1's third-party-model risk framing** → `model-governance.md`'s rules on models you did not
  train.
- **Measurement honesty.** MEASURE's insistence that metrics be validated and their limits stated is
  the same discipline `statistics` and `agent-evaluation` enforce; canon does not restate it.

## What we leave

- **The organisational program structure** — risk tolerance statements, enterprise roles, board
  reporting. This is a project scaffold; an org-level AI governance program is a different artifact
  and would be pretending.
- **The AI RMF Playbook's full subcategory checklist.** Useful, long, and better consulted at the
  publisher than duplicated.
- **Any claim of AI RMF "compliance."** The AI RMF is voluntary and has no conformity assessment.
  `compliance-crosswalk.md` maps to it for orientation; it never asserts conformance.

## How it lands here

| Function | Where it lives | Mechanism |
|---|---|---|
| GOVERN | `memory/policy/` canon + `governance` skill | `/gate` refuses to advance without evidence |
| MAP | P1 problem framing, P3 threat model | `threat-modeling` · `/threat-model` |
| MEASURE | P5 evaluate & red-team | `agent-evaluation` · `llm-red-teaming` · `statistics` |
| MANAGE | P7 operate, monitor, respond | `observability` · `reliability-sre` · `risk-register.md` |
| GenAI profile risks | `ai-security.md`, `model-governance.md` | canon rules + `guardrails` |

## Gotcha

The AI RMF is a *risk-management* framework, not a security control set. It will tell you to identify
and treat information-security risk; it will not tell you what a hardened pod spec looks like. Pair
it with `owasp-agentic-top10.md` and `cis-kubernetes.md` — using AI RMF alone produces documentation,
not defence.
