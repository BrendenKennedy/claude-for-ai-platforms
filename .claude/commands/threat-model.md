---
description: >
  Build or refresh the project's threat model — map trust boundaries, enumerate threats against
  STRIDE + OWASP ASI/LLM + MITRE ATLAS, and drive every one to a decision. Writes
  .claude/memory/process/threat-model.md.
argument-hint: "[optional focus e.g. the retrieval path, the CI pipeline]"
---

Build or refresh this project's threat model. A threat model written at P3 changes the design; one
written at P6 is documentation. If we're past P3 and this is the first one, say so — it's late, and
that's worth naming rather than papering over.

Focus, if given: **$ARGUMENTS**

1. **Load the context.**
   @.claude/memory/process/project-definition.md
   @.claude/memory/process/threat-model.md
   Model what is actually in scope per the scope ledger — not what could theoretically be built.
   If a threat model already exists, you are **refreshing** it: preserve accepted risks and their
   review dates, and report what changed.

2. **Dispatch the `threat-modeler` agent** with the project context and the focus above. It is
   read-only and returns the model plus the gaps.

3. **Review what it returns before writing it.** Specifically check:
   - Are the AI-specific boundaries there — application→model, model→tool execution, retrieved
     document→prompt, agent→agent? These are the ones a generic threat model omits.
   - Is **CI/CD** modelled as an actor with production credentials? It usually isn't.
   - Does every threat end in a decision, with the control's *location* named — a canon rule plus a
     file, not "we validate input"?
   - Is there a **detection** answer per threat, or only prevention?

4. **Write `.claude/memory/process/threat-model.md`** using template T9 in `PROCESS.md`. It must
   carry a version and a date — an undated threat model is assumed current and isn't, and
   `session-orient.py` surfaces its age at every session start.

5. **Propagate the outputs, don't strand them:**
   - Accepted risks → `.claude/memory/process/risk-register.md`, each with an owner and a review
     date.
   - Gaps that need work → `.claude/memory/roadmap.md`.
   - Any judgment call (accepting a risk, scoping something out) → the relevant policy decision log.

6. **Report** to the user: the trust boundaries found, the top gaps, what changed since the last
   version, and what you wrote where. Lead with the gaps — that's the part that's actionable.
