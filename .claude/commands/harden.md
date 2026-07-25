---
description: >
  Audit an existing surface — cluster manifests, IaC, an agent's tool grants, or a CI pipeline —
  against the platform/AI security canon and produce a prioritised remediation plan.
argument-hint: "[target: deploy/ | infra/ | agents | pipeline | all]"
---

Harden an existing surface. Unlike `/sec-review` (which reviews a *change*), this audits what is
**already there** — the accumulated state nobody diffed.

Target: **$ARGUMENTS** — if empty, ask which surface, or audit all four if the project is small.

1. **Enumerate the surface.** Depending on the target:
   - `deploy/` — every manifest and rendered overlay (`kubectl kustomize deploy/overlays/<env>`)
   - `infra/` — every `.tf` file, and the **plan** if one can be produced (policy against the plan
     is strictly stronger than against the source, because it evaluates what will actually exist)
   - `agents` — `.mcp.json`, `.claude/agents/*`, tool definitions in code, and
     `.claude/memory/process/agent-authority.md`
   - `pipeline` — `.github/workflows/*`, runner configuration, and cloud trust policies

2. **Check against canon, rule by rule.** Read the relevant file(s) in `.claude/memory/policy/` and
   walk the rules — `platform-security.md` `P1`–`P10`, `supply-chain.md` `C1`–`C8`,
   `identity-and-access.md` `I1`–`I9`, `ai-security.md` `AI1`–`AI12`. Use the `security-reviewer`
   agent for the detailed pass on large surfaces.

3. **Run the tooling that exists**, and say which was unavailable rather than silently skipping:
   `conftest test -p policies/ -` · `trivy config <dir>` · `checkov -d infra/` · `kubeconform` ·
   `kube-bench` (self-managed clusters) · `python3 .claude/scripts/check-hooks.py`

4. **Prioritise honestly.** Order by *exploitability × blast radius*, not by how easy the fix is.
   Separate:
   - **Fix now** — exploitable, or a canon violation with no recorded exception
   - **Fix next** — real weakness, needs a decision or a migration
   - **Accept + record** — genuinely constrained by something outside this repo; needs a
     decision-log entry with a compensating control and a review date

5. **Offer to apply the mechanical fixes** — missing resource limits, `:latest` → digest, missing
   default-deny NetworkPolicy, `automountServiceAccountToken`, unpinned actions. **Ask before
   changing anything**, and dispatch `platform-engineer` to do it. Anything that changes behaviour
   (network paths, RBAC scope, auth) is a decision for the user, not a mechanical fix.

6. **Update `.claude/memory/process/control-coverage.md`** with what you found implemented,
   evidenced, and missing — that file is what a questionnaire gets answered from, and this audit is
   how it stays true.

Report: what you audited, what tooling ran, the prioritised findings, and what you'd fix first.
