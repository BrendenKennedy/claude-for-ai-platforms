---
description: >
  Upgrade this project's installed scaffold to a newer claude-for-ai-platforms release — read the
  `.claude/scaffold-version` stamp, walk the CHANGELOG delta, then apply upstream changes under a
  three-way safety rule: ADD new files, REPLACE only files the project never modified, ASK about
  everything locally edited. Preserves memory/ state, the skillOverrides profile, and filled
  placeholders. Run after a new scaffold release ships, not on a schedule.
argument-hint: "[path-to-scaffold-clone]"
---

Upgrade the installed scaffold in this project. The invariant that governs every step: **user
state and user edits are never clobbered** — the same never-clobber contract as `install.sh`,
extended with a three-way merge so *unmodified* scaffold files can still move forward.

## 0. Does this command even apply?
Read `.claude/scaffold-version` (format: `<version> (<sha>)`). No stamp → this repo either *is*
the scaffold or is a "Use this template" copy — its upgrades arrive as git merges from upstream,
not through this command. Say so and stop.

## 1. Get upstream + the story
- Upstream source: `$1` if given (a local clone — `git -C <path> pull` it), else clone fresh
  into the scratchpad (`git clone https://github.com/BrendenKennedy/claude-for-ai-platforms`).
- Read upstream `VERSION`. Equal to the stamp → already current; stop.
- Read the `CHANGELOG.md` entries between the stamp version and upstream, and **summarize for
  the user what this upgrade contains before touching any file** — the CHANGELOG is written for
  exactly this diff.

## 2. Build the file plan (classify, don't act yet)
The upgrade set is `install.sh`'s source set: everything under `.claude/` plus root `CLAUDE.md`
and `PROCESS.md`. For each upstream file:
- **Absent in the project → ADD.**
- **Byte-identical to upstream → SKIP.**
- **Differs → three-way, using the stamp sha:** fetch the version this project was installed
  from (`git -C <clone> show <stamp-sha>:<path>`), then:
  - project file **== old version** → the user never touched it → **REPLACE** with upstream;
  - project file **!= old version** → locally modified → **CONFLICT**: show the diff and ask
    (keep mine / take upstream / hand-merge) — never decide silently;
  - old version unavailable (shallow clone, pre-stamp file) → treat as CONFLICT.

## 3. The never-touch list (state is not scaffold)
- `.claude/memory/sessions/`, `roadmap.md`, and the live files in `memory/process/` are the
  **project's data** — never replaced; only ADD seed files the project lacks entirely.
- `settings.json` is **merged, not replaced**: new `skillOverrides` keys arrive as `"off"`, new
  hook wirings are shown and added, and the user's permissions + profile are preserved verbatim.
- Skills the project filled placeholders into: after a REPLACE, re-apply the filled values
  (diff old-scaffold-version vs project to find them); anything that can't be re-applied
  cleanly goes in the report as a named follow-up, not a silent loss.

## 4. Finish + verify
1. Rewrite `.claude/scaffold-version` with the new version + upstream HEAD sha.
2. Run `bash .claude/scripts/check-scaffold.sh` — drift introduced by the upgrade must fail
   loudly now, not surface later.
3. Run `/skill-update --check` — replaced tool skills may document different versions than the
   project's lockfile runs; the drift table says which need syncing.
4. Commit per the `memory` skill's branch conventions (`chore: upgrade scaffold vA → vB`).

**Report:** version A → B, the CHANGELOG summary, the plan's outcome per file
(ADDED / REPLACED / SKIPPED / CONFLICT + how each conflict resolved), placeholders re-applied or
orphaned, and the `/skill-update` drift table.
