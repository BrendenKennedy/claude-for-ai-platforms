# Roadmap

The living backlog: future scope, open threads, and TODOs. Sessions point their follow-ups here;
recall reads here for "what's next". Keep it pruned — check off or delete finished items.
Doubles as the scope **parking lot** (PROCESS.md §3.3): promotion into the v1 contract needs the
written gate + a decision-log line.

## Now / in progress
- **Dogfooding** (user-driven): first real project through `/setup` → gates → `/report`; its
  retro produces PROCESS.md 0.3.0 + the real README walkthrough → **the 1.0 gate**

## Next
- **Agent preload policy for `ml-engineer` / `platform-engineer`** (2026-07-26 docs audit): neither
  carries a `skills:` line. Four agents legitimately don't (the generalists), but these two are
  lane-shaped and arguably should. Left undecided rather than adding one to satisfy a doc example.
- **`build-reference.py`'s `TOOLS` constant** (2026-07-26 docs audit): the last hardcoded taxonomy in
  the generator. The chassis is now derived from `settings.json`; the tool/lane split has no on-disk
  signal (`**Pinned:**` isn't one — 30 skills carry it, incl. lane skills). Needs a real signal or an
  accepted-hardcoding note.
- **Publish v1.5.0** — `scripts/publish-releases.sh` covers v0.9.0–v1.4.0; v1.5.0 needs a row, and
  the six earlier releases still aren't on GitHub.
- **`docs/` snapshot auto-sync** (dota2 dogfood theme #2, 3× friction): a `/wrapup`-time step or hook
  that regenerates published `docs/` process snapshots from the canonical `.claude/memory/process/`
  copies, so the two never drift. v0.9.0 shipped the canonical-home *guidance*; this is the automation.
- **`/wrapup` × `memory` skill restatement drift** (this repo's own journal): `/wrapup` copies the
  memory skill's step list; watch for real drift, and if it bites, reference the numbered steps instead.
- **Cross-project scaffold-journal harvest** (this session's own friction): `/scaffold-retro` reads
  only this repo's journal, but the richest dogfood signal lives in installed projects' journals
  (git-untracked, local). Let `/scaffold-retro` accept a downstream journal path, or `/upgrade` surface it.
- Run `/doctor` to confirm the skill-listing budget post-rewrite
- Watch skill surfacing after the description rewrite; sharpen under-triggering descriptions
- Dogfood-tune the `SessionStart` briefing: is its length right, and does the "finish before
  handing back" DoD actually fire the `/wrapup` offer? Adjust `session-orient.py` / CLAUDE.md if not
- Exercise the scaffold loop end-to-end while dogfooding: wrapup scaffold-check populates
  `scaffold-journal.md`, then run the first `/scaffold-retro` and confirm a friction→improved trail
  forms. Watch that the wrapup check doesn't decay into rote "none" (capture-the-moment is the real path)

## Someday / maybe
- Causal inference skill (observational methods beyond A/B — DoWhy/propensity) — when demand shows
- Big-data escalation skills (polars/duckdb/spark) — when demand shows
- Kubernetes manager, SageMaker/EC2 surface for `infra-aws`, GCP/Azure lanes — parked on demand (AWS S3+Redshift + Docker/Compose shipped in v0.8.0)
- Data-validation tool skill (pandera/great-expectations)

## Done (recent)
- **v0.9.0 — dota2 dogfood refining patch** (harvested from `dota2-prediction-engine`, scaffold v0.7.0,
  18 journal entries): predictive-signal screen → `eda` + P3 exit-gate go/no-go (PROCESS.md 0.3.0, the
  headline lesson); `/gate` PASS cascades to roadmap; `/intake` mandatory env-confirm + VC-scope +
  skillOverrides session-boundary note; `guard-pyproject` anchored on TOML headers; `env-uv`
  isolated-GPU-env pattern + line-length-100 convention; `tabular` prove-on-synthetic-flip-to-real
  documented — 2026-07-19, [session note](sessions/2026-07-19-dota2-dogfood-refining-patch.md),
  branch `scaffold-refine-dota2-dogfood`, commit `826914f`. See `scaffold-journal.md` Themes.
- Multi-archetype `/bootstrap` skeletons (tabular §3e, time-series §3f, LLM data+eval §3g) — 2026-07-18, v0.8.0
- Ship clean memory stores — `install.sh` no longer copies this repo's dev session notes / roadmap /
  journal into fresh projects; seeds blank stores from `templates/memory/` — 2026-07-18,
  [session note](sessions/2026-07-18-ship-clean-stores.md), branch `ship-clean-stores`, commit `c42ea74`.
- Scaffold self-assessment loop — `scaffold-journal.md` + wrapup scaffold-check + `/scaffold-retro`;
  the tooling's meta-loop (parallel to PROCESS.md Part V) — 2026-07-18,
  [session note](sessions/2026-07-18-scaffold-self-assessment-loop.md), branch `scaffold-journal`, commit `d96618d`.
- `SessionStart` orientation hook + "finish before handing back" DoD convention — the completion
  contract (mechanical + judgment halves); no orchestrator agent — 2026-07-18,
  [session note](sessions/2026-07-18-session-start-orientation.md), branch `session-start-orientation`, commit `e5c8083`.
  (Superseded the old "Stop-hook gate-debt warning" idea — Stop is per-turn.)
- Release v0.11.0: lifecycle pass (/upgrade, check-scaffold 2b, stability contract) — 2026-07-18
- Release v0.10.0: audit pass (58-agent adversarially-verified sweep, 45 findings fixed) + resource matrix — 2026-07-18
- Release v0.9.0: self-hosted pass (local-stack: MinIO, CVAT, Postgres+extensions) — 2026-07-18
- Release v0.8.0: infrastructure pass (infra-aws + IAM boundary template, containers, hook tiers) — 2026-07-18
- Pushed to origin; GitHub releases v0.4.0–v0.7.0 created from CHANGELOG — 2026-07-18
- Release v0.7.0: end-to-end pass (sql, data-acquisition, serving, wrangling lanes; ad-hoc mode; fairness slices) — 2026-07-18
- Release v0.6.0: communication layer (eda, visualization, statistics, reporting + /report) — 2026-07-18
- Release v0.5.0: lane skills (tabular, timeseries, monitoring) + config-omegaconf — 2026-07-18
- Release v0.4.0 (process framework, efficiency pass, agent audit, versioned tool skills,
  llm-eval + hpo-optuna) — 2026-07-18
- `finetune-unsloth` (tool-gated) + MLflow Model Registry section + version pins on all tool
  skills + `/skill-update` — 2026-07-18
- Process framework integration + context-efficiency pass — 2026-07-18,
  [session note](sessions/2026-07-18-process-and-efficiency.md), commit `436a1f6`
