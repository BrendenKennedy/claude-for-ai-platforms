# 2026-07-25 — AI-platform security fork

**Focus:** Fork `claude-for-datascience` 0.9.0 into `claude-for-ai-platform` 1.0.0 — an AI platform
engineering + AI security scaffold, keeping the DS layer underneath.

## State

Complete and CI-green on branch `claude/ai-platform-security-fork-d8z8ha`. All 8 `check-scaffold.sh`
checks pass (175 files install, 79 placeholders intact, re-run idempotent); `check-hooks.py` passes
50 cases across every guard hook.

Built: 5 new canon domains + crosswalk (`AI#`/`P#`/`I#`/`C#`/`R#`), `S#` retrofitted onto
`security.md`, `D7` and `M14`–`M16` added; 20 framework reference docs with verified versions;
5 always-on + 11 gated skills, 7 existing rescoped; 6 agents, 3 rescoped; 6 hooks, 4 extended;
7 commands, 4 modified; PROCESS.md → 1.0.0 with the §3.9 security track and T9–T13; k8s/policy/CI/
OTel templates; 4 new process state files; `check-scaffold.sh` checks 7–8; `check-hooks.py`.

## Decisions

Four recorded in `memory/process/decision-log.md`: Kubernetes un-parked (reversing a parent
decision); canon may cite framework control ids (reversing the zero-citation convention); skill
listing budget 0.02 → 0.04; phase numbers/names kept unchanged, security added as a track instead of
a rename.

## What did not happen

- **The GitHub repo was not created.** `POST /user/repos` returns 403 — this session's GitHub app
  scope covers only `claude-for-datascience`. All work is on the branch; the fork is one push away
  once the repo exists. The `upstream` remote wiring is likewise pending.
- Framework docs are verified against publishers as of 2026-07-25. `genai.owasp.org` returned 403 to
  automated fetch, so the OWASP LLM Top 10 v2.0 facts rest on multiple independent secondary
  sources — noted in that file's `**Verified:**` line rather than smoothed over.

## Follow-ups

- Create `claude-for-ai-platform` on GitHub, push this branch as `main`, add `upstream`.
- `docs/TUTORIAL.md` still describes the DS walkthrough — needs a platform rewrite.
- Appendix A of `PROCESS.md` is still the Dota 2 worked example; an AI-platform one would read better.
- No `*-decision-log.md` files exist for the new canon domains yet, correctly — they are created on
  the first judgment call, and their absence means no exception has been granted.

---

## Increment 2 (same day) — supporting tier + the two loose ends

**Focus:** the tier between the platform substrate and the agent layer — stores, workflow engines,
and clouds — plus the TUTORIAL and Appendix A rewrites flagged at the v1.0.0 handoff.

### State

v1.1.0, CI green. 58 skills (17 always-on, 11 gated-on, 30 gated-off). Live description budget
7,108 / 8,000 tokens — the eight new skills are all gated off, so they cost nothing until `/intake`
turns one on. `check-hooks.py` now 56 cases.

Added: `vector-stores`, `graph-stores`, `relational-stores`, `caching-and-queues`,
`object-and-lakehouse`, `workflow-orchestration`, `infra-gcp`, `infra-azure`; `infra-aws` expanded
from S3+Redshift to six platform surfaces. Canon `D8`–`D10` and `P11`, with `P11` enforced in
`guard-iac.py` across all three clouds. `local-stack` gained the AI/ML service catalogue; `serving`
gained self-hosted inference depth.

### Gaps this closed, worth naming

`data-governance.md` `D7` had required tenant-scoped retrieval since v1.0.0 and **nothing told anyone
how** — `vector-stores` is now that how. Similarly `D6` said delete the data and nothing said the
embeddings survive; `D10` says it now.

### Decisions

`workflow-orchestration` is a new skill rather than an extension of `pipelines` — they share a word
and nothing else. Recorded in `memory/process/decision-log.md`.

### Still open

- **The GitHub repo still does not exist** (403 on `POST /user/repos` — session scope). Unchanged
  from the v1.0.0 handoff; everything is on the branch.
- `infra-gcp`/`infra-azure` are authored from current knowledge, not verified against a live
  account. Both carry the usual `**Pinned:** unpinned` caveat, and cloud service names move — the
  first project on either should run `/skill-update`.
- SageMaker remains out of scope in `infra-aws`, now stated explicitly rather than implied.
