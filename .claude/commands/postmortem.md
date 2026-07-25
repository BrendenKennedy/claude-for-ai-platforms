---
description: >
  Write a blameless postmortem for an incident — timeline, impact, systemic contributing factors,
  and tracked actions with owners. Writes to .claude/memory/incidents/.
argument-hint: "[incident slug or short description]"
---

Write a blameless postmortem. Incident: **$ARGUMENTS**

1. **Gather evidence before writing anything.** Dispatch the `sre-analyst` agent to reconstruct what
   happened from telemetry, logs, deploy history, and any timeline kept during the incident
   (`reliability.md` `R7`). Ask the user for what only they have: when it was noticed, who was
   involved, what was tried, when it was resolved.

2. **Write the timeline from evidence, not memory.** Timestamps, what was observed, what was done,
   what happened next. Include the detection time and the *time to detection* — the gap between
   "it broke" and "we knew" is usually the most actionable number in the document.

3. **Blameless means blameless.** Analyse the systemic causes:
   - What made this **possible**? (the design or configuration that permitted it)
   - What made it **slow to detect**? (missing alert, wrong SLI, alert fatigue)
   - What made it **hard to fix**? (no runbook, untested rollback, unclear ownership)

   **No names attached to mistakes. "Human error" is not a root cause** — it's the starting point
   for asking what made the error easy and why nothing caught it. Blame suppresses the reporting
   this process depends on.

4. **Record what went well**, including the controls that worked. They need defending in the next
   prioritisation round, and a postmortem that only lists failures gets them cut.

5. **Actions, each with an owner and a tracking entry.** Cover all three categories, because a
   postmortem that only produces prevention actions has ignored two thirds of the options:
   - **Prevent** recurrence
   - **Detect** faster next time
   - **Reduce impact** when it happens anyway

   Every action gets a row in `.claude/memory/process/risk-register.md`. Actions without an owner
   and a tracking entry are wishes — `reliability.md` `R8`.

6. **If it was a security incident**, note it explicitly: was evidence preserved before remediation?
   Was a credential involved (rotate, don't delete — `security.md` `S4`)? Does the threat model need
   updating? Route findings into `/threat-model` rather than leaving them in the postmortem.

7. **Write it** to `.claude/memory/incidents/YYYY-MM-DD-<slug>.md` using template T11 in
   `PROCESS.md`, and update the SLO register if the incident consumed meaningful error budget.

Report the postmortem path and the actions to the user, with the actions listed first — those are
the part that has to survive the meeting.
