---
description: >
  Run the current phase's exit-gate review (PROCESS.md §3.8) — walk the checklist demanding written
  evidence, review the risk register, and record pass or gate debt in the phase-state file. Refuses
  to advance the phase while items are unchecked.
argument-hint: [phase e.g. P2]
---

Run a phase-gate review per `PROCESS.md` §3.8. The gate is a checklist filled with **evidence, not
assent** — a file path, a number, a link, a table row. "Yeah we did that" does not check a box.

1. **Load state.** Read `@PROCESS.md` (the phase definitions + exit gates) and
   `@.claude/memory/process/phase-state.md` (the current phase + gate history). The phase under
   review is `$1` if given, otherwise the current phase in the phase-state file. If the phase-state
   file says the project hasn't started, the review target is P1.

2. **Walk the checklist.** For each item in that phase's exit gate in PROCESS.md:
   - Ask the user for (or locate in the repo yourself) the **evidence** — then record the item in
     the phase-state file as `[x]` with a one-line evidence pointer.
   - A conditional item (e.g., P2's labeling items) may be recorded `N/A` **with a written reason**.
   - No evidence → it stays `[ ]` with one line on exactly what's missing.
   Don't soften: an item that's "mostly done" is unchecked.

3. **Walk the security & reliability track (`PROCESS.md` §3.9).** Every phase gate carries these
   items alongside the delivery ones, and they take evidence on exactly the same terms — a file, a
   run id, a date. They are the ones most likely to be waved through, so ask for the artifact.

   **First read the archetype from `project-definition.md` and size the track to it** (§3.9 table).
   A cv/tabular/time-series project with no LLM in it does not carry the cluster and adversarial
   items; a model-building project *with* an LLM does carry the AI-surface ones. Mark the items that
   don't apply **`N/A — <archetype>`**, explicitly, in the phase-state record. Do not skip them
   silently: an item nobody considered looks exactly like one that was considered and dismissed, and
   only one of those is safe. If the definition doc has no archetype, that is itself gate debt —
   `/intake` hasn't run.
   - **Threat model current** (P3 onward) — `.claude/memory/process/threat-model.md` exists, is
     dated, and its version covers the architecture as it stands now. A threat model predating the
     current design is unchecked, not checked.
   - **Controls implemented** (P4) — the canon rules this phase's work touches have a mechanism, not
     just prose. `/harden` or `compliance-mapper` produces the evidence.
   - **Adversarial run recorded** (P5) — a `/redteam` run with a date and coverage, per
     `model-governance.md` `M16`. "We tried some prompts" is not a run.
   - **SLOs + runbooks + rollback tested** (P6) — `slo-register.md` has targets *with agreed
     consequences*, and the rollback has actually been exercised (`reliability.md` `R3`).
   - **Monitoring live and IR path known** (P7).

   **Expired policy exceptions are gate debt.** Check `.claude/memory/policy/*-decision-log.md` for
   any exception past its review date — it was accepted as temporary and has become permanent by
   default, which is precisely the thing a gate exists to catch.

4. **Review the risk register.** Read `@.claude/memory/process/risk-register.md`. With the user:
   are the listed risks still live, are mitigations current, did this phase surface new risks?
   Update the table. Threat-model gaps and unfixed red-team findings live here too — they are risks,
   not a separate ledger.

5. **Verdict — and this is the part that must not bend:**
   - **All items `[x]` or `N/A`-with-reason** → record **PASS** (date + reviewer) in the phase-state
     file's gate history, advance **Current phase** to the next phase, and clear any gate debt for
     the passed phase. **Then cascade to the backlog:** update `@.claude/memory/roadmap.md` in the
     same step — move the just-passed gate's item out of **Now / in progress** into **Done (recent)**
     (dated), and surface the next phase's work in **Now**. The phase ledger and the backlog drift
     apart otherwise (a recurring dogfood friction: `/gate` advanced the ledger but left the roadmap
     stale for wrapup to reconcile by hand) — don't leave that reconciliation for later.
   - **Any item unchecked** → record **BLOCKED** in the gate history and list the unchecked items
     under **Gate debt**. Do **not** advance the phase, and do not offer to "advance anyway" — the
     override path is the user editing the phase-state file themselves, deliberately.

6. **Record decisions.** Any judgment call made during the review (a threshold chosen, a risk
   accepted, a scope cut) goes through the `governance` skill's decision-log protocol — one line,
   append-only.

Report the verdict, the evidence table, and (if blocked) the shortest path to clearing each debt item.
