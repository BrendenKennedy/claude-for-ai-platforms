---
name: threat-modeling
description: >
  Producing and maintaining the project's threat model — the artifact that says what we're
  defending, from whom, and what stops them. Carries: the four-question frame, drawing the trust
  boundaries that make threats visible, STRIDE for the classic surface and MITRE ATLAS + OWASP ASI
  for the AI/agent surface, rating without a fake-precision scoring scheme, and the rule that every
  threat ends in a control, an accepted risk, or a register entry — never a shrug. Load at P3
  before architecture is settled, when the design changes materially, when a new trust boundary or
  data flow appears, or when asked what could go wrong. Triggers: threat model, threat modelling,
  STRIDE, attack surface, trust boundary, data flow diagram, what could go wrong, abuse case, risk
  assessment, security design review, attacker perspective, adversary, kill chain, MAESTRO, ATLAS,
  security requirements. Produces the artifact; the controls themselves live in `agent-security`,
  `kubernetes`, `authn-authz`, and the policy canon.
---

# threat-modeling — deciding what you're defending before you defend it

> On-demand: load this to build or refresh `.claude/memory/process/threat-model.md`. This skill owns
> the *artifact and the method*; every control it points at is owned elsewhere (`agent-security`,
> `kubernetes`, `authn-authz`, `supply-chain-security`) and every *must* is canon in
> `.claude/memory/policy/`. `/threat-model` runs this; the `threat-modeler` agent does it read-only.

## When this applies

At P3, before the architecture is settled — that's the point where the output can still change the
design cheaply. Then: whenever a trust boundary moves, a data flow appears, an agent gains a tool, a
new tenant class shows up, or the system becomes internet-reachable. A threat model written at P6 is
documentation; written at P3 it is design input.

## The four questions

The whole method, and it fits in a sentence each:

1. **What are we building?** A diagram, or at minimum an honest component-and-flow list.
2. **What can go wrong?** Threats, enumerated per boundary using a checklist so you don't only think
   of what you already fear.
3. **What are we going to do about it?** A control, an accepted risk, or a register entry — per
   threat, no exceptions.
4. **Did we do a good job?** Reviewed at the gate; revisited when the design moves.

Most failed threat models fail at (1) — a vague picture produces vague threats — or at (3), where a
list of worries never becomes a list of decisions.

## Step 1 — draw the boundaries, because threats live on them

You need components, the data flowing between them, and — the part that carries the value —
**trust boundaries**: every place where data or control crosses between differently-trusted zones.

Boundaries that exist in almost every AI platform and get missed:

| Boundary | Why it's a boundary |
|---|---|
| User → application | The obvious one |
| **Application → model** | The prompt is a control channel |
| **Model → tool execution** | The point where text becomes action — the highest-value boundary in an agent system |
| **Retrieved document → prompt** | Where indirect injection enters |
| **Agent → agent** | Internal ≠ trusted (`AI7`) |
| **CI/CD → production** | The pipeline is an actor with production credentials |
| **Third-party model API** | Data leaves; output arrives untrusted |
| Tenant → tenant | Wherever shared infrastructure separates them |

Name the assets too, concretely: model weights, the retrieval corpus, customer data, credentials,
the system prompt, the audit log. "The system" is not an asset.

## Step 2 — enumerate, with a checklist

Freeform brainstorming finds the threats you already worried about. Use both lists:

**STRIDE — for the conventional surface** (services, APIs, infrastructure):

| | Threat | Asks |
|---|---|---|
| **S** | Spoofing | Can someone claim to be another principal? |
| **T** | Tampering | Can data or code be modified in flight or at rest? |
| **R** | Repudiation | Can an actor deny what they did? |
| **I** | Information disclosure | Can data reach someone who shouldn't have it? |
| **D** | Denial of service | Can availability be destroyed — or the budget? |
| **E** | Elevation of privilege | Can someone gain capability they weren't granted? |

**OWASP ASI01–ASI10 + LLM01–LLM10 — for the AI surface.** Walk them explicitly; the agent-specific
ones have no STRIDE analogue. Goal hijack, tool misuse, agent identity abuse, memory poisoning,
inter-agent trust, cascading failure, human-agent trust exploitation, rogue agents. Details:
`policy/frameworks/owasp-agentic-top10.md`.

**MITRE ATLAS** for naming *how*: cite technique IDs so a threat is checkable rather than a worry.

For privacy-relevant systems, LINDDUN covers what STRIDE doesn't (linkability, identifiability,
non-repudiation as a *harm*, detectability, disclosure, unawareness, non-compliance).

## Step 3 — rate, without inventing precision

Likelihood × impact, on a three-point scale, argued in a sentence. **Do not build a numeric scoring
model** — a 7.4 implies a precision nobody has and starts arguments about the number instead of the
threat. What actually matters:

- Is this reachable by an unauthenticated attacker?
- Does exploiting it require a mistake by someone else, or just the attacker?
- What's the blast radius — one tenant, or everything?
- Is it detectable if it happens?

That last one is routinely skipped and is often the cheapest thing to fix.

## Step 4 — every threat ends in a decision

The rule that makes the artifact worth writing. Per threat, exactly one of:

- **Mitigated** — name the control *and where it lives* (a canon rule, a hook, a manifest, a code
  path). "We validate input" is not a control; `identity-and-access.md` `I4`, enforced in
  `api/authz.py` is.
- **Accepted** — with a named owner, a reason, and a review date. Goes in
  `memory/process/risk-register.md`.
- **Transferred** — to a provider or a contract; record what they've actually attested to.
- **Eliminated** — the design changed. This is the best outcome and the reason to do this at P3.

A threat with none of these is an unfinished sentence.

## The artifact

Lives at `.claude/memory/process/threat-model.md` (template: `PROCESS.md` T9). It carries: scope and
version, the component/flow picture, the trust boundaries, the assets, the threat table
(id · boundary · threat · framework id · likelihood · impact · decision · control location), the
accepted-risk list with review dates, and what's explicitly **out of scope** — which is as important
as what's in, because an unstated exclusion reads as an oversight.

**It is versioned and dated.** A threat model with no date is assumed current and isn't.

## Gotchas

- **Threat modelling the deployment while ignoring the pipeline.** CI holds production credentials
  and nobody models it (`CICD-SEC-5`).
- **Assuming the model is trusted infrastructure.** It's the component most likely to be
  attacker-influenced; it belongs *inside* the threat model, not outside it.
- **Stopping at the perimeter.** "It's internal" describes network position, not trust
  (`platform-security.md` `P5`, `authn-authz` `I7`).
- **One-and-done.** An unreviewed threat model decays into fiction as the system changes; the
  `session-orient.py` hook surfaces its age at session start for exactly this reason.
- **No detection column.** Half of threat treatment is noticing; if nothing in the model says how
  you'd know, you wouldn't.
