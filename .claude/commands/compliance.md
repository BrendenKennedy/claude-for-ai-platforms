---
description: >
  Report control coverage against the crosswalk — which canon rules are actually enforced, which
  are only prose, which framework controls nothing covers, and which exceptions have expired.
argument-hint: "[optional framework focus e.g. SOC 2, NIST CSF, EU AI Act]"
---

Assess control coverage. Focus, if given: **$ARGUMENTS**

**State the caveat first and mean it:** this is a coverage assessment, not a conformance claim. No
framework in the crosswalk has been certified against, and this command cannot make anyone
compliant. Its value is producing an honest evidence trail — including the gaps.

1. **Dispatch the `compliance-mapper` agent.** It walks every canon rule
   (`S#`/`AI#`/`P#`/`I#`/`C#`/`R#`/`D#`/`M#`), finds the mechanism that enforces it, and classifies:
   **Enforced** (something blocks the violation) / **Implemented** (real, but can regress) /
   **Documented** (canon says it; nothing does it) / **Not applicable** (with a written reason) /
   **Not evidenced**.

2. **Hold the line on evidence.** A rule is only Implemented if you can point at a file, a hook, a
   policy, a test, or a configuration. **Reporting a rule as implemented because canon says it
   should be is the exact failure this command exists to prevent** — an overclaimed control is worse
   than a missing one, because it stops anyone looking.

3. **Invert the map.** Walk the framework columns in
   @.claude/memory/policy/compliance-crosswalk.md and find controls that no canon rule addresses.
   Gaps found this way are the ones a self-assessment always misses — you can only evidence rules
   you thought to write.

4. **Check the exception register.** Every entry in `.claude/memory/policy/*-decision-log.md` is a
   coverage caveat. **Flag the ones past their review date separately** — those were accepted as
   temporary and have become permanent by default.

5. **Write `.claude/memory/process/control-coverage.md`** (template T12 in `PROCESS.md`) — status
   and evidence per rule. That file, not this report, is what a questionnaire gets answered from.

6. **Report** to the user:
   - Counts by status, and the three most consequential gaps
   - Framework-side gaps (controls with no rule)
   - Expired exceptions
   - Questionnaire-ready statements **for the well-evidenced controls only**, phrased as what is
     true and verifiable — no aspirational language, no "we ensure that…"

If the user asks "are we compliant?", the honest answer is that compliance is a determination
someone qualified makes against a specific obligation — here is the evidence they'd need, and here
is what's missing. For EU AI Act questions specifically, see
`.claude/memory/policy/frameworks/eu-ai-act.md`: classification is a legal question, the timelines
have already moved once, and this is not legal advice.
