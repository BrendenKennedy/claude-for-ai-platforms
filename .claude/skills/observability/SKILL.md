---
name: observability
description: >
  Instrumenting a platform so you can answer questions you didn't anticipate — logs, metrics, and
  traces via OpenTelemetry, plus the LLM/agent-specific telemetry nothing else emits. Carries: the
  three signals and when each is the right one, OTel concepts (spans, context propagation,
  resource + semantic attributes, collector), what an agent run must record (model + version,
  token counts, cost, latency incl. time-to-first-token, every tool call, retrieval hits,
  trajectory), cardinality discipline, and PII-safe logging. Load when adding instrumentation,
  designing what to log, debugging in production, wiring a collector, or tracking token spend.
  Triggers: observability, OpenTelemetry, OTel, tracing, distributed trace, span, metrics,
  Prometheus, structured logging, log levels, correlation id, cardinality, dashboard, token usage,
  cost tracking, LLM telemetry, agent trace, what is my agent doing, debug in production, why is
  it slow. SLOs and error budgets are `reliability-sre`; model drift is `monitoring`; what may be
  logged at all is `policy/security.md` S6.
---

# observability — instrumenting for the question you haven't thought of yet

> On-demand: load this when deciding what a system should emit, or when production behaviour needs
> explaining. Objectives built *on* this telemetry (SLIs, SLOs, error budgets, alerting policy)
> belong to `reliability-sre`; model-quality drift belongs to `monitoring`; the rule about what may
> be logged at all is canon (`policy/security.md` `S6`, `ai-security.md` `AI11`).

## When this applies

Adding instrumentation. Choosing what to log. Wiring a collector or backend. Debugging something in
production. Tracking token spend. Designing an agent's trace so a bad run can be reconstructed.

## Monitoring vs observability

Monitoring answers **known** questions — "is the error rate above 1%?" Observability is the property
that lets you answer **unknown** ones — "why are requests from this one tenant slow, only when the
retrieval cache misses, only since Tuesday?" You get it from high-cardinality, well-structured
telemetry that lets you slice arbitrarily after the fact. Dashboards are the monitoring half; the
observability half is what makes a new question answerable without shipping code.

## The three signals

| Signal | Answers | Cost | Cardinality |
|---|---|---|---|
| **Metrics** | "How much / how many / how often?" — aggregates over time | Cheap, constant | **Low** — every label combination is a time series |
| **Logs** | "What exactly happened in this one case?" | Moderate, scales with volume | High — fine |
| **Traces** | "Where did the time go, across services?" | Moderate (sampled) | High — fine |

**The default mistake is reaching for logs when you needed a metric, or a metric when you needed a
trace.** Rate/error/duration → metrics. Causal chain across components → traces. The specific detail
of one request → logs, correlated to the trace by id.

## OpenTelemetry — the parts that matter

OTel is the vendor-neutral standard for producing all three. Adopt it because it decouples
instrumentation from backend: instrument once, change vendors without touching code.

| Concept | What it is |
|---|---|
| **Span** | One unit of work — name, start/end, attributes, status, events. Spans nest into a trace. |
| **Context propagation** | How trace context crosses process boundaries (W3C `traceparent`). Without it you get disconnected fragments, which is the most common broken setup. |
| **Resource attributes** | What's emitting — `service.name`, `service.version`, `deployment.environment`. Set once. |
| **Semantic conventions** | Standard attribute names so backends understand your data. Use them; inventing `http_status_code` when the convention is `http.response.status_code` costs you tooling. |
| **Collector** | A process that receives, processes (batch, filter, **redact**), and exports. Run one — it's where PII scrubbing and sampling belong, so app code doesn't carry them. |
| **Sampling** | Head-based (decide at start, cheap) vs tail-based (decide after seeing the whole trace — keeps all errors and slow requests, needs the collector). Tail-based is usually what you want. |

```python
from opentelemetry import trace
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("agent.run") as span:
    span.set_attribute("agent.name", agent.name)
    span.set_attribute("agent.id", agent.identity)      # AI6 — attribution
    span.set_attribute("gen_ai.request.model", model_id)
    ...
    span.set_attribute("gen_ai.usage.input_tokens", usage.input)
    span.set_attribute("gen_ai.usage.output_tokens", usage.output)
```

Attach the identity from `ai-security.md` `AI6` to every span. "Which agent did this?" should be a
filter, not an investigation.

## What an agent run must record

This is the part generic instrumentation misses, and it's what `ai-security.md` `AI12` requires —
enough to reconstruct a decision after the fact.

**Per run (the root span):** agent name + identity · resolved model id **and version/snapshot**
(`M14`) · prompt template version (`M15`) · total tokens in/out · **cost** · total latency ·
outcome · termination reason (completed / cap hit / error / refused).

**Per model call (a child span):** model + version · input/output tokens · latency, with
**time-to-first-token separate** for streaming · finish reason · retry count · whether a fallback
model was used (`R5`).

**Per tool call (a child span):** tool name · arguments (**redacted**) · result size and status ·
latency · **whether it required human approval and what was decided** (`AI3`).

**Per retrieval (a child span):** query (redacted) · number of hits · **document ids and sources**
(not content) · scores · which tenant filter applied (`D7`).

**Trajectory-level:** the sequence of steps, so a wrong answer can be traced to *where* it went
wrong. This is what `agent-evaluation` scores offline and what an incident needs online.

### The four numbers to put on a dashboard first

Requests, error rate, p95/p99 latency, **and cost per request**. Cost is a first-class operational
signal for LLM systems in a way it isn't elsewhere — it's how `LLM10` (unbounded consumption)
becomes visible before the invoice does.

## Structured logs

JSON, one event per line, machine-parseable — never formatted prose. Every log carries `trace_id`
and `span_id` so a log line jumps to its trace.

```python
log.info("tool_call_completed", extra={
    "tool": "search_customers", "duration_ms": 142, "result_count": 3,
    "agent_id": agent.identity, "trace_id": ctx.trace_id,
})
```

Levels that mean something: `ERROR` = a human must look. `WARN` = degraded, self-recovering
(`R5` fallback fired). `INFO` = state changes worth reconstructing. `DEBUG` = off in production.
**If everything is `ERROR`, nothing is.**

## Cardinality — the thing that breaks the bill

**A metric label with unbounded values creates unbounded time series.** Never label a metric with
user id, request id, prompt text, full URLs, or session id. Those belong in logs and traces, which
are built for high cardinality. Bounded labels only: model name, tool name, status, tenant *tier*,
route *template* (`/users/{id}`, never `/users/12345`).

This single mistake is the most common cause of an observability bill that dwarfs the service.

## PII and secrets in telemetry

Canon: `security.md` `S6` (treat everything logged as public to the team), `ai-security.md` `AI11`
(sensitive output filtered at the boundary), `data-governance.md` for what counts as sensitive.

- **Never log** prompts or completions verbatim by default. Log token counts, hashes, and
  classifications. If prompt capture is genuinely needed for debugging, it is opt-in, redacted,
  short-retention, and access-controlled — and it's a `data-governance` decision, not a default.
- **Redact in the collector**, not just in app code — one enforcement point that new services
  inherit for free.
- Retrieval spans record document **ids and sources**, never content.
- Tool arguments are redacted by field, with an allowlist of safe fields rather than a denylist.

## Gotchas

- **Broken context propagation** — async boundaries, queues, and background tasks silently drop
  trace context, giving you orphan spans that look like separate requests. Test it end to end.
- **Sampling away the interesting traces.** Head-based sampling at 1% discards 99% of your errors.
  Tail-based, keeping all errors and slow traces.
- **Instrumenting the framework and not the decisions.** Auto-instrumentation gives HTTP spans for
  free and tells you nothing about *why the agent chose that tool*. The domain spans are the ones
  you have to write.
- **Streaming latency measured wrong.** Total completion time hides a slow first token; users feel
  TTFT. Emit both.
- **Logging the prompt "just for now."** It persists, it's indexed, and it's exactly the transcript
  problem from `security.md` `S3` in a different store.
