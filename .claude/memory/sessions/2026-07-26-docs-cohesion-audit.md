# Session: Documentation cohesion audit — v1.5.0

**Date:** 2026-07-26 · **Focus:** make every doc factually true, mechanically enforced, and coherent for a new user in either family

## Summary
v1.4.0 renamed the scaffold and merged two families into one repo, and that landed correctly at the
root — README and CLAUDE.md had accurate counts, correct tiers, coherent two-family framing. Every
layer below root still spoke as the pre-merge data-science scaffold ("family" appeared 6× at root,
0× in any supporting doc). Audited the whole documentation surface with three parallel Explore
agents, re-verified every finding against the files personally, then fixed three layers: ~20 wrong
statements, the information architecture, and — the part that matters most — the checks that would
have caught all of it. Shipped as v1.5.0; PROCESS.md's own version went to 1.1.0.

## Changes & artifacts
- `.github/workflows/ci.yml` — runs `check-hooks.py`. README said "CI runs both"; nothing invoked it.
- `.claude/scripts/check-hooks.py` — fail-open cases for `guard-secrets.py` and `validate-bash.sh`,
  the two hooks that lacked one while three files claimed every hook had one. Both passed: correct,
  just untested.
- `.claude/scripts/check-scaffold.sh` — six new checks (CI wiring, hook coverage incl. fail-open via
  AST, framework mechanism paths, reference-note registration, PROCESS.md version self-consistency,
  index completeness); check 1 extended to hooks + scripts; check 3 extended to agent preloads,
  shebang/exec agreement, and `"off"` overrides. Exit-status bug fixed in checks 1/2b/3; check 6 now
  separates a crashed generator from a stale file.
- `.claude/scripts/build-reference.py` — `hook_line()` reads Python docstrings (10 of 13 hook rows
  were blank), `cell()` escapes `|` (the `Edit|Write` matcher broke the table), chassis derived from
  `settings.json` instead of hardcoded (removes the empty abolished tier).
- `install.sh`, `.claude/commands/intake.md` — the post-install and post-intake onboarding text, both
  pre-1.4.0 on three counts. `.claude/commands/bootstrap.md` — description covered only the model
  archetypes.
- `docs/` — `TUTORIAL.md` split into chooser + `tutorial-platform.md` + new `tutorial-model.md`; new
  `docs/README.md`. `README.md` — "Where to read next" table, incl. the first-ever link to PROCESS.md.
- `PROCESS.md` — retitled for both families, new §2.1 phase-mapping table, Appendix A named, 1.1.0.
- Three drifted indexes completed (`templates/` 6→20 files, `memory/` +2 stores, `scripts/` 0→3).
- 14 stale "this fork"/"parent scaffold" refs; the agent-preload rule; `google-sre.md`'s R8 path;
  two `skillListingBudgetFraction` / `ml-engineer` errors; the threat-model mislabel in two files.

## Key decisions
- **Preload rule re-derived on interchangeability, not always-on-ness.** v1.4.0 gated every domain
  skill, making "preload only ALWAYS-ON skills" illegal for 9 of 10 real preloads. The rule's actual
  purpose was that a *tool*-gated skill is one of a swappable pair; a *lane*-gated one has no
  sibling. Rejected "chassis only" — it would have been routed around within a release.
- **Deleted the `skillListingBudgetFraction` literal rather than correcting it.** It drifted three
  times in eight days; `settings.json` already carries the value and the reasoning.
- **Did not rename PROCESS.md's phases.** `decision-log.md` records that decision with a good reason
  (~50 files cross-reference them by number and name). The §2.1 mapping table gets the same outcome
  for 10 lines. An audit shouldn't silently reverse a reasoned architectural decision.
- **Kept the deliberate duplications** (memory index ×2, policy-domain table ×4) and enforced them
  instead of collapsing — each copy serves a different reader. Labelled as such in-file.
- **Every new check was proven to fail on a broken fixture**, not merely to pass. A check that can't
  fail is the defect class the wave exists to prevent.

## State
Both `check-scaffold.sh` (17 checks) and `check-hooks.py` (87 cases) pass in the scaffold repo **and**
in a freshly installed project. All relative links resolve. `shellcheck` runs in CI only (not
installed locally — this box is a DGX Spark, no apt).

**Biggest find, discovered while verifying my own new text:** `check-scaffold.sh` had never worked in
an installed project — checks 1, 1b and 4 require `README.md` and `install.sh`, neither of which
ships, so it reported ~90 failures on a healthy project. Now gated on the scaffold repo; an installed
project passes clean.

## Post-release audit (v1.5.1)

The user asked for a full audit of the above. Three adversarial passes plus my own reproduction found
**23 issues — four in code this session had just shipped, and one was the exact defect the session
existed to eliminate.** Worth recording honestly, because the pattern is the lesson:

- **The apt guard missed `apt-get -y install`.** The regex anchored the subcommand adjacent to the
  binary. My 10 tests all passed because I wrote them against my regex instead of against the threat.
  `sudo apt-get -qq update && sudo apt-get -y dist-upgrade` — the literal brick sequence S10 exists
  to stop — walked through. Rewritten to tokenize; 30 cases now, written threat-first and failing
  before the fix.
- **The guard had an off-switch the guarded agent could flip.** `echo no > /tmp/.claude-appliance-host.$UID`
  was allowed and permanently disabled it. Cache deleted.
- **check-scaffold check 1 still printed `ok` after failing** — baseline captured after the loops.
  The v1.5.0 commit message claims this was fixed. Checks 2 and 7/8 were never converted.
- **check-scaffold executed a target project's `install.sh`, twice**, because the scaffold-repo
  predicate was `install.sh + README.md`.
- **`docs/tutorial-model.md` — my own new file — described a bootstrap step that doesn't exist**,
  and was flatly wrong for the LLM lane.

**The lesson, recorded because it will recur:** every one of these came from writing a plausible
claim and then testing that the claim was self-consistent, rather than testing it against the thing
it describes. A test written after the implementation tests the implementation. The three that
escaped an entire session of "verify everything" were the three where I was the author *and* the
verifier.

## Follow-ups
- `ml-engineer` and `platform-engineer` carry no `skills:` preload — is that right? Deliberately not
  decided here; adding one to make a doc sentence true would be the tail wagging the dog. → roadmap
- `build-reference.py`'s `TOOLS` set is the last hardcoded taxonomy (no on-disk signal for the
  tool/lane split; `**Pinned:**` isn't one — 30 skills carry it, including lane skills). → roadmap
- v1.5.0 is committed but **not tagged or released** — `scripts/publish-releases.sh` covers
  v0.9.0–v1.4.0 and needs a v1.5.0 row.

## Landed
Branch `session/2026-07-26-docs-cohesion`, 5 commits, merged to `main` at **`5cae2df`** (`--no-ff`,
matching this repo's convention for session branches). Releases **v1.5.0** and **v1.5.1**; PROCESS.md
independently at 1.1.0. `check-scaffold.sh` 11 checks → 19, `check-hooks.py` 85 cases → 131, both
green on `main` in the scaffold repo and in an installed project.

**Pushed** to `origin/main` at `9aae3e8` (8 commits). The `origin` and `fork` remote URLs still
pointed at `claude-for-datascience` and were working only via GitHub's redirect — both repointed at
`claude-for-ai-platforms`.

**Branch cleanup:** `docs/authoring-extensions-reference` (`9c96dd5`, from 2026-07-15) was the only
unmerged branch anywhere. Verified redundant — its `authoring-extensions.md` is a 163-line ancestor
of main's 247-line version, and its `CLAUDE.md` line is already present. Deleted local + remote.
Diffing against it is what surfaced the last of the pre-merge tier framing (commit `9aae3e8`).

**Released.** All 8 missing releases published via `scripts/publish-releases.sh` (v0.9.0 → v1.5.1,
with rows added for the last two). **16 CHANGELOG versions = 16 tags = 16 GitHub releases** — full
parity for the first time. Repo description and topics also refreshed off the CV-era text.

## Related
- `2026-07-25-ai-platform-security-fork.md` — the merge this audit cleans up after.
