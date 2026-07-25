# claude-for-ai-platform

A Claude Code scaffold for building **AI platforms securely** — agent and LLM security, Kubernetes,
SRE, observability, identity, and supply chain, grounded in published framework canon.

> Forked from [`claude-for-datascience`](https://github.com/BrendenKennedy/claude-for-datascience).
> The data-science layer is kept, not bolted on: evaluating an AI platform is an empirical problem,
> and the split discipline, statistical honesty, and error-analysis habits that make model evaluation
> trustworthy are the same ones that make *agent* evaluation trustworthy.

## What this is

Five ideas, in order of how much they matter:

1. **Security is a track through every phase, not a review at the end.** `PROCESS.md` §3.9 puts a
   threat model at P3, controls and policy-as-code at P4, a recorded adversarial run at P5, SLOs and
   an exercised rollback at P6, and telemetry plus an incident path at P7. `/gate` demands evidence
   for each — a file, a run id, a date. "We'll do a security review before launch" is the failure
   mode this replaces.
2. **Rules that must hold are hooks and permissions, not prose.** A privileged pod, a `0.0.0.0/0`
   ingress rule, an unpinned MCP server, or a JWT pasted into a config file is *blocked at the
   edit*, with a message naming the canon rule it violates. Destructive cluster and infrastructure
   operations get a confirmation dialog that fires even in `bypassPermissions`.
3. **Policy canon with citable rules, sourced from real frameworks.** Eight domains, each rule
   numbered so a review finding, a hook message, or a decision log can cite exactly one
   (`ai-security.md AI5`, `platform-security.md P1`). Twenty framework reference documents —
   OWASP, NIST, CIS, SLSA, SPIFFE, ISO, EU AI Act — each with its version, publisher, verification
   date, and an explicit *what we leave*.
4. **Knowledge that surfaces when it's relevant.** 50 skills; the ones a project doesn't need are
   off and cost nothing.
5. **Memory across sessions.** Decisions, risks, threat models, SLOs, and incidents live in files,
   not in a transcript that scrolls away.

**It does not replace:** your tools, your judgement, a security team, a penetration test, or legal
advice. It makes the defaults good and the omissions visible.

## Quick start

```bash
git clone https://github.com/BrendenKennedy/claude-for-ai-platform.git
cd /path/to/your-project
/path/to/claude-for-ai-platform/install.sh .    # never overwrites; safe to re-run
```

Then, in Claude Code:

```
/setup      # git preflight → /intake → /bootstrap → /threat-model → /gate (P1) → /wrapup
```

Or run the pieces yourself: `/intake` (what are we building + the security-posture interview) →
`/bootstrap` (generate and *prove* the skeleton) → `/threat-model` → `/gate`.

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

## What's in it

### Policy canon — `.claude/memory/policy/`

| Domain | Rules | Governs |
|---|---|---|
| `ai-security.md` | `AI1`–`AI12` | Agents and models in the product: injection, tool agency, memory/RAG poisoning, output handling, agent identity, blast radius |
| `platform-security.md` | `P1`–`P10` | Clusters, workloads, images, networks, tenancy |
| `identity-and-access.md` | `I1`–`I9` | Human and workload identity, authn/authz, tokens, delegated agent authority |
| `supply-chain.md` | `C1`–`C8` | Dependencies, SBOM, signing, provenance, base images, model weights, MCP servers |
| `reliability.md` | `R1`–`R8` | SLOs, error budgets, change safety, degradation, incidents |
| `security.md` | `S1`–`S9` | The development loop: secrets, egress, the agent's own identity |
| `data-governance.md` | `D1`–`D7` | Datasets, labels, licensing, PII, splits, retrieval corpora |
| `model-governance.md` | `M1`–`M16` | Reproducibility, checkpoint provenance, third-party models, prompt versioning, model cards |

Plus `compliance-crosswalk.md` (every rule → CSF 2.0 / 800-53 / ISO / SOC 2 / EU AI Act) and
`frameworks/` — OWASP LLM Top 10 v2.0, OWASP Agentic Top 10 2026 (ASI01–ASI10), MITRE ATLAS, NIST AI
RMF, CIS Kubernetes v2.0.1, NSA/CISA Kubernetes Hardening v1.2, SP 800-190, Pod Security Standards,
SLSA, NIST SSDF + SP 800-218A, CycloneDX/SPDX, OWASP CI/CD Top 10, SP 800-63-4, OAuth 2.1/OIDC,
SPIFFE/SPIRE, NIST CSF 2.0, SP 800-53, ISO 27001/42001, EU AI Act, and Google SRE.

### Skills — `.claude/skills/`

**Always-on chassis:** `process` · `governance` · `testing` · `memory` · `wave-planning`

**Always-on security & platform spine:** `agent-security` · `threat-modeling` · `observability` ·
`reliability-sre` · `agent-evaluation`

**Always-on DS core:** `datasets` · `eda` · `evaluation` · `statistics` · `visualization` ·
`notebooks` · `reporting`

**Gated — platform:** `kubernetes` · `policy-as-code` · `authn-authz` · `secrets-management` ·
`supply-chain-security` · `secure-cicd` · `iac-terraform` · `gitops` · `containers` · `serving` ·
`monitoring`

**Gated — cloud:** `infra-aws` · `infra-gcp` · `infra-azure` · `local-stack`

**Gated — data & workflow:** `vector-stores` · `graph-stores` · `relational-stores` ·
`caching-and-queues` · `object-and-lakehouse` · `workflow-orchestration`

**Gated — AI security:** `guardrails` · `mcp-security` · `llm-red-teaming`

**Gated — tools:** `env-uv` · `tracking-mlflow` · `config-hydra` · `data-dvc` · `tracking-wandb` ·
`config-omegaconf` · `hpo-optuna`

**Gated — model-building lanes:** `training` · `annotation` · `pipelines` · `tabular` ·
`timeseries` · `wrangling` · `sql` · `data-acquisition` · `finetune-unsloth` · `llm-eval`

### Subagents — `.claude/agents/`

`security-reviewer` · `threat-modeler` · `platform-engineer` · `sre-analyst` · `red-teamer` ·
`compliance-mapper` · `code-reviewer` · `software-architect` · `data-engineer` · `ml-engineer` ·
`eval-analyst`

### Commands — `.claude/commands/`

`/setup` · `/intake` · `/bootstrap` · `/threat-model` · `/sec-review` · `/harden` · `/redteam` ·
`/slo` · `/postmortem` · `/compliance` · `/gate` · `/review` · `/report` · `/wrapup` ·
`/skill-update` · `/upgrade` · `/scaffold-retro`

### Hooks — `.claude/hooks/`

`session-orient` · `validate-bash` · `guard-secrets` · `guard-pyproject` ·
`guard-notebook-outputs` · `guard-k8s-manifests` · `guard-iac` · `guard-agent-config` ·
`validate-python` · `validate-manifests` · `scan-untrusted-content` · `run-leakage-tests` ·
`run-security-tests`

Every hook has block / allow / **fail-open** cases in `.claude/scripts/check-hooks.py`. The
fail-open case is the one nobody tests and the one that bites: a guard that crashes on unexpected
input either blocks everything or nothing.

## What it looks like in practice

<details>
<summary>Writing a Kubernetes manifest</summary>

You ask for a deployment. What comes back is Pod Security `restricted`, digest-pinned,
resource-limited, with a named ServiceAccount and `automountServiceAccountToken: false` — because
that is what the template is, not because anyone remembered. If you edit it to run as root, the
write is blocked:

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
<summary>Granting an agent a tool</summary>

`agent-security` asks the question that decides the design: *if an attacker fully controlled this
model's output, what could they reach?* The ladder is reduce agency → narrow the tool → constrain
the argument → authorize server-side against the **user's** identity → gate irreversible actions on
a human → cap the blast radius → and only then, detect. Teams reliably start at the last step.

The grant is recorded in `agent-authority.md`, and `guard-agent-config.py` checks edits against it —
so least agency erodes visibly, as a diff, rather than one convenient addition at a time.
</details>

<details>
<summary>Adding an MCP server</summary>

Blocked if it can't be pinned; a confirmation dialog if it can. An MCP server supplies tool
descriptions that go straight into the model's instruction context — it is a dependency with a
prompt-injection channel and your credentials, and neither CVE scanning nor SBOM sees any of it. The
`mcp-security` skill covers tool poisoning, the rug pull (a *pinned* server changing its
descriptions), cross-server shadowing, and the confused deputy.
</details>

## Verifying the scaffold itself

```bash
bash .claude/scripts/check-scaffold.sh    # drift, frontmatter, config, install, placeholders, docs
python3 .claude/scripts/check-hooks.py    # every guard: blocks, allows, fails open
```

CI runs both. `check-scaffold.sh` fails if a skill exists on disk but isn't named in `CLAUDE.md` and
this README, if a canon file isn't registered in the `governance` skill, or if a framework id cited
in canon doesn't resolve to a document in `frameworks/` — the map and the territory are kept in sync
mechanically, because both real bugs in this repo's history were drift of exactly that kind.

## Contributing

Architecture debates start from the recorded decisions in `.claude/memory/reference/` — including
`architecture-security-layers.md`, which explains why canon, skills, hooks, and agents divide the way
they do, and why this fork un-parked Kubernetes. See `CONTRIBUTING.md`.

## License

See [`LICENSE`](LICENSE).
