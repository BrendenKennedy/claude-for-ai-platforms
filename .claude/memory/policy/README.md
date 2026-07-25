# `.claude/memory/policy/` — the policy canon

The **authored source of truth** for how this repo's code, data, and platform must be built — the
rules a change has to obey. This directory is the DATA (the canon); the **`governance` skill** is the
access PROTOCOL over it (locate → load → apply → record). Policy text lives here in exactly one place
and is never copied into a skill or CLAUDE.md — those only *point* at it.

> Ships with eight authored domains plus a crosswalk, all registered in the `governance` skill's
> Policy index (the `process` domain's canon is repo-root `PROCESS.md`). Add one canon file per
> additional **governed domain** your project has, then register it there. Do NOT invent domains you
> don't need yet.

## The pattern
- **Canon** = a version-controlled `<domain>.md` here. A human authors it; code is written and data is
  shaped *from* it. It wins on any conflict.
- **Decision log** (optional, per domain) = an append-only `<domain>-decision-log.md` beside the canon,
  recording each irreducible judgment call: *what / which rule / why*. Add one only for domains that
  make case-by-case calls over time (a prescriptive style guide needs none). **They are created on the
  first call — an absent log means no exception has ever been granted, which is information.**
- **Frameworks** = `frameworks/`, the published standards the rules are sourced from. Reference, not
  rules. Canon cites control IDs (`[LLM01]`, `[CIS 5.2]`); the framework text lives there. See
  `frameworks/README.md`.

## Domains

| Domain | Canon file | Rule prefix | Governs | Decision log? |
|---|---|---|---|---|
| `security` | `security.md` | `S#` | The **development loop** — secrets, egress, the agent's own identity, dev supply chain | yes |
| `ai-security` | `ai-security.md` | `AI#` | Agents and models in the **product** — injection, agency, memory/RAG poisoning, output handling, blast radius | yes |
| `platform-security` | `platform-security.md` | `P#` | Clusters, workloads, images, networks, tenancy | yes |
| `identity-and-access` | `identity-and-access.md` | `I#` | Human and workload identity, authn/authz, tokens, delegated agent authority | yes |
| `supply-chain` | `supply-chain.md` | `C#` | Dependencies, SBOM, signing, provenance, base images, models, MCP servers | yes |
| `reliability` | `reliability.md` | `R#` | SLOs, error budgets, change safety, degradation, incidents | yes |
| `data-governance` | `data-governance.md` | `D#` | Datasets, labels, licensing, PII, splits & leakage, RAG corpora | yes |
| `model-governance` | `model-governance.md` | `M#` | Reproducibility, checkpoint provenance, model cards, release | yes |
| *(crosswalk)* | `compliance-crosswalk.md` | — | Maps every rule above to CSF 2.0 / 800-53 / ISO / SOC 2 / EU AI Act. **Reference, asserts nothing.** | no |
| `<code conventions>` | `<code-conventions.md>` | — | The idioms every source module follows | usually no (prescriptive) |

The `process` domain's canon is repo-root **`PROCESS.md`** — it travels with the project, so it lives
there rather than here; live state is in `.claude/memory/process/`.

## Which file for which change

The most common mistake is reaching for `security.md` for everything. It governs *this repo and this
machine*. If the change is about the system being built, it is one of the others:

- Granting an agent a tool, wiring retrieval, persisting agent memory → `ai-security.md`
- Writing a manifest, opening a port, choosing a namespace → `platform-security.md`
- Adding a login, issuing or validating a token, granting a permission → `identity-and-access.md`
- Adding a dependency, building an image, pulling weights, adding an MCP server → `supply-chain.md`
- Defining "working", changing production, responding to an incident → `reliability.md`

Several often apply to one change. Apply all of them; the stricter rule wins.

## Adding a domain
1. Author the canon at `policy/<name>.md`, with numbered rules and a `why` on each.
2. Register a row in the `governance` skill's Policy index **and** fold that domain's sharp trigger
   words into the skill's `description` — miss the second and the domain is unreachable.
3. If the domain makes judgment calls over time, add a decision log beside its canon (lazily, on the
   first call).
4. Add its rules to `compliance-crosswalk.md`.

Keep policy in ONE skill (`governance`) indexing MANY canon files here — don't spawn a skill per
domain.
