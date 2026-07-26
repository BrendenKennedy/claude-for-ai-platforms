---
description: >
  Full one-time project setup in one guided session — git preflight, then /intake (definition +
  security posture + stack) → /bootstrap (skeleton, proven) → /threat-model (before the gate, while
  the design is still cheap to change) → /gate (P1 review) → land + /wrapup, with a checkpoint
  commit per stage. Thin orchestrator: the logic lives in the piece commands; this sequences them
  and manages git.
allowed-tools: "*"
disable-model-invocation: true
---

Run the complete project setup end-to-end. This command is a **sequencer, not a source of truth** —
the same rule `/bootstrap` applies to skills: invoke each piece command below and follow it
**verbatim**; never reimplement, summarize, or shortcut its content. What this command owns is the
ordering and the **git management** between pieces, so setup ends as clean committed history, not a
pile of uncommitted files.

## 0. Git preflight

- `git rev-parse --git-dir` — no repo? Ask, then `git init` and commit the pre-setup state as-is
  (`chore: pre-scaffold state`) so everything setup does is diffable against it.
- `git status` — **pre-existing uncommitted changes are not yours to bundle.** If there are any,
  stop and ask: commit them first (their own commit, their own message), stash, or abort.
- Branch: on a fresh/empty project, work directly on the default branch — there's nothing to
  protect yet. If the repo already carries real code, branch `setup/scaffold` and land it at the
  end per the landing convention `/intake` captures.

## 1. `/intake` — definition + stack

Invoke the `intake` command and follow it verbatim (definition interview → stack interview →
`skillOverrides` → placeholders → its report).

**Checkpoint commit** when it completes: the config + definition artifacts
(`.claude/settings.json`, filled skills, `memory/process/*`), message like
`chore: configure scaffold (/intake)`. Use the commit trailer `/intake` just captured, if any —
this commit is the first one it applies to.

## 2. `/bootstrap` — skeleton, proven

Invoke the `bootstrap` command and follow it verbatim — including its "prove it runs" step in full,
whichever form that takes for the lane: real train/eval/resume on synthetic data for a model lane,
or a rendering + policy-conformance + eval-harness pass for a platform lane.

**Checkpoint commit** only after that verification actually passed: the skeleton + tests,
`feat: bootstrap project skeleton (/bootstrap)`. A skeleton whose smoke didn't pass does not get
committed — fix or report, don't checkpoint broken.

## 3. `/threat-model` — the first pass

Invoke the `threat-model` command. Run it **here**, before the P1 gate and before real building
starts: a threat model produced now can still change the design cheaply, and one produced at P6 is
documentation. The security-posture answers from `/intake` (data sensitivity, tenancy, exposure,
agent autonomy, regulatory) are its inputs, so most of the work is already done.

Expect it to be thin at this stage, and say so rather than padding it — an honest first pass naming
the trust boundaries and the top gaps is the deliverable. It gets refreshed at P3 when the
architecture settles, which is when it earns its keep.

**Checkpoint commit:** `docs: initial threat model (/threat-model)`.

## 4. `/gate` — the P1 review

Invoke the `gate` command for P1. The definition doc from step 1 is most of T1's evidence, so this
should be quick — but run it honestly; open questions recorded during the definition stay
unchecked and become gate debt, which is fine and correct. Commit the phase-state/memory updates:
`chore: record P1 gate review (/gate)`.

## 5. Land + `/wrapup` + report

If step 0 used a `setup/scaffold` branch, land it per the captured convention (merge to main
locally, or push + PR).

Then invoke the `wrapup` command verbatim to close the session out: the session note records what
setup built, the checkpoint commits + branch, and the current phase + gate debt (its instructions
already cover this); the roadmap gets the open items. Let wrapup's commit step run as a final
checkpoint (`chore: record setup session (/wrapup)`) so the session note + roadmap land in history
too — the earlier checkpoints covered the build, not the record; landing already happened above.

Finally, report — deferring to each piece's own report for its detail:

- **Commits:** each checkpoint with its hash; branch + landing status.
- **Verdicts:** the P1 gate result (passed / debt items).
- **Recorded:** the session note path from `/wrapup`.
- **Still open:** the human-decision placeholders and gate debt, in one consolidated list.

One-time: re-runs happen at the **piece** level (`/intake` to change stacks, `/bootstrap` to
reshape, `/gate` any time) — not by re-running this command.
