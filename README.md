# claude-for-ai-platforms

A Claude Code scaffold for two kinds of work, picked at setup:

- **Build an AI platform securely** — agent and LLM security, Kubernetes, SRE, observability,
  identity, and supply chain, grounded in published framework canon.
- **Build a model** — computer vision, tabular, time-series, or LLM fine-tuning, with the split
  discipline, statistical honesty, and error-analysis habits that make a result trustworthy.

Drop it into a project, run `/setup`, answer what you're building. From then on the agent works
inside guardrails you didn't have to write: hardened manifests by default, a phase-gate process that
demands evidence before it advances, and canon rules a review finding can cite by number.

**It does not replace:** your tools, your judgement, a security team, a penetration test, or legal
advice. It makes the defaults good and the omissions visible.

---

**Contents** — [Which one am I?](#which-one-am-i) · [Quick start](#quick-start) ·
[What it actually does](#what-it-actually-does) ·
[The security model](#the-security-model-stated-plainly) · [Reference](#reference) ·
[Verifying the scaffold](#verifying-the-scaffold-itself) · [Contributing](#contributing)

---

## Which one am I?

The one question the whole scaffold configures itself from. `/intake` asks it; this table is what it
does with your answer.

| If you're building… | Family | Turns on |
|---|---|---|
| An agent with tools and memory | Platform | `agent-security` · `mcp-security` · `guardrails` · `agent-evaluation` · `kubernetes` · `authn-authz` |
| A RAG service | Platform | the above, plus `vector-stores` (tenant filtering **in the query**, not the prompt) |
| An inference platform | Platform | `serving` · `kubernetes` · `observability` · `reliability-sre` · `supply-chain-security` |
| An eval harness | Platform | `agent-evaluation` · `evaluation` · `statistics` · `llm-red-teaming` |
| An MLOps / data platform | Platform | `workflow-orchestration` · `object-and-lakehouse` · `gitops` · `secure-cicd` |
| A CV / tabular / time-series model | Model | `datasets` · `eda` · `evaluation` · `statistics` · `visualization` · the lane's own skills |
| An LLM fine-tune | Model | the above, plus `finetune-unsloth` · `llm-eval` — **and `agent-security`** |
| Both (train it *and* ship it) | Both | both blocks; say so at `/intake` rather than picking one |

<!-- always-on:start -->
**Only a five-skill chassis is always on** — `process` · `governance` · `testing` · `memory` ·
`wave-planning`.
<!-- always-on:end -->
Everything else is gated, so you carry context for the family you picked, not both. A skill that's
off costs nothing.

> One question doesn't follow from the lane: **is there an LLM or an agent in this at all?** It
> decides `agent-security`, and the archetype doesn't imply it — a "tabular" project that calls a
> model has an agentic surface; an inference platform serving a classifier may not.

Neither half is bolted on. Evaluating an AI platform is an empirical problem, and the habits that
make *model* evaluation trustworthy are the same ones that make *agent* evaluation trustworthy — so
the DS layer earns its place on the platform side, and a model that ships eventually needs somewhere
to run.

## Quick start

```bash
git clone https://github.com/BrendenKennedy/claude-for-ai-platforms.git
cd /path/to/your-project
/path/to/claude-for-ai-platforms/install.sh .    # never overwrites; safe to re-run
```

Then, in Claude Code:

```
/setup      # git preflight → /intake → /bootstrap → /threat-model → /gate (P1) → /wrapup
```

Or run the pieces yourself: `/intake` (what are we building + the security-posture interview) →
`/bootstrap` (generate and *prove* the skeleton) → `/threat-model` → `/gate`.

New to it? [`docs/TUTORIAL.md`](docs/TUTORIAL.md) is a ~30-minute first project on synthetic data.

## What it actually does

<details>
<summary><b>Writing a Kubernetes manifest</b> — hardened because the template is, not because anyone remembered</summary>

You ask for a deployment. What comes back is Pod Security `restricted`, digest-pinned,
resource-limited, with a named ServiceAccount and `automountServiceAccountToken: false`. If you edit
it to run as root, the write is blocked:

```
[guard-k8s-manifests] Blocked deploy/api.yaml — platform-security canon violation:

  P1  runAsNonRoot: false
      fix: Set runAsNonRoot: true and give the container a non-zero runAsUser.

  Canon: .claude/memory/policy/platform-security.md  (see also `kubernetes` skill)
  If this is a deliberate, recorded exception, add a decision-log entry and mark the
  resource with:  # platform-security-exception: <RULE> <reason>
```

The same constraint is checked three times — at the edit, in CI via `conftest`, and at admission via
Pod Security and Kyverno. Only the last one is a security boundary; the first two exist so you find
out before the rollout.
</details>

<details>
<summary><b>Granting an agent a tool</b> — the design ladder, not a filter</summary>

`agent-security` asks the question that decides the design: *if an attacker fully controlled this
model's output, what could they reach?* The ladder is reduce agency → narrow the tool → constrain
the argument → authorize server-side against the **user's** identity → gate irreversible actions on
a human → cap the blast radius → and only then, detect. Teams reliably start at the last step.

The grant is recorded in `agent-authority.md`, and `guard-agent-config.py` checks edits against it —
so least agency erodes visibly, as a diff, rather than one convenient addition at a time.
</details>

<details>
<summary><b>Adding an MCP server</b> — a dependency with a prompt-injection channel</summary>

Blocked if it can't be pinned; a confirmation dialog if it can. An MCP server supplies tool
descriptions that go straight into the model's instruction context — it is a dependency with a
prompt-injection channel and your credentials, and neither CVE scanning nor SBOM sees any of it. The
`mcp-security` skill covers tool poisoning, the rug pull (a *pinned* server changing its
descriptions), cross-server shadowing, and the confused deputy.
</details>

<details>
<summary><b>Reaching a phase gate</b> — evidence, or it doesn't advance</summary>

`/gate` walks the phase's exit checklist and the security track, demanding a file, a run id, or a
date for each item. "Mostly done" is unchecked. It records a pass or named gate debt in
`phase-state.md`, and refuses to advance the phase while items are open.

The security track **scales with your archetype** — a CV project isn't asked about admission
control, and `N/A — <archetype>` is a valid recorded answer. Silence isn't: an item nobody
considered reads identically to one considered and dismissed, and only one of those is safe.
</details>

## The security model, stated plainly

**The hooks are guardrails against agent *mistakes*, not a sandbox against an adversary.** They
pattern-match; a determined bypass defeats them, and that is accepted — they exist to stop the common
accident cheaply and loudly. The actual boundaries are Claude Code's permission system, the IAM
policy, the RBAC binding, and Kubernetes admission control.

The same honesty applies upward: this repo maps its rules to NIST CSF, SP 800-53, ISO 27001/42001,
SOC 2, and the EU AI Act **for orientation**, and asserts conformance to none of them. What is
actually implemented, with evidence, lives in `control-coverage.md` — and "not evidenced" is an
expected status there, because an overclaimed control is worse than a missing one.

Full threat model: [`.claude/memory/policy/security.md`](.claude/memory/policy/security.md).

## Reference

Every skill, command, agent, and hook with its full description:
[`docs/REFERENCE.md`](docs/REFERENCE.md) — generated from source, so it can't drift.

### Policy canon — `.claude/memory/policy/`

Eight domains, every rule numbered so a hook message, review finding, or decision log can cite
exactly one.

| Domain | Rules | Governs |
|---|---|---|
| `ai-security.md` | `AI1`–`AI12` | Agents and models in the product: injection, tool agency, memory/RAG poisoning, output handling, agent identity, blast radius |
| `platform-security.md` | `P1`–`P11` | Clusters, workloads, images, networks, tenancy, data-store exposure |
| `identity-and-access.md` | `I1`–`I9` | Human and workload identity, authn/authz, tokens, delegated agent authority |
| `supply-chain.md` | `C1`–`C8` | Dependencies, SBOM, signing, provenance, base images, model weights, MCP servers |
| `reliability.md` | `R1`–`R8` | SLOs, error budgets, change safety, degradation, incidents |
| `security.md` | `S1`–`S9` | The development loop: secrets, egress, the agent's own identity |
| `data-governance.md` | `D1`–`D10` | Datasets, labels, licensing, PII, splits, retrieval corpora, store tenancy, encryption, tested restore |
| `model-governance.md` | `M1`–`M16` | Reproducibility, checkpoint provenance, third-party models, prompt versioning, model cards |

Plus `compliance-crosswalk.md` (every rule → CSF 2.0 / 800-53 / ISO / SOC 2 / EU AI Act) and
`frameworks/` — 20 reference documents, each with its version, publisher, verification date, and an
explicit *what we leave*: OWASP LLM Top 10 v2.0, OWASP Agentic Top 10 2026 (ASI01–ASI10), MITRE
ATLAS, NIST AI RMF, CIS Kubernetes v2.0.1, NSA/CISA Kubernetes Hardening v1.2, SP 800-190, Pod
Security Standards, SLSA, NIST SSDF + SP 800-218A, CycloneDX/SPDX, OWASP CI/CD Top 10, SP 800-63-4,
OAuth 2.1/OIDC, SPIFFE/SPIRE, NIST CSF 2.0, SP 800-53, ISO 27001/42001, EU AI Act, Google SRE.

### Skills — `.claude/skills/`

58 skills. See [Which one am I?](#which-one-am-i) for the always-on chassis; everything below is
gated — `/intake` sets the profile, and off costs zero context.

<details>
<summary>The 53 gated skills, by group</summary>

**Security & platform spine:** `agent-security` · `threat-modeling` · `observability` ·
`reliability-sre` · `agent-evaluation`

**DS core:** `datasets` · `evaluation` · `statistics` (on by default — any project with data
measures something) · `eda` · `visualization` · `notebooks` · `reporting`

**Platform:** `kubernetes` · `policy-as-code` · `authn-authz` · `secrets-management` ·
`supply-chain-security` · `secure-cicd` · `iac-terraform` · `gitops` · `containers` · `serving` ·
`monitoring`

**Cloud:** `infra-aws` · `infra-gcp` · `infra-azure` · `local-stack` — each carries the same six
sections (identity + workload identity · managed k8s · serverless · managed DBs · native CI/CD ·
AI services), so they're diffable when moving between clouds

**Data & workflow:** `vector-stores` · `graph-stores` · `relational-stores` · `caching-and-queues` ·
`object-and-lakehouse` · `workflow-orchestration`

**AI security:** `guardrails` · `mcp-security` · `llm-red-teaming`

**Tools:** `env-uv` · `tracking-mlflow` · `config-hydra` · `data-dvc` · `tracking-wandb` ·
`config-omegaconf` · `hpo-optuna`

**Model-building lanes:** `training` · `annotation` · `pipelines` · `tabular` · `timeseries` ·
`wrangling` · `sql` · `data-acquisition` · `finetune-unsloth` · `llm-eval`
</details>

### Subagents — `.claude/agents/`

`security-reviewer` · `threat-modeler` · `platform-engineer` · `sre-analyst` · `red-teamer` ·
`compliance-mapper` · `code-reviewer` · `software-architect` · `data-engineer` · `ml-engineer` ·
`eval-analyst`

### Commands — `.claude/commands/`

- **Setup (one-time):** `/setup` · `/intake` · `/bootstrap`
- **Security:** `/threat-model` · `/sec-review` · `/harden` · `/redteam` · `/compliance`
- **Operations:** `/slo` · `/postmortem`
- **Process:** `/gate` · `/review` · `/report` · `/wrapup`
- **Maintenance:** `/skill-update` · `/upgrade` · `/scaffold-retro`

### Hooks — `.claude/hooks/`

`session-orient` · `validate-bash` · `guard-secrets` · `guard-pyproject` ·
`guard-notebook-outputs` · `guard-k8s-manifests` · `guard-iac` · `guard-agent-config` ·
`validate-python` · `validate-manifests` · `scan-untrusted-content` · `run-leakage-tests` ·
`run-security-tests`

Every hook has block / allow / **fail-open** cases in `.claude/scripts/check-hooks.py`. The
fail-open case is the one nobody tests and the one that bites: a guard that crashes on unexpected
input either blocks everything or nothing.

## Verifying the scaffold itself

```bash
bash .claude/scripts/check-scaffold.sh    # drift, frontmatter, config, install, placeholders, docs
python3 .claude/scripts/check-hooks.py    # every guard: blocks, allows, fails open
```

CI runs both. `check-scaffold.sh` fails if a skill exists on disk but isn't named in `CLAUDE.md` and
this README, **if a skill is listed in the wrong tier here**, if a canon file isn't registered in the
`governance` skill, if a framework id cited in canon doesn't resolve to a document in `frameworks/`,
or if a canon rule id cited in a skill doesn't resolve to a rule that exists — the map and the
territory are kept in sync mechanically, because every real bug in this repo's history was drift of
exactly that kind.

It also asserts the thing a scaffold is most likely to get wrong about itself: **the shipped
Kubernetes baseline in `templates/k8s/` must pass the shipped policies in `templates/policies/`**,
and those policies must reject their own bad fixtures. An exemplar that violates its own enforcement
would ship broken to every project generated from it.

## Contributing

Architecture debates start from the recorded decisions in `.claude/memory/reference/` — including
`architecture-security-layers.md`, which explains why canon, skills, hooks, and agents divide the way
they do. Process decisions — why Kubernetes was un-parked, why both skill wings gate, why the
platform work merged back rather than forking — are in
`.claude/memory/process/decision-log.md`. See `CONTRIBUTING.md`.

Previously published as `claude-for-datascience`. The platform half was developed as a fork and
merged back rather than kept separate, because ~60% of the tree is shared and maintaining it twice
was the worse option.

## License

See [`LICENSE`](LICENSE).
