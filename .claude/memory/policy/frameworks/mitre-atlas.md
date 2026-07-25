# MITRE ATLAS — adversary tactics and techniques against AI systems

**Identity:** MITRE · living knowledge base, 2026 update · https://atlas.mitre.org/
**Verified:** 2026-07-25 — 16 tactics, ~170 techniques, 35 mitigations, 57 case studies; agentic
techniques (context/memory poisoning, agent configuration tampering, credential harvesting,
exfiltration via tool invocation) added through late 2025 into 2026.
**Canon citing it:** `ai-security.md` (AI1, AI4, AI6, AI8, AI12) · used by `threat-modeling` as the
technique vocabulary

> ATT&CK for AI: a catalogue of how attacks on machine-learning and agentic systems actually proceed,
> built from real incidents rather than theory. We carry it for threat modelling and red-teaming —
> OWASP names the *risk*, ATLAS names the *technique*, and a threat model needs both.

## The structure

ATLAS mirrors ATT&CK's shape: **tactics** (the adversary's goal at a stage) containing **techniques**
(`AML.T####`, how they achieve it), with **mitigations** (`AML.M####`) and case studies
(`AML.CS####`). The tactic sequence runs roughly reconnaissance → resource development → initial
access → ML model access → execution → persistence → privilege escalation → defense evasion →
credential access → discovery → collection → ML attack staging → exfiltration → impact.

**We do not reproduce the technique catalogue.** It is large, it moves, and MITRE maintains it well.
Cite technique IDs; look them up at the publisher.

The techniques that recur most in this scaffold's threat models:

| Area | What it covers |
|---|---|
| Prompt injection (direct + indirect) | The dominant initial-access technique for LLM applications |
| Training / RAG data poisoning | Implanting behaviour through the data path rather than the prompt |
| Context and memory poisoning | The agentic extension — persistence across runs |
| Agent configuration tampering | Altering tool grants, system prompts, or server definitions |
| Model exfiltration / extraction | Stealing weights, or reconstructing them through queries |
| Exfiltration via tool invocation | Using a granted tool as the egress channel |
| LLM supply-chain compromise | Poisoned models, adapters, plugins, or MCP servers |

## What we adopt

- **Technique IDs as the naming convention in threat models.** `/threat-model` produces entries of
  the shape *asset → technique (ATLAS ID) → control (canon rule) → residual risk*. A threat model
  whose threats have no technique IDs tends to be a list of worries; one with them is checkable.
- **The case studies as evidence.** When canon asserts a rule that costs someone effort, an ATLAS
  case study is the argument that it is not hypothetical.
- **Mitigation IDs as crosswalk targets** in `compliance-crosswalk.md`.
- **The tactic sequence as red-team structure.** `llm-red-teaming` organises attack suites by tactic
  so coverage gaps are visible.

## What we leave

- **The full technique catalogue.** Referenced, never copied — a local copy would be stale within a
  quarter and would compete with the publisher as a source of truth.
- **ATT&CK-style detection engineering.** Mapping techniques to SIEM detections is real work but sits
  outside a project scaffold; `observability` carries what to emit, not how a SOC consumes it.
- **Navigator-layer scoring.** Coverage is assessed at phase gates, not in a heat map.

## How it lands here

| Use | Canon rule | Mechanism |
|---|---|---|
| Naming threats in the threat model | — (process) | `threat-modeling` · `/threat-model` · `threat-modeler` agent |
| Structuring adversarial test suites | `AI1`, `AI4` | `llm-red-teaming` · `/redteam` · `red-teamer` agent |
| Justifying a canon rule with evidence | all of `ai-security.md` | case-study citation in the rule's `*Why:*` |
| Mitigation crosswalk | — | `compliance-crosswalk.md` |

## Gotcha

ATLAS is descriptive, not prescriptive. It tells you what adversaries do; it does not tell you what
you must do. Do not cite an ATLAS technique as though it were an obligation — the obligation is the
canon rule, and ATLAS is the evidence that the rule is worth having.
