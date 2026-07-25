---
name: governance
description: >
  Which policy governs a change and how to apply it — the index + locate→load→apply→record protocol
  over the policy canon in `.claude/memory/policy/`. Load for any governed change: agent
  tools/memory/retrieval (ai-security), clusters/workloads/images/networks (platform-security),
  authn/authz/tokens/permissions (identity-and-access), dependencies/SBOM/signing/MCP servers
  (supply-chain), SLOs/incidents (reliability), secrets/credentials/egress (security), dataset
  licensing/PII (data-governance), model release (model-governance), phase gates/scope
  (process → `PROCESS.md`). Triggers: policy, governance, is this allowed, compliance, decision log,
  ADR, record a decision, secret, credential, API key, .env, PII, data egress, threat model, prompt
  injection, agent permissions, least agency, RBAC, pod security, privileged container, network
  policy, OAuth, JWT, token scope, rotate credential, SBOM, signing, provenance, MCP server, SLO,
  error budget, incident, postmortem, license, model card, phase gate, OWASP, NIST, CIS, SLSA,
  audit, control mapping. Policy text lives only in the canon files — this skill indexes and never
  restates.
---

# Governance — the index + access protocol over this repo's policy

> On-demand: load this for any governed change — locating the right policy, applying it, recording a
> decision, or adding a policy domain. It's the map + protocol; the authored policy text lives in
> `.claude/memory/policy/` (below) and wins on any conflict. Run the loop directly whenever you touch a
> governed domain — no agent required.

## The governance model (two layers, one source of truth)
- **Canon** — the authored policy, a version-controlled file at `.claude/memory/policy/<domain>.md`. The
  source of truth. A human reads it; code is written and data is shaped from it.
- **This skill** — the index across domains + the access protocol + (folded-in) each domain's sharp
  triggers, so a governed change auto-surfaces governance and routes to the right canon. It never restates
  policy.

Policy text lives in exactly one place — the canon file — never copied into a skill or duplicated
elsewhere.

## Policy index (the domains + where their canon lives)
> Ships with the authored domains below. Add a row per new governed domain (e.g. a `code-conventions.md`
> once your Python idioms stabilize); each row's canon file goes in `.claude/memory/policy/`.

| Domain | Rules | Governs | Canon (`.claude/memory/policy/`) | Apply when… |
|---|---|---|---|---|
| `ai-security` | `AI#` | agents & models in the **product** — injection, tool agency, memory/RAG poisoning, output handling, agent identity, blast radius | `ai-security.md` | granting an agent a tool, wiring retrieval, persisting memory, connecting agents, shipping model output into another system |
| `platform-security` | `P#` | clusters, workloads, images, networks, tenancy | `platform-security.md` | writing a manifest, provisioning a cluster/namespace, building a runtime image, opening a network path |
| `identity-and-access` | `I#` | human & workload identity, authn/authz, tokens, delegated agent authority | `identity-and-access.md` | adding a login, issuing/validating a token, granting a permission, service-to-service traffic |
| `supply-chain` | `C#` | dependencies, SBOM, signing, provenance, base images, model weights, MCP servers | `supply-chain.md` | adding a dependency, publishing an artifact, choosing a base image, pulling weights, adding an MCP server |
| `reliability` | `R#` | SLOs & error budgets, change safety, degradation, incidents | `reliability.md` | shipping to users, defining "working", changing production, responding to an incident |
| `security` | `S#` | the **development loop** — secrets, what may be logged/egressed, the agent's own identity, dev supply chain | `security.md` | touching anything that holds or moves a credential, adding logging calls, or sending data anywhere external |
| `data-governance` | `D#` | datasets, labels, licensing, PII/sensitive imagery, splits & leakage, retrieval corpora | `data-governance.md` | ingesting/splitting/labeling data, adding a dataset, building a RAG corpus |
| `model-governance` | `M#` | model reproducibility, checkpoint provenance, third-party models, prompt versioning, model cards, release | `model-governance.md` | training, checkpointing, changing a prompt, or releasing a model |
| `process` | — | the project lifecycle — phases, exit gates, scope, risks, kill/pivot | **`PROCESS.md` (repo root** — travels with the project, so its canon lives there, not in `policy/`; live state in `.claude/memory/process/`, run via the `process` skill + `/gate`**)** | starting/advancing/closing a phase, changing scope, or making a kill/pivot call |
| `<code-conventions>` | — | how any source module is written — the repeated Python idioms | `<code-conventions.md>` | writing or editing any source file (add this canon when your idioms settle) |

Each authored domain's decision log is `<domain>-decision-log.md` beside its canon; `process` logs to
`.claude/memory/process/decision-log.md`.

**Two files here are reference, not canon** — they carry no rules and have no decision log:
`compliance-crosswalk.md` (every rule above mapped to CSF 2.0 / 800-53 / ISO / SOC 2 / EU AI Act) and
`frameworks/` (the published standards the rules are sourced from — OWASP, NIST, CIS, SLSA and the
rest, each with its version and verification date). **Canon cites framework control IDs
(`[LLM01]`, `[CIS 5.2]`); the framework text lives only in `frameworks/`.**

_Add a row per new domain. If a domain produces a generated artifact (a spec the code implements), note
that it's data, not policy, and lives outside `policy/`. Decision logs are append-only and created on the
first judgment call — they won't exist until then._

### Picking the right file
The common mistake is reaching for `security.md` for everything. It governs **this repo and this
machine**; the system being *built* is governed by `ai-security` / `platform-security` /
`identity-and-access` / `supply-chain` / `reliability`. Several often apply to one change — apply all
of them, and the stricter rule wins.

## Access protocol — locate → load → apply → record
1. **Locate.** Match the change to a domain above (several can apply to one change). No matching domain
   ⇒ no policy yet; proceed or propose one.
2. **Load.** Read that domain's **canon** file in `.claude/memory/policy/`. Canon wins on conflict.
3. **Apply.** Follow the canon — copy the idioms, run the decision procedure, or check the invariants +
   checklist for that domain.
4. **Record.** If the domain has a **decision log**, log every irreducible judgment call there
   (append-only: what / which rule / why). Prescriptive domains (a fixed style guide) have no log.

## Add a policy domain (the extension protocol)
1. **Author the canon** at `.claude/memory/policy/<name>.md` — the authored source of truth.
2. **Register a row** in the Policy index above, and fold that domain's sharp triggers into this skill's
   `description` so governed changes auto-surface it.
3. If the domain makes judgment calls over time, add a **decision log** beside its canon.

Keep policy in ONE skill — this one; don't spawn a skill per policy domain. One index, many canon files.

## Who runs this
Any session or specialist that touches a governed domain runs the locate→load→apply→record loop directly —
the decentralized model: each specialist agent gets a one-line pointer to this skill for the policy on what
it edits. There is deliberately **no governance-manager agent** (policy is applied where the work happens,
not by a coordinator).

## Gotcha
This skill only **indexes and explains access** — it is deliberately thin. If you find yourself restating
idioms, rules, or checklists here, stop: that belongs in the canon file (single source of truth). Policy
canon lives in `.claude/memory/policy/`; this skill points at it and never copies it.
