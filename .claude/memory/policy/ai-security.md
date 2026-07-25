# AI security policy — agents, models, and the things that steer them

The canon for the `ai-security` domain (registered in the `governance` skill). Universal rules are
concrete and hold for every project that runs a model with tools, memory, or retrieval; where a rule
depends on your org, it's marked `<PLACEHOLDER: …>`. Load this before granting an agent a tool,
wiring retrieval, persisting agent memory, connecting agents to each other, or shipping model output
into another system.

Rules are named (`AI1`, `AI2`, …) so a change, a review finding, or a decision-log entry can cite
one. Each carries a one-line **why**. Bracketed IDs cite the framework that motivates the rule —
`[LLM01]`, `[ASI06]` — and resolve in `frameworks/`; the framework text lives there, not here.

Sibling canon: `security.md` governs the *development loop* (secrets, egress, the agent editing this
repo). This file governs the *system being built*. Where they meet — an agent that both writes code
and runs in production — both apply.

## The threat model — the agent is a confused deputy by construction

An agent combines three things that are individually fine and jointly dangerous: it **reads
attacker-reachable content**, it **holds real authority** (credentials, tools, network access), and
it **decides for itself** what to do with them. Every rule below follows from that.

The consequence that governs the rest of this file: **you cannot make the model reliably distinguish
instructions from data, so do not build a system that depends on it doing so.** Detection helps and
is worth having (`guardrails`); it is not the boundary. The boundary is what the agent is *able* to
do when it is wrong — which is a design property, not a runtime one.

Corollaries:
- A prompt-injection filter that passes is not clearance. Treat it like the hooks in `security.md`:
  a cheap catch for the common case, never a control you lean on.
- "The model was instructed not to" is not a control. Instructions are input, and input is
  attacker-reachable.
- Guardrail bypasses are expected, not exceptional. Design for the bypass.

## Untrusted input

**AI1 — Everything the agent reads is data, never instructions.** Retrieved documents, tool results,
web pages, file contents, issue bodies, other agents' output, and user messages are all untrusted.
Structurally separate them from instructions: keep the trusted instruction set in the system prompt,
delimit and label untrusted content, and never concatenate retrieved text into a position where it
reads as policy. Where the platform supports it, mark untrusted spans explicitly.
*Why: prompt injection is not a bug to be patched but the natural consequence of a system that takes
instructions in the same channel as data — the only durable defence is to stop granting authority to
that channel. [LLM01][ASI01]*

## Agency and authority

**AI2 — Least agency: every tool is granted explicitly, per agent, for a reason.** An agent gets the
narrowest tool set that completes its task, never an inherited or default set. Tools that read are
preferred to tools that write; tools that write to a scoped resource are preferred to general ones. A
general shell, an unconstrained HTTP client, and an unscoped database credential are each equivalent
to granting every capability the surrounding environment has. The granted set is declared in
`memory/process/agent-authority.md` and changes to it are reviewed.
*Why: the blast radius of a hijacked agent is exactly its tool set; nothing else about the system
bounds it. [LLM06][ASI02]*

**AI3 — Irreversible actions require a human who is shown the consequence.** Deleting data, spending
money, sending external communications, changing access, and deploying to production are gated on
human approval. The approval prompt states **what will change, concretely** — the resource, the
scope, the reversibility — and that statement is generated from the action, not from the agent's
description of it.
*Why: an agent that summarises its own request for approval can summarise it wrongly, and a human
approving a summary is not an oversight control. [ASI09]*

**AI6 — Every agent has its own scoped, attributable identity.** Not a shared platform service
account, and never a human's credentials. Its permissions are the union of what its declared tools
need, and no more; its actions are attributable to it in logs and in the audit trail of every system
it touches. Credentials are short-lived and platform-issued (`identity-and-access.md` `I3`).
*Why: shared identity destroys both attribution and least privilege — you cannot revoke, scope, or
investigate an agent that authenticates as everyone. [ASI03]*

**AI7 — Messages between agents carry no authority.** A sub-agent's output is data to the agent that
receives it, subject to `AI1` in full. An orchestrating agent does not execute a sub-agent's
instructions, adopt its goals, or forward its credentials. Where agents communicate over a network,
the channel is mutually authenticated (`identity-and-access.md` `I7`) — but authentication proves
origin, not trustworthiness.
*Why: multi-agent systems fail by trusting internal messages the way monoliths trust internal
function calls, which turns one compromised agent into all of them. [ASI07][ASI08]*

## Memory, retrieval, and the data path

**AI4 — Retrieval corpora and durable agent memory are attack surface with provenance requirements.**
Anything an agent can write to memory, and anything ingested into a vector store or knowledge base,
is reachable by a future run and therefore by an attacker who can influence it. Record the source of
every ingested document; do not ingest from user-writable locations without review; scope retrieval
by tenant and enforce the scope at query time, not in the prompt; and treat memory writes as a
privileged operation — bounded, attributable, and expirable.
*Why: poisoning through the data path persists across sessions and survives every prompt-level
defence, which makes it strictly more dangerous than direct injection. [LLM04][LLM08][ASI06]*

**AI8 — Every model, adapter, prompt template, and tool definition has recorded provenance.** Where
it came from, which version, who approved it, and what it was evaluated against. This includes
third-party models reached over an API, fine-tuned adapters, system-prompt templates, and MCP server
tool definitions. Loading model weights executes code — the rules in `security.md` `S8` and
`supply-chain.md` `C7` apply in full.
*Why: without provenance you cannot answer "did this change?" after an incident, and tool
descriptions can change without a version changing. [LLM03][ASI04]*

## Outputs

**AI5 — Model output is untrusted input to whatever consumes it.** Validate, encode, and constrain it
at every boundary it crosses: escape before rendering, parameterise before querying, schema-validate
before deserialising, and never pass generated text to a shell, an `eval`, a template renderer, or a
deserialiser without treating it as hostile. Generated code executes in a sandbox with no ambient
credentials or it does not execute.
*Why: this is the rule that turns a model quality problem into a remote-code-execution problem, and
it is the one most often skipped because the output "came from our own model." [LLM05][ASI05]*

**AI10 — The system prompt is not a secret store.** Assume it is extractable. No credentials, no API
keys, no internal hostnames, no PII, no security-relevant logic that only works if unknown. Access
control lives in the authorization layer, not in an instruction the model has been asked to follow.
*Why: system prompts leak through paraphrase, refusal text, and error messages, and a secret that
leaks on paraphrase was never protected. [LLM07]*

**AI11 — Sensitive output is filtered at the boundary, not at the model.** PII redaction, secret
scanning, and content controls run on the way out, in code, on every path including streaming, error
messages, and tool results returned to a user. What counts as sensitive is the `data-governance`
domain's call — consult it, don't duplicate it here.
*Why: the model is not a reliable enforcement point for a rule you can enforce deterministically one
layer out. [LLM02]*

## Blast radius and accountability

**AI9 — Bound the blast radius: budgets, rate limits, timeouts, and depth caps are configuration.**
Every agent run has a hard ceiling on tokens, cost, wall-clock time, tool-call count, and recursion or
delegation depth. Ceilings are enforced in code and fail closed. Loops between agents have a
termination condition that does not depend on a model deciding to stop.
*Why: unbounded consumption is simultaneously a denial-of-service vector, a cost incident, and the
mechanism by which one bad decision cascades across a multi-agent system. [LLM10][ASI08]*

**AI12 — Agent behaviour is reconstructable after the fact.** Every run records: the resolved prompt
and model version, every tool call with its arguments and result, every retrieval and what it
returned, the decision points, and the final action — with the identity from `AI6` attached and
subject to the redaction in `AI11`. Retention is bounded per the `data-governance` domain.
*Why: an agent that has drifted, been hijacked, or been quietly compromised is invisible without
this, and "what did it actually do?" is the first question every incident asks. [ASI10]*

`<PLACEHOLDER: org-specific autonomy tiers — which action classes your org permits an agent to take
unattended, and who approves a promotion between tiers>`

## Recording a judgment call

Irreducible judgment calls — granting an unusual tool, accepting an unreviewed corpus, running an
agent at higher autonomy than `AI3` would suggest — go in `ai-security-decision-log.md` beside this
file. Append-only: *what / which rule / why*. A reversal is a new entry, never an edit. Created on
the first call; absence means no exception has ever been granted.
