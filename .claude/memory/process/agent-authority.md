# Agent authority declaration

> Live state for `PROCESS.md` T13 and canon `ai-security.md` `AI2`/`AI6`. **This is the file
> `guard-agent-config.py` checks tool-granting edits against**, which is what makes a growing tool
> surface visible as a diff rather than an accumulation.
>
> The rule it exists to enforce: **an agent's permissions should be as hard to change as its code.**
> Least agency erodes silently — one convenient addition at a time — and this file is where that
> erosion becomes reviewable.

**Last reviewed:** _Not yet written — seeded by `/bootstrap` for platform archetypes._

## Agents and their granted tools

_One row per agent. "Reaches" is the concrete blast radius: which systems, which data, whose
credentials. If you cannot fill "reaches", the grant is not understood well enough to make._

| Agent | Identity (`AI6`) | Tool | Scope / constraint | Reaches | Reversible? | Human gate (`AI3`) |
|---|---|---|---|---|---|---|

## Actions requiring a human

_`AI3`: irreversible actions need an approving human who is shown the **concrete consequence** —
rendered from the action, not from the agent's description of it._

| Action class | Why irreversible | Who approves | What the prompt must show |
|---|---|---|---|

## Budgets and caps

_`AI9`: enforced in code, failing closed. A cap that fails open is not a cap._

| Limit | Value | Enforced where | Fails |
|---|---|---|---|
| Tokens per run | — | — | closed |
| Cost per run / per day | — | — | closed |
| Wall-clock per run | — | — | closed |
| Tool calls per run | — | — | closed |
| Delegation / recursion depth | — | — | closed |

## Connected MCP servers and third-party tools

_`C8`: pinned by version or digest, and the **tool descriptions** are part of the reviewed surface —
a server can change what its tools claim to do without changing its version._

| Server | Pin | Tools exposed | Tools actually granted | Credentials + scope | Last description review |
|---|---|---|---|---|---|

## Review

Reviewed at every phase gate from P4, and whenever a tool is added. A tool present in code but not
declared here is a finding (`/sec-review`).
