# OWASP Top 10 for Agentic Applications — the agent-layer risk vocabulary

**Identity:** OWASP GenAI Security Project · 2026 edition (ASI01–ASI10) · published 2025-12 ·
https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
**Verified:** 2026-07-25. Risk set and IDs confirmed across the publisher's resource page and
multiple independent secondary sources.
**Canon citing it:** `ai-security.md` (AI1–AI12) · `identity-and-access.md` (I8) ·
`supply-chain.md` (C8) · `reliability.md` (R4, R5)

> The threat list for systems where a model plans, holds memory, calls tools, and acts with delegated
> authority — which is exactly what this scaffold exists to build. This is the single most important
> framework document in the repo: if you read one thing before wiring an agent to a tool, read this.

## The controls

| ID | Title | In one line |
|---|---|---|
| ASI01 | Agent Goal Hijack | The agent's objective is redirected by injected or manipulated input |
| ASI02 | Tool Misuse & Exploitation | Granted tools are used in unintended, chained, or destructive ways |
| ASI03 | Agent Identity & Privilege Abuse | The agent's credentials or delegated authority exceed or outlive the task |
| ASI04 | Agentic Supply Chain Compromise | Malicious or altered tools, MCP servers, plugins, models, or prompts enter the system |
| ASI05 | Unexpected Code Execution | Generated or retrieved content reaches an interpreter, shell, or eval |
| ASI06 | Memory & Context Poisoning | Persisted memory or retrieved context is contaminated and steers later runs |
| ASI07 | Insecure Inter-Agent Communication | Messages between agents are unauthenticated, unvalidated, or carry implicit trust |
| ASI08 | Cascading Agent Failures | One bad decision or compromise propagates across connected agents and workflows |
| ASI09 | Human-Agent Trust Exploitation | Persuasive or misleading output induces a human to approve something unsafe |
| ASI10 | Rogue Agents | Compromised, misaligned, or drifting agents keep operating unnoticed |

## What we adopt

Effectively all of it — this list is the backbone of `ai-security.md`. The specific stances:

- **ASI01 is structural, not detectable.** Goal hijack is prevented by constraining what the agent
  *can* do (`AI2`) and requiring a human for irreversible actions (`AI3`), not by trying to spot the
  hijack.
- **ASI03 gets its own canon rule** (`AI6`) and a state file: `memory/process/agent-authority.md`
  declares what each agent may do, which `guard-agent-config.py` checks edits against. An agent with
  a human's credentials is the failure this prevents.
- **ASI04 is why `mcp-security` exists as its own skill.** Tool poisoning, rug pulls, and
  cross-server shadowing are not covered by ordinary dependency scanning — a pinned server can change
  its tool *descriptions* without changing its version.
- **ASI06 → memory is a store with integrity requirements** (`AI4`). Anything written to durable
  agent memory is attacker-reachable on the next run.
- **ASI07 → messages between agents carry no authority** (`AI7`). A sub-agent's output is data.
- **ASI08 → blast-radius bounding** (`AI9`) plus the reliability rules on circuit breakers and
  graceful degradation (`R4`, `R5`). This is where security and SRE genuinely converge.
- **ASI09 is the one most teams have no control for at all.** Canon `AI3` requires that a human
  approval step present the *consequence* (what will change, irreversibly) rather than the agent's
  own summary of it. An approval dialog written by the thing asking for approval is not a control.
- **ASI10 → attributable, reconstructable agent behaviour** (`AI12`), which is the security reason
  the `observability` skill treats trajectory spans as mandatory rather than nice-to-have.

## What we leave

- **The maturity-model and scoring apparatus.** Our readiness gate is `PROCESS.md` §3.9, assessed at
  phase gates with written evidence — a second scoring scheme would be a second home for the same
  judgment.
- **Multi-agent-framework-specific mitigations.** Named framework integrations date quickly; canon
  states the invariant and the skills carry the current how-to.

## How it lands here

| Framework ID | Canon rule | Mechanism |
|---|---|---|
| ASI01 | `AI1`, `AI2` | `agent-security` · `scan-untrusted-content.py` · `guardrails` |
| ASI02 | `AI2`, `AI3` | `agent-security` · `agent-authority.md` · `guard-agent-config.py` |
| ASI03 | `AI6`, `I8` | `authn-authz` · `secrets-management` · `agent-authority.md` |
| ASI04 | `C8` | `mcp-security` · `supply-chain-security` · `guard-agent-config.py` |
| ASI05 | `AI5` | `agent-security` · `security-reviewer` · `guardrails` |
| ASI06 | `AI4` | `agent-security` · `data-governance.md` (corpus provenance) |
| ASI07 | `AI7` | `agent-security` · `authn-authz` (mTLS between services) |
| ASI08 | `AI9`, `R4`, `R5` | `reliability-sre` · `observability` |
| ASI09 | `AI3` | `agent-security` · `PROCESS.md` T13 (agent authority declaration) |
| ASI10 | `AI12`, `R6` | `observability` · `reliability-sre` · `llm-red-teaming` (drift regression) |

## Relationship to the LLM list

Every ASI risk extends one or more LLM risks (`owasp-llm-top10.md`) with the amplification that
autonomy, tools, and multi-agent topology bring. Build with both: the LLM list tells you what the
model gets wrong, this one tells you what the model getting it wrong can *reach*.
