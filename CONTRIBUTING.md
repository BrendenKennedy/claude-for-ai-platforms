# Contributing

Contributions welcome — skills, agents, commands, hooks, and fixes to any of them. This repo is
itself the artifact: the bar for what goes in is the same discipline the scaffold teaches.

## Before you write anything

Read **`.claude/memory/reference/authoring-extensions.md`** — it is the authoring canon for all
four extension types (skills, agents, commands, hooks): file locations, frontmatter contracts,
and the conventions that bite. The short version of the rules that reject PRs:

- **Earn the surface.** Every skill active in a profile pays for its description on every turn of
  every session in that profile — the always-on chassis in all of them, a gated skill in each
  profile that flips it on. New knowledge must either fit an existing skill, gate behind a
  tool/lane override, or displace something weaker. "Might be useful" is the parking lot
  (`roadmap.md`), not a merge.
- **Descriptions are front-loaded and budgeted.** ≤ ~1,000 chars, use case first, triggers
  sharpest-first — the listing truncates tails and the budget is shared
  (see the description rules in the authoring doc).
- **Tool skills carry a `**Pinned:**` line** and document commands that actually run on that
  version. `/skill-update` owns pin bumps; claims you didn't execute don't ship.
- **Agents preload only skills that are `"on"` in `skillOverrides`** (`skills:` frontmatter), never
  tool-gated ones; least-privilege `tools:`; output goes to the caller, not the user.
- **Register everything** in CLAUDE.md (and the README tree) — `check-scaffold.sh` enforces this.

## The PR checklist

1. `bash .claude/scripts/check-scaffold.sh` and `python3 .claude/scripts/check-hooks.py` pass
   (the script headers list what each one checks; CI runs both).
2. New/changed skill descriptions are within budget (the check above warns; the authoring doc
   has the numbers).
3. A `CHANGELOG.md` entry under an `Unreleased`/next-version heading, in the existing style.
4. If you changed policy-shaped content (`memory/policy/`, PROCESS.md), say why in the PR —
   those files are canon and get closer review.
5. One concern per PR. A new skill and a hook fix are two PRs.

## Design questions

Architecture decisions that keep coming up are recorded with their reasoning in
`.claude/memory/reference/` (start with `architecture-skills-vs-agents.md`) — read those before
proposing a restructure, and expect "revisit conditions" to be part of any counter-proposal.

## The stability contract (what SemVer means for a scaffold)

Installed projects depend on this repo's *interfaces*, so version bumps follow what a change does
to them:

- **Breaking (major):** renaming or removing a skill, command, agent, or hook; moving a
  `.claude/memory/` path; changing the `**Pinned:**` line, resource-matrix, or phase-state
  formats; changing a hook's exit-code semantics or the `settings.json` contract
  (`skillOverrides` keys, hook wiring shape).
- **Additive (minor):** new skills, lanes, commands, or gate items; extended docs; new template
  files.
- **Fixes (patch):** corrections that change no interface.

Post-1.0, every breaking change ships a migration note in its CHANGELOG entry, and `/upgrade`
handles the mechanical part for installed projects.

## Reporting problems

Issues with a reproduction (the command you ran, what surfaced, what you expected) get fixed
fastest — especially skill-routing misses ("said X, expected skill Y to load"), since
descriptions are tuned from exactly that evidence.
