---
description: >
  Review the current diff through the AI-platform security lens — agent tool grants, injection
  paths, manifests, IAM/RBAC, token validation, secrets, supply-chain pinning — with every finding
  cited to a canon rule.
argument-hint: "[optional path or target; defaults to the working-tree diff]"
---

Run a security review of the current change. This is the security counterpart to `/review`
(correctness + the ML lens) — run both on a change that is substantially both.

Target: **$ARGUMENTS** — if empty, the working-tree diff.

1. **Dispatch the `security-reviewer` agent** with the target. It is read-only and returns findings
   grouped by severity, each citing the canon rule it violates.

2. **If the change touches an agent's tool surface** — tool grants, MCP servers, prompts, retrieval,
   or memory — also check `.claude/memory/process/agent-authority.md`. A tool granted in code but
   not declared there is itself a finding (`ai-security.md` `AI2`).

3. **Do not accept a finding you can't verify.** Before reporting, confirm each one against the
   surrounding code — if a control exists one layer out (a validated schema, a server-side
   authorization check, an admission policy), the finding is wrong. A reviewer that cries wolf gets
   ignored, which costs more than the finding was worth.

4. **Check the decision logs before calling something a defect.** A recorded, justified exception in
   `.claude/memory/policy/*-decision-log.md` is not a finding — but one **past its review date** is,
   because it was accepted as temporary and has become permanent by default.

5. **Report** findings to the user grouped Blocking / Should-fix / Nit, each with `path:line`, the
   canon rule, the concrete impact, and the fix. End with a one-line verdict.
   **If the diff is clean, say so plainly.** Do not invent findings to justify the run.

Do not fix anything unless the user asks — the review and the fix are separate decisions.
