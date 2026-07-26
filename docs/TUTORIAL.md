# Tutorial — your first project on the scaffold

A hands-on path from empty directory to a threat-modelled, gated project. Everything here runs for
real, with **nothing provisioned** — no cluster, no cloud account, no GPU. Time: ~40 minutes of
interaction.

The scaffold serves two families and configures itself differently for each, so this tutorial does
too: the setup below is shared, then you pick a path.

## 0. What you need

[Claude Code](https://claude.com/claude-code) · `git` · [`uv`](https://docs.astral.sh/uv/).
Optionally `kubectl` + `conftest` for the platform path (manifests render and validate without a
cluster). No cloud account required.

## 1. Install

```bash
git clone https://github.com/BrendenKennedy/claude-for-ai-platforms.git ~/dev/claude-for-ai-platforms
mkdir my-project && cd my-project && git init
~/dev/claude-for-ai-platforms/install.sh .
```

The installer copies `.claude/` (skills, agents, commands, hooks, and the policy canon), `CLAUDE.md`
(the index the agent reads every session), and `PROCESS.md` (the phase-gate framework). It never
overwrites existing files and stamps `.claude/scaffold-version` so `/upgrade` can serve you later.

It does **not** copy this tutorial or the README — inside your project, `CLAUDE.md` is the index and
the upstream repo is the manual.

## 2. `/setup` — one guided session

Open Claude Code and run `/setup`. Six stages, each ending in a checkpoint commit:

**0. Git preflight** — confirms you're in a repo with a clean tree, so every later stage has
something to check point against.

**1. `/intake`** — three interviews back to back:

- **The definition interview** — *"what are we building?"*, and it will push back. Answer honestly,
  including "I don't know" — unknowns become recorded open questions, not invented answers. This is
  where you pick your **family** and **archetype**, and everything downstream follows from it.
- **The security-posture interview** — the one that shapes the most. Data sensitivity, tenancy,
  internet exposure, **agent autonomy**, which actions need a human, and whether you're anywhere near
  an EU AI Act use case. Say "multi-tenant" and `platform-security.md` `P10` and `data-governance.md`
  `D8` stop being theoretical. Say "the agent can take irreversible actions" and `agent-authority.md`
  becomes mandatory rather than advisory. Asked whichever family you picked — a model-building
  project with an LLM in it has an agentic threat surface too.
- **The stack interview** — tracker, config system, data versioning, and for platform work
  orchestration, cloud, IaC, delivery, identity provider, secrets backend, observability, model
  providers, MCP servers. Each answer flips lane skills on; everything else stays off and costs you
  nothing.

**2. `/bootstrap`** — generates the skeleton the skills already describe, then **proves it runs**.
What it generates depends on your lane: `deploy/` + `policies/` + `observability/` + `evals/` for a
platform archetype, or the `conf/` tree + `train.py`/`eval.py` for a model one. Until this runs, the
skills document a project you don't have.

**3. `/threat-model`** — before the gate, deliberately. At this stage a threat model can still change
the architecture cheaply; produced at delivery it is documentation.

**4. `/gate`** — the P1 review. The definition doc is most of the evidence, so this should be quick.

**5. Land + `/wrapup`** — the session note and the merge.

## 3. Pick your path

Both paths follow the same shape — watch a hook refuse you, build the thing, break it on purpose,
then the daily rhythm — so they're worth skimming across if you'll eventually do both.

| If `/intake` put you in… | Go to |
|---|---|
| **Platform** — agent platform, RAG service, inference platform, eval harness, MLOps platform | [**`tutorial-platform.md`**](tutorial-platform.md) |
| **Model** — CV, tabular, time-series, LLM fine-tuning | [**`tutorial-model.md`**](tutorial-model.md) |

## Where to go deeper

[REFERENCE.md](REFERENCE.md) — every skill/command/agent/hook, one line each ·
[PROCESS.md](../PROCESS.md) — the framework, its lineage, and the §3.9 security track ·
[`policy/`](../.claude/memory/policy/) — the canon, and the 20 framework documents behind it ·
[CONTRIBUTING.md](../CONTRIBUTING.md) — extending the scaffold, and the stability contract.
