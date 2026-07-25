---
name: llm-red-teaming
description: >
  Adversarial testing of your own LLM and agent systems — finding the failures before someone else
  does, and keeping them fixed. Carries: scoping and authorization (own systems only, in writing),
  organising attacks by MITRE ATLAS tactic and OWASP ASI risk so coverage gaps are visible, the
  attack catalogue (direct and indirect injection, tool misuse, data exfiltration via tool calls,
  cross-tenant retrieval, memory persistence, multi-turn escalation, encoding and obfuscation),
  automated harnesses (promptfoo, garak, PyRIT), scoring attempts without fooling yourself, and
  turning every finding into a permanent regression case. Load when adversarially testing an agent,
  building an attack suite, running a pre-release security evaluation, or wiring a red-team
  regression gate. Triggers: red team, red teaming, adversarial testing, jailbreak, attack the
  agent, prompt injection test, security testing the LLM, penetration test the agent, garak,
  promptfoo, PyRIT, attack suite, can it be exploited, pre-release security eval. Scoring
  methodology is `agent-evaluation`; the defences are `agent-security` and `guardrails`.
---

# llm-red-teaming — attacking your own system on purpose

**Pinned:** promptfoo, garak, pyrit — unpinned · authored 2026-07 · run `/skill-update
llm-red-teaming` once installed; this area moves fast and tool APIs move with it.

> On-demand: load this to build or run adversarial tests. **Scope: systems this project owns**, per
> the project definition and threat model. The defences are `agent-security` (architecture) and
> `guardrails` (runtime); scoring methodology and regression gating are `agent-evaluation`; the
> release obligation is canon (`model-governance.md` `M16`).

## Authorization — settle this first

**Only test systems you own or have written permission to test.** Concretely:

- In scope: this project's agents, models, endpoints, and infrastructure, in a non-production
  environment where possible.
- Out of scope without explicit written authorization: third-party model providers' infrastructure,
  other tenants, any system not named in this project's threat model.
- **Testing a model provider's API** for jailbreaks against *their* safety training is testing
  someone else's system — check their terms; most permit security research on your own application
  and not attacks on their platform.

If scope is unclear, that's a question for the user, not an assumption. Record the authorized scope
in the threat model.

## When this applies

Before release (`M16` — a recorded run is release evidence). After an architecture change that moves
a trust boundary. When a new tool is granted. On a schedule, because attacks evolve while your system
doesn't.

## Structure the campaign, don't freestyle

Freeform attacking finds what you already imagined. Organise by framework so gaps are visible:

- **By OWASP ASI risk** (`ASI01`–`ASI10`) — did we attempt goal hijack? tool misuse? memory
  poisoning? identity abuse? A campaign that skipped four of ten has a coverage gap you can name.
- **By MITRE ATLAS tactic** — reconnaissance → initial access → execution → persistence → exfiltration
  → impact. This surfaces the chained attacks that single-shot testing misses.

Track coverage as a matrix. "We tried some jailbreaks" is not a security evaluation.

## The attack catalogue

**Direct injection** — the baseline. Instruction override, role-play framing, hypothetical framing,
"repeat your system prompt," delimiter escape, fake system messages.

**Indirect injection — the one that matters.** Payload in content the agent reads rather than in the
user's message:

| Channel | Test |
|---|---|
| Retrieved document | Poison a corpus document with instructions; does the agent follow them? |
| Web page fetched by a tool | Same, via the fetch path |
| File contents, code comments | Payload in a repo the agent reads |
| Ticket/issue/email bodies | The classic enterprise-agent vector |
| Filenames, image alt text, metadata | Frequently unfiltered |
| **Another agent's output** | `AI7` — test the multi-agent trust boundary explicitly |

**Tool misuse** — can the agent be talked into a destructive call? Calling a tool with
out-of-scope arguments? Chaining benign tools into a harmful outcome (read file → send email)?
Calling a tool it shouldn't have access to at all?

**Data exfiltration** — usually via a granted tool rather than the response: encode data in a URL the
agent fetches, in a filename it writes, in an email it sends, or in a search query it issues. **This
is the attack most systems have no control for**, and the reason egress belongs in the threat model.

**Boundary tests** — cross-tenant retrieval, another user's data via id manipulation, PII in output,
system prompt extraction.

**Persistence** — write instructions into durable memory or a corpus in session 1; verify they fire
in session 2 (`ASI06`). This is the highest-severity class because it survives everything
prompt-level.

**Multi-turn escalation** — establish a benign context over several turns, then pivot. Single-turn
testing misses it entirely, and it's how real attacks work.

**Obfuscation** — base64, ROT13, homoglyphs, zero-width characters, non-English, token splitting,
markdown/HTML comments. Run every successful attack again encoded; filters routinely fail here.

## Harnesses

| Tool | Fits |
|---|---|
| **promptfoo** | Eval-first, YAML-configured, good red-team plugins; slots into the CI gate alongside `agent-evaluation` |
| **garak** | Broad probe catalogue for model-level vulnerability scanning |
| **PyRIT** | Multi-turn, orchestrated attacks; the right tool for escalation scenarios |

Automation gives coverage and repeatability. **Manual creative testing finds the novel things** —
run both, and expect the interesting findings to come from a human following a hunch, then get
encoded as an automated case.

## Scoring without fooling yourself

- **Define success per attack, in advance.** "Did the agent reveal the system prompt?" is checkable;
  "did it behave badly?" is not.
- **Attack success rate over N trials**, not a single attempt — these systems are stochastic, and a
  single pass proves nothing. Report `k/n`.
- **Severity is impact, not novelty.** A boring attack that reaches production data outranks a clever
  one that produces a rude sentence.
- **A judge scoring attack success needs validating** like any other judge (`agent-evaluation`).
- **Record the failures too.** Attacks that didn't work are the coverage evidence, and they're what
  makes the next run comparable.

## Every finding becomes a regression case

The point of the exercise. A finding that is fixed and not encoded will come back.

1. Minimal reproduction, added to the safety suite in `evals/`.
2. Fix — at the **structural** level where possible (`agent-security` ladder), filter only as
   backstop.
3. The case now runs in CI. `agent-evaluation` gates the safety suite **absolutely**: any regression
   fails the build.
4. Finding + decision recorded in `memory/process/risk-register.md`; unfixed ones get an owner and a
   review date.

## Reporting

Per finding: what was attempted, what happened, reproduction steps, impact if exploited, the ASI/
ATLAS id, severity, and the recommended structural fix. Written for the person who has to fix it —
which means naming the canon rule it violates, so the fix has a home.

## Gotchas

- **Testing the model, not the system.** Whether the model can be talked into saying something rude
  matters far less than whether your agent can be made to call `delete_account`. Test the *system*.
- **Skipping indirect injection** because direct injection is easier to script. Direct injection is
  mostly a nuisance; indirect is the threat.
- **Single-turn only.** Real attacks build context.
- **Stopping at the first success.** Enumerate the class; one blocked variant means little.
- **Red-teaming once, before launch.** The system changes, the attacks evolve, the suite is what
  keeps up.
- **Confusing this with a penetration test.** This covers the model and agent layer. The API, the
  cluster, and the pipeline need conventional security testing too (`secure-cicd`, `policy-as-code`).
