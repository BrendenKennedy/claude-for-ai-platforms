# Tutorial — the Platform path

Continues from [`TUTORIAL.md`](TUTORIAL.md), which covers install and `/setup`. You should have a
`deploy/` tree that renders, `policies/` whose bad fixtures actually fail, and a passed P1 gate.

One thing worth checking before you go on: `/bootstrap` proved the policy suite by running
`conftest verify` — confirming the policies *reject* their bad fixture, not merely that they run. A
policy suite whose bad fixture passes is enforcing nothing, and that check is the one people skip.

## 1. Watch a hook refuse you

This is a `PreToolUse` hook: it gates **Claude's** edits, not yours — editing in your own editor
bypasses it, which is the point. So ask Claude to relax `deploy/base/deployment.yaml`: set
`runAsNonRoot: false`, or change the digest-pinned image to a `:latest` tag. The write is blocked:

```
[guard-k8s-manifests] Blocked deploy/base/deployment.yaml — platform-security canon violation:

  P1  runAsNonRoot: false
      fix: Set runAsNonRoot: true and give the container a non-zero runAsUser.

  Canon: .claude/memory/policy/platform-security.md  (see also `kubernetes` skill)
  If this is a deliberate, recorded exception, add a decision-log entry and mark the
  resource with:  # platform-security-exception: <RULE> <reason>
```

Three things to take from that message. It names the **rule**, so the reasoning is one file away.
It names the **fix**, not just the problem. And it offers an **exception path** — a guard with no way
out gets deleted rather than argued with, so the way out is recorded rather than silent.

The same constraint is checked three times: here at the edit, in CI via `conftest`, and at admission
via Pod Security. **Only the last is a security boundary** — the first two exist so you find out
before a rollout at 2am. `security.md` `S1` says this plainly, and it's worth believing: never treat
a green hook as clearance.

## 2. Build the thing

Work conversationally; the skills load themselves. Wiring retrieval is where the canon earns its
keep — ask for a RAG pipeline and `vector-stores` will insist the tenant filter goes **in the query,
not the prompt**:

```python
results = store.search(query_vec, top_k=10, filter={"tenant_id": ctx.tenant_id})
```

Not an instruction telling the model to ignore documents it can see. If the retriever returned
another tenant's chunk, the breach already happened — that's `D8`, and it's the difference between a
control and a hope.

Grant the agent a tool and `agent-security` walks the ladder: **remove the capability** before
constraining it, constrain it before authorizing it, authorize server-side against the *user's*
identity before gating on a human, and only then reach for a filter. Teams reliably start at the
filter. The grant lands in `agent-authority.md`, and `guard-agent-config.py` checks future edits
against it — so least agency erodes visibly, as a diff, instead of one convenient addition at a time.

Quick questions need no ceremony: *"what's in this manifest?"* is served directly — gates govern
project work, not curiosity.

## 3. Break it on purpose

`/redteam` runs an adversarial campaign against **your own** system, organised by OWASP ASI risk and
MITRE ATLAS tactic so the gaps are visible rather than silent. Expect it to find something, and
expect it to be indirect injection — a payload in a retrieved document, not in the user's message.
Direct injection is mostly a nuisance; the user already has the user's permissions.

Every finding becomes a regression case in `evals/`, and the safety suite gates CI **absolutely** —
any regression fails the build. That's what stops a fixed finding coming back.

## 4. The daily rhythm

- **`/review`** and **`/sec-review`** before committing — correctness plus the ML lens, then the
  security lens with every finding cited to a canon rule.
- **`/slo`** before you ship. It will ask the uncomfortable question: *what happens when the error
  budget is spent?* Answer it now, because an SLO with no agreed consequence is a dashboard.
- **`/wrapup`** when you stop — the session note that lets tomorrow answer *"why is that namespace
  `baseline`?"*
- **`/gate`** at phase boundaries — **expect your first BLOCKED verdict early**, usually on "threat
  model current" or "rollback exercised." That's the system working: the debt is named, you keep
  working the phase, and nothing slides forward silently. An untested rollback is a plan, not a
  capability, and the gate is where that distinction gets enforced.

## 5. Prove it to someone else

`/compliance` maps what you've **actually implemented** against the crosswalk — and reports
"not evidenced" where it can't find a mechanism. That status is a feature. An overclaimed control is
worse than a missing one because it stops anyone looking, and `control-coverage.md` is the file a
security questionnaire gets answered from precisely because it's honest.

`/report` assembles a deliverable from the repo's own records; every number cites a run id, and
anything it can't back becomes `[TODO: evidence]` rather than a plausible guess.

## 6. Keep it current

- **`/skill-update`** after you upgrade a tool — syncs that skill's facts to the version you run.
  The framework docs in `policy/frameworks/` carry verification dates for the same reason: security
  frameworks move faster than tools, and an unversioned one reads as current when it isn't.
- **`/harden`** periodically on `deploy/`, `infra/`, or the agent's tool surface — it audits what
  accumulated, as opposed to `/sec-review` which reviews what changed.
- **`/upgrade`** after a new scaffold release.
- After shipping, run the **retro** (PROCESS.md Part V) and the **`/scaffold-retro`**: edit the
  process itself with what the gates caught and missed. The process improving per project is the
  point of the whole system.

## Where to go deeper

[REFERENCE.md](REFERENCE.md) — every skill/command/agent/hook, one line each ·
[PROCESS.md](../PROCESS.md) — the framework, its lineage, and the §3.9 security track ·
[`policy/`](../.claude/memory/policy/) — the canon, and the 20 framework documents behind it ·
[CONTRIBUTING.md](../CONTRIBUTING.md) — extending the scaffold, and the stability contract.
