# `.claude/memory/` — agent working memory (data store)

The **stored notes** that let a new session resume with the last one's context — refined summaries,
never raw transcripts. This directory is the DATA; the **record/recall protocol + branch workflow** is
the **`memory` skill** (so the process surfaces when you start, branch, or wrap up work — not on every
session). Pulled in on demand, never auto-loaded.

## Layout
| Path | Holds |
|---|---|
| `sessions/` | dated refined summaries of each substantive session (`YYYY-MM-DD-<slug>.md`, newest-last); start from `sessions/_template.md` |
| `incidents/` | blameless postmortems, written by `/postmortem` from `incidents/_template.md` (`reliability.md` `R8`) |
| `reference/` | stable "how we do X" notes that recur but don't warrant a full skill |
| `roadmap.md` | the living backlog: next · in-progress · done-recent |
| `scaffold-journal.md` | observed quality of the `.claude/` scaffold itself — friction, wins, gaps; harvested by `/scaffold-retro` |
| `policy/` | authored governance policy canon + decision logs (accessed via the `governance` skill) |
| `process/` | live `PROCESS.md` state — `project-definition`, `phase-state` (gates), `risk-register`, `scope-ledger`, `decision-log`, `resources` (the resource matrix); written by `/gate`, `/intake`, and the infra lanes |

> `CLAUDE.md` indexes this directory too, and that duplication is deliberate rather than drift: the
> one there is *agent routing* (it names the specific `process/` files so the agent needn't open
> another file), this one is *human orientation* (it has the authoring guidance below). Both are
> kept complete by `check-scaffold.sh`; don't collapse them into one.

## Not to be confused with
- **Repo-root `docs/`** — human/project documentation (READMEs, design contracts). That's project
  data; this is agent working memory.
- **The personal auto-memory at `~/.claude/projects/**/memory/`** — per-user and cross-project. This
  store is in-repo, git-tracked, and project-scoped.

## What goes where (so it stays consistent)
- **Deep domain knowledge with discovery triggers** → make it a **skill** (`.claude/skills/`), not a note here.
- **Reusable "how we do X in this repo"** → `reference/`.
- **What happened / current state** → `sessions/`.
- **What's next** → `roadmap.md`.
- **Rules the code/schema must obey** → `policy/` (via the `governance` skill).
- **Current phase / gates / scope / risks / resources** → `process/` (via the `process` skill + `/gate`).

If a category outgrows itself (e.g. decision history), split it out — a dedicated log beside its
canon in `policy/`, or a new subdir here, is the obvious next addition.
