---
name: guardrails
description: >
  Runtime input and output controls for LLM systems — the filtering layer, with an honest account of
  what it can and cannot buy you. Carries: where a guardrail belongs in the defence stack (last, not
  first), input-side injection detection and its false-positive economics, output-side PII redaction
  and secret scanning on every path including streaming, schema-constrained generation as the
  control that actually works, tool-call allowlisting and argument validation, content moderation
  models, egress filtering, and fail-open vs fail-closed as a deliberate decision per control. Load
  when adding input/output filtering, validating model output, constraining tool calls, redacting
  PII, or moderating content. Triggers: guardrails, prompt injection detection, input validation,
  output filtering, PII redaction, content moderation, Llama Guard, NeMo Guardrails, structured
  output, JSON schema, function calling validation, refusal, safety filter, egress filtering,
  jailbreak detection, block unsafe output. Architecture-level defences are `agent-security`;
  attack generation is `llm-red-teaming`; the musts are `policy/ai-security.md` AI5, AI11.
---

# guardrails — the last layer, useful precisely because it isn't the only one

**Pinned:** no single pinned tool — this skill is pattern-level · authored 2026-07. Specific
moderation models and libraries move fast; verify any named tool before relying on it.

> On-demand: load this when adding runtime filtering. **Read `agent-security` first** — that skill
> carries the structural defences, and a guardrail bolted onto an over-privileged agent is
> decoration. The non-negotiable rules are canon: `ai-security.md` `AI5` (output is untrusted input)
> and `AI11` (sensitive output filtered at the boundary).

## When this applies

Adding input or output filtering. Validating model output. Constraining tool calls. Redacting PII.
Moderating content. Deciding what to do when a filter is unavailable.

## Where guardrails sit — and the honest claim

`agent-security`'s ladder puts detection at step 7, last. That ordering is the whole point:

- A guardrail **raises the cost** of an attack. It does not make one impossible.
- **A passing guardrail is not clearance** — same rule as the hooks in `security.md` `S1`.
- Guardrails are worth building anyway: they catch the common case cheaply, they generate the
  telemetry that tells you you're under attack, and they turn a silent failure into a logged one.

The claim to make is "this reduces the rate and gives us signal," never "this prevents injection."
Teams that believe the second one stop doing the first six steps.

## The two sides, and which is more tractable

| | Input side | Output side |
|---|---|---|
| Goal | Spot hostile or out-of-policy input | Stop harmful, leaking, or malformed output |
| Reliability | **Weak** — adversary adapts, obfuscates, translates, encodes | **Much stronger** — you're checking against your own rules |
| False positives | Expensive: blocks legitimate users | Cheaper: usually a retry or a redaction |
| Invest here? | Modest effort, log everything | **This is where the effort pays** |

**Output-side controls are deterministic checks against known rules; input-side controls are an arms
race against an adaptive adversary.** If you have budget for one, spend it on the output side and on
structure.

## Structured output — the control that actually works

The highest-value guardrail isn't a filter, it's making malformed output impossible:

```python
class ToolChoice(BaseModel):
    tool: Literal["search_docs", "get_account", "escalate"]   # enum, not free text
    query: str = Field(max_length=200)

resp = client.messages.create(..., tools=[{"name": "choose", "input_schema": ToolChoice.model_json_schema()}])
choice = ToolChoice.model_validate(resp.tool_use.input)       # validate anyway — never trust the API's word
```

The model picks from options rather than composing freely. This converts "did it say something
dangerous?" into "is this value in the enum?" — a question with a reliable answer. Combine with
`agent-security` ladder step 3.

**Always re-validate server-side.** Schema-constrained decoding is a strong nudge, not a guarantee,
and a proxy or a version change can silently drop the constraint.

## Output-side controls

Run on **every path** — normal responses, error messages, tool results returned to users, and
**streaming**. The streaming path is the one that ships unfiltered, because the filter was wired on
the complete response.

| Control | Notes |
|---|---|
| **Secret scanning** | Same patterns as `guard-secrets.py`. A model can regurgitate a key from its context |
| **PII redaction** | What counts as PII is `data-governance`'s call. Regex for structured identifiers, NER for names/addresses; accept it's imperfect |
| **Tenant-boundary check** | If the response references an id, verify the caller may see it. Catches retrieval scoping failures (`D7`) |
| **Content moderation** | A classifier for harm categories. Tune thresholds on your own traffic, not the defaults |
| **Schema validation** | Above |
| **Injection-in-output** | Model output going into another prompt (multi-agent, summarisation chains) gets the same treatment as untrusted input (`AI7`) |

### Streaming

Two workable patterns, and one that isn't:

- **Buffer to a boundary** — filter per sentence or per N tokens. Small latency cost, real filtering.
- **Optimistic with retraction** — stream, and if the filter trips, send a retraction the client
  honours. Requires a client that actually implements it.
- **Filter only the final assembled response** — this is the one that doesn't work, because the
  content already reached the user.

Pick one deliberately. Measure the added TTFT against the SLI (`reliability-sre` `R1`).

## Input-side controls

Worth having, with realistic expectations:

- **Injection classifiers** — a model or heuristic scoring "does this look like an instruction
  override?" Expect adaptation. **Log every detection even when you don't block** — the detection
  rate is a security signal and the trend matters more than the individual verdict.
- **Length and structure caps** — cheap, and they bound the injection surface.
- **Encoding normalisation** — strip zero-width and bidi characters, normalise Unicode
  (homoglyph and hidden-character attacks are common and cheap to defeat).
- **Source-based trust** — a document from the vetted corpus is treated differently from a
  user-uploaded PDF. This is more useful than any classifier: it's a property you *know* rather than
  one you infer.

**On indirect injection:** input filtering the *user's* message does nothing about a payload in a
retrieved document. Apply the same normalisation and detection to retrieved content, and remember
this is mitigation — the boundary is what the agent can do (`AI2`).

## Tool-call guardrails

The highest-consequence boundary in an agent system:

1. **Allowlist** — the agent may call these tools; anything else is rejected before execution.
2. **Argument validation** — schema, ranges, enums, path-traversal checks. A model-supplied file path
   gets resolved and confirmed inside the intended directory.
3. **Server-side authorization** — the tool re-checks against the *user's* identity, not the agent's
   (`authn-authz` `I4`, `I8`). **This is the one that survives a full compromise of the model**, and
   the one most often missing.
4. **Human gate on irreversible actions** (`AI3`), with the consequence rendered from the action.
5. **Rate and budget caps** (`AI9`), failing closed.

## Fail-open or fail-closed — decide per control

When the moderation service times out, do you block or allow? There is no universal answer, and the
failure mode is not deciding:

| Fail **closed** (block) | Fail **open** (allow) |
|---|---|
| Output PII/secret redaction | Optional quality checks |
| Tool-call authorization | Advisory classifiers |
| Budget and rate caps | Telemetry enrichment |

Anything protecting a *hard* boundary fails closed. Anything advisory fails open and **logs loudly**.
Write the choice down per control; alert when a fail-open path is actually taken, or you'll run
unprotected for weeks without knowing.

## Gotchas

- **Guardrails as the whole security story.** The single most common mistake in this area.
- **The streaming bypass.** Worth stating twice.
- **Blocking without logging.** A blocked request is your best signal that someone is probing;
  discarding it wastes the one thing detection is genuinely good for.
- **Tuning on synthetic attacks only.** False-positive rate on *real* traffic is what determines
  whether the control survives contact with users.
- **Redacting in the response but not in the logs.** `observability` and `S6` — the log is a second
  copy nobody filtered.
- **A moderation model with unexamined defaults.** Its notion of harm is not yours; calibrate against
  your policy or you'll block legitimate use and miss what you care about.
