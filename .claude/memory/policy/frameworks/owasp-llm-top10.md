# OWASP Top 10 for LLM Applications — the model-layer risk vocabulary

**Identity:** OWASP GenAI Security Project · v2.0 (2025 list) · https://genai.owasp.org/llm-top-10/
**Verified:** 2026-07-25. Publisher page returned 403 to automated fetch; version and risk set
confirmed across multiple independent secondary sources reporting the v2.0 (2025) release.
**Canon citing it:** `ai-security.md` (AI1, AI4, AI5, AI8, AI9, AI10, AI11) · `supply-chain.md` (C7)

> The reference taxonomy for what goes wrong in an application built on a large language model. We
> carry it because it is the shared vocabulary — naming a finding "LLM01" communicates more, to more
> people, than any phrasing we could invent, and it makes our canon auditable against something
> external.

## The controls

| ID | Title | In one line |
|---|---|---|
| LLM01 | Prompt Injection | Attacker-controlled text steers the model's behaviour, directly or via content it retrieves |
| LLM02 | Sensitive Information Disclosure | The model reveals secrets, PII, or proprietary data through its output |
| LLM03 | Supply Chain | Compromised models, adapters, datasets, or dependencies enter the system |
| LLM04 | Data and Model Poisoning | Training, fine-tuning, or retrieval data is manipulated to implant behaviour |
| LLM05 | Improper Output Handling | Downstream systems trust model output — leading to XSS, SQLi, or code execution |
| LLM06 | Excessive Agency | The model is granted more capability, permission, or autonomy than the task requires |
| LLM07 | System Prompt Leakage | Instructions or secrets placed in the system prompt are extracted |
| LLM08 | Vector and Embedding Weaknesses | RAG stores are poisoned, inverted, or leak across tenants |
| LLM09 | Misinformation | Confident, wrong output is acted on — including hallucinated packages and APIs |
| LLM10 | Unbounded Consumption | Uncapped inference drives cost, latency, or denial of service |

## What we adopt

- **The IDs as vocabulary.** Threat models, red-team findings, and canon rules cite them; the
  `security-reviewer` agent maps every finding to one.
- **LLM01 as a design constraint, not a filter problem.** Canon `AI1` states the rule structurally —
  untrusted content is data — rather than assuming detection works. Detection (`guardrails`) is a
  second layer, never the boundary.
- **LLM05's inversion.** Model output is untrusted *input* to whatever consumes it (`AI5`). This is
  the rule most often skipped and the one that turns a chat bug into an RCE.
- **LLM06 → least agency by default** (`AI2`): tools are allowlisted per agent, not inherited.
- **LLM08 as a first-class store concern** (`AI4`): a retrieval corpus is an attack surface with
  provenance requirements, not a cache.
- **LLM10 → hard budgets** (`AI9`): token, cost, time, and concurrency caps are configuration, not
  aspiration.

## What we leave

- **The tooling and vendor recommendations.** We choose our own; see `guardrails` and
  `llm-red-teaming`.
- **The risk-scoring methodology.** Our prioritisation runs through `memory/process/risk-register.md`
  and the phase gates, not a parallel scoring scheme.
- **LLM09 (Misinformation) as a *security* control.** We treat output quality as an evaluation
  problem owned by `agent-evaluation` and `evaluation`, not a canon rule — with one exception:
  hallucinated dependency names are a supply-chain risk and are covered by `C1`.

## How it lands here

| Framework ID | Canon rule | Mechanism |
|---|---|---|
| LLM01 | `AI1` untrusted content is data | `agent-security` · `scan-untrusted-content.py` · `guardrails` |
| LLM02, LLM07 | `AI10`, `AI11`, `S5` | `guardrails` (output filtering, PII redaction) · `guard-secrets.py` |
| LLM03 | `C7`, `C8` | `supply-chain-security` · `mcp-security` · `guard-agent-config.py` |
| LLM04 | `AI4`, `AI8` | `data-governance.md` (corpus provenance) · `agent-security` |
| LLM05 | `AI5` | `agent-security` · `security-reviewer` |
| LLM06 | `AI2`, `AI3` | `agent-security` · `memory/process/agent-authority.md` · `guard-agent-config.py` |
| LLM08 | `AI4` | `agent-security` · `data-governance.md` |
| LLM10 | `AI9` | `reliability-sre` · `observability` (cost/token telemetry) |

## Relationship to the agentic list

LLM01–LLM10 govern the **model layer**; `owasp-agentic-top10.md` (ASI01–ASI10) governs what happens
once that model plans, remembers, and calls tools. The agentic risks extend these rather than replace
them — an agent system needs both. Where a threat appears in both, canon cites both IDs.
