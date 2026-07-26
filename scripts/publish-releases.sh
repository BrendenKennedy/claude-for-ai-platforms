#!/usr/bin/env bash
# publish-releases.sh — create the six missing GitHub Releases, and refresh the repo metadata.
#
# WHY THIS EXISTS: the session that wrote v0.9.0-v1.4.0 could push branches but not tags (the git
# proxy returns 403 on refs/tags/*), and its GitHub MCP has no create_release tool. So this is the
# handover. Run it from a clone of BrendenKennedy/claude-for-ai-platforms with `gh` authenticated.
#
#   chmod +x publish-releases.sh && ./publish-releases.sh
#
# `gh release create --target <sha>` creates the tag AND the release in one step, so you do not need
# to create tags first. Safe to re-run: it skips any release that already exists.
#
# Verify afterwards:  gh release list   (should show v1.4.0 at the top)

set -euo pipefail

REPO="BrendenKennedy/claude-for-ai-platforms"

command -v gh >/dev/null || { echo "gh CLI not found — https://cli.github.com/"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh not authenticated — run: gh auth login"; exit 1; }

# Make sure the commits these releases point at are actually present locally.
git rev-parse --verify --quiet e2827d4 >/dev/null || {
  echo "commit e2827d4 not found — run 'git fetch origin main' first"; exit 1; }

release() {
  local tag="$1" target="$2" title="$3" notes="$4"
  if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
    echo "skip  $tag (already published)"
    return
  fi
  # The releases API rejects an abbreviated sha with "Release.target_commitish is invalid" —
  # target_commitish takes a branch name or a FULL 40-char sha. Resolve before sending.
  local full
  full=$(git rev-parse --verify "${target}^{commit}")
  gh release create "$tag" \
     --repo "$REPO" \
     --target "$full" \
     --title "$title" \
     --notes "$notes"
  echo "ok    $tag -> $full"
}

# ---------------------------------------------------------------------------------------------

release v0.9.0 5812391 "v0.9.0 — the dogfood refining patch" \
'The last release before the AI-platform work. A full worked project run end-to-end against the
scaffold surfaced friction its own authors could not see from inside it.

- **Signal-screen gate at P2** — *is there enough signal to justify modelling at all*, answered
  before the modelling phase rather than discovered during it.
- Friction fixes across the intake and bootstrap flows, found by actually running them.

_Tagged retroactively at the last commit of v0.9.0'"'"'s work, which is also the point from which the
v1.0.0 platform work diverged. The release commit itself is `826914f`._'

release v1.0.0 1416724 "v1.0.0 — the AI-platform security release" \
'The scaffold gains a platform and security half: agent and LLM security, Kubernetes, SRE,
observability, identity, and supply chain — grounded in published framework canon rather than
invented.

- **Five new policy canon domains with citable rule ids** — `ai-security` (AI1–AI12),
  `platform-security` (P1–P10), `identity-and-access` (I1–I9), `supply-chain` (C1–C8),
  `reliability` (R1–R8), plus S1–S9 retrofitted onto `security.md` and a compliance crosswalk.
- **20 framework reference documents**, each carrying its version, publisher, verification date, and
  an explicit statement of what it does *not* cover: OWASP LLM Top 10 v2.0, OWASP Agentic
  ASI01–ASI10, MITRE ATLAS, NIST AI RMF, CIS Kubernetes v2.0.1, NSA/CISA Hardening v1.2, SP 800-190,
  Pod Security Standards, SLSA, NIST SSDF, CycloneDX/SPDX, OWASP CI/CD Top 10, SP 800-63-4,
  OAuth 2.1/OIDC, SPIFFE/SPIRE, NIST CSF 2.0, SP 800-53, ISO 27001/42001, EU AI Act, Google SRE.
- 16 new skills, 6 new subagents, 6 new enforcement hooks, 7 new commands.
- `PROCESS.md` 1.0.0 with the **security and reliability track (§3.9)** running through every gate.
- Kubernetes un-parked and made the orchestration spine, reversing a recorded earlier decision.'

release v1.1.0 802188b "v1.1.0 — the supporting tier" \
'The tier between the platform substrate and the agent layer: the stores an AI platform runs on, the
engines that move data between them, and the clouds that host it.

- **Six data and workflow skills** — `vector-stores` (tenant filtering **in the query**, not the
  prompt), `graph-stores`, `relational-stores`, `caching-and-queues`, `object-and-lakehouse`,
  `workflow-orchestration`.
- **`infra-gcp` and `infra-azure`** added; `infra-aws` expanded from S3+Redshift to six platform
  surfaces. All three carry the same six sections, so they are diffable when moving between clouds.
- **Canon D8–D10 and P11** — store-level tenancy enforced by the query; encryption including
  backups, replicas, and derived indexes; tested restore and deletion that reaches derived
  artifacts; and data stores never internet-reachable or default-credentialed. P11 is enforced in
  `guard-iac.py` across all three clouds.
- `docs/TUTORIAL.md` rewritten as an agent-platform walkthrough.'

release v1.2.0 f6f3f26 "v1.2.0 — the dogfood pass" \
'The scaffold'"'"'s own review tooling, verification scripts, and policies pointed at its own output for
the first time — 133 files that had been reviewed only by their author.

- **The `permissions.allow` list was broader than its own comment claimed.** A permission prefix
  matches the start of the command string and cannot exclude a flag that appears later, so bare tool
  names granted the whole binary — `trivy:*` permitted `trivy plugin install`, `conftest:*`
  permitted `conftest push`. Entries scoped to subcommands; `semgrep` and `helm template` removed
  entirely, because no prefix can make them safe.
- **`check-scaffold.sh` check 9**, in two halves: every canon rule id cited in a skill must resolve,
  and the shipped `templates/k8s/` baseline must pass the shipped `templates/policies/` while those
  policies reject their own bad fixtures.
- Cloud facts verified against publishers, producing five substantive corrections.

> ⚠️ This release claimed the dogfood pass was complete. It was not — see **v1.3.0**.'

release v1.3.0 032ae15 "v1.3.0 — what the review agent found that I didn't" \
'v1.2.0 was tagged while the `security-reviewer` dispatch was still running. Its findings landed
after the tag, and one of them invalidated that release'"'"'s central claim.

### The headline defect

**`guard-k8s-manifests.py` and `guard-agent-config.py` were blind to the `Edit` path entirely.**
Both gated on anchors a diff hunk never contains, so every check silently skipped. An `Edit`
inserting `privileged: true` exited 0. An `Edit` widening `permissions.allow` exited 0 with no ask —
**in every permission mode, including `bypassPermissions`**, the one mode where that ask is the only
remaining human in the loop. Only whole-file `Write` was ever protected, and a manifest is normally
changed by `Edit`.

**`check-hooks.py` read green throughout, because all 56 cases used `Write`.** Coverage counted in
cases rather than in tool *paths* measures nothing. Now 87 cases, with Edit-path regressions.

### Also fixed

- `guard-iac` port **ranges** were untested: `0`–`65535` open to `0.0.0.0/0` passed while a narrow
  port-22 rule was blocked — strictly worse against the worse rule.
- `scan-untrusted-content` escaped newlines on the `Read` path, killing every `^`-anchored pattern.
  Payloads at the start of a line — where real indirect injection sits — scanned clean.
- `templates/security-ci.yml`: unpinned scanners in a workflow that SHA-pins its actions, an unused
  `security-events: write` grant on the job running repo-supplied code, missing
  `persist-credentials: false`, and a `conftest` step that exited 127 because it was never installed.'

release v1.4.0 e2827d4 "v1.4.0 — one scaffold, two families" \
'The AI-platform work was built as a fork and was about to become its own repo. It is **merged back**
instead, and `/intake` asks which kind of project you are starting. Renamed
`claude-for-datascience` → `claude-for-ai-platforms`.

### Both wings gate — always-on drops 17 → 5

Merging two families into one repo makes the always-on set the *union* of both, taxing everyone for
what they did not pick. Only the chassis is always-on now (`process`, `governance`, `testing`,
`memory`, `wave-planning`); the security spine and the DS core are both archetype-gated.
`skillListingBudgetFraction` 0.04 → 0.03.

**`agent-security` was always-on on a recorded rationale — "security defaults must not be opt-in" —
and that is not quietly reversed.** The skill was never the security floor: the floor is the
**hooks** (always on, zero context) plus the **canon** (on demand), both of which hold regardless of
profile. It now gates on *"is there an LLM or an agent in this at all?"*, asked separately from the
archetype — because the archetype maps wrong in both directions.

### Also

- `PROCESS.md` §3.9 and `/gate` **scale the security track by archetype** in three sizes rather than
  applying one uniformly. `N/A — <archetype>` is a valid recorded gate answer; silence is not.
- **`check-scaffold.sh` check 1b** — the always-on tier in the docs must match `settings.json`.
  Check 1 proved skills were *named* in the docs, never that they were in the right *tier*, and that
  gap shipped inside this very release.
- **README rebuilt for a cold reader**, with a "which one am I?" table answering the question the
  whole scaffold configures itself from.

_Existing installs are unaffected until they opt in: gating is by presence in `skillOverrides`, so a
`settings.json` omitting these keys keeps them always-on._'

release v1.5.0 a3cd73b "v1.5.0 — the documentation audit" \
'v1.4.0 renamed the scaffold and merged two families into one repo. That landed correctly at the
root and nowhere below it: the word "family" appeared 6x in `README.md` and `CLAUDE.md`, and **0x in
any supporting doc**. Every finding below was verified against the files rather than inferred.

### Statements a reader would have acted on

- **`README.md` said "CI runs both" and CI ran one.** `check-hooks.py` — 85 behavioural cases
  including the fail-open tier — was invoked by no workflow.
- **Two hooks had no fail-open case** while three separate files asserted every hook did. Both pass;
  they were correct, just untested. Coverage counted in claims is not coverage.
- **The agent-preload rule was unsatisfiable.** v1.4.0 gated every domain skill, so "preload only
  ALWAYS-ON skills" made 9 of 10 real preloads illegal. Re-derived on the axis the rule was actually
  about — interchangeability: never a *tool*-gated skill (one of a swappable pair is wrong half the
  time), a *lane*-gated one only while it is on.
- `google-sre.md` cited `templates/postmortem.md` as `R8`s mechanism. No such file.
- 14 "this fork" / "the parent scaffold" references described a fork reversed on 2026-07-26.

### `docs/REFERENCE.md` was wrong at birth, not drifted

Advertised as "generated from source, so it cannot drift" — and it had not drifted. **10 of 13 hook
rows were empty** because the extractor only read `#` comments and every Python hook uses a
docstring; and an unescaped `Edit|Write` matcher added a fourth cell to a three-column table, so
what did render landed in the wrong column.

### The installed-project blind spot

`install.sh` copies `.claude/`, `CLAUDE.md` and `PROCESS.md` — **not** the README, not `docs/`. Its
closing echo is therefore the only onboarding an installed project ever sees, and it was pre-1.4.0
on three counts. Fixed, plus a stanza naming what shipped and what did not, and the fact that
`build-reference.py` works in an installed project and will generate an index from *that* project.

- **The tutorial forks by family.** It claimed "~30 minutes on synthetic data" and was a 40-minute
  platform walkthrough with none, while `README.md` sent Model-family users into Kustomize and
  `/redteam`. Now a chooser plus `tutorial-platform.md` and a new `tutorial-model.md`.
- **`README.md` gains a "Where to read next" table**, carrying the single most-missing link in the
  repo: `PROCESS.md` — 646 lines governing every gate, installed into every project, previously
  unreachable from the front door.
- **`PROCESS.md` is retitled for both families** and gains §2.1 mapping the data-science phase names
  onto platform work. Phase names stay; `decision-log.md` records why. Its own version → 1.1.0.

### The checks, so this audit does not need repeating

`check-scaffold.sh` 11 checks → 19. CI now runs `check-hooks.py`. New: every check-* script is
actually invoked by CI; every hook has cases **and** a fail-open case (AST-parsed, not grepped);
`PROCESS.md`s header matches its own changelog; framework "How it lands here" paths resolve;
`memory/reference/` notes are registered; four directory indexes name every file they hold.

> ⚠️ This release also claimed `check-scaffold.sh` works in an installed project, and claimed to
> have fixed the checks that print `ok` after failing. Both were wrong — see **v1.5.1**.'

release v1.5.1 9aae3e8 "v1.5.1 — what the audit of 1.5.0 found" \
'An adversarial review of the release above — three independent passes, every finding reproduced —
turned up 23 issues. **Four were in code v1.5.0 had just shipped, and one was the exact defect that
release claimed to have eliminated.**

### The appliance guard missed the form the world actually uses

v1.5.0 shipped `S10`: never `apt` on a vendor-managed appliance box (DGX Spark / GB10 / Jetson),
where the OS image is a tested set and recovery is a re-image rather than a rollback. The block
anchored the subcommand immediately after the binary — so `apt-get install -y foo` blocked and
**`apt-get -y install foo` did not**, along with absolute paths, `bash -c`, `$( )`, `apt reinstall`,
`dpkg --unpack`, and `apt-get -qq update && apt-get -y dist-upgrade`, **which is verbatim the
sequence S10 exists to prevent**.

The ten tests shipped with it all passed, because they were written against the regex instead of
against the threat. The decision now **tokenizes**: strip env prefixes and wrappers, find the real
binary, judge the first non-flag subcommand against a read-only allowlist, default-deny the rest.
Knowing where a command *starts* is also what distinguishes a real invocation from
`git commit -m "… apt install …"` describing one.

- **Containers are allowed** (`docker run`/`exec`, `podman`) — a container is the remedy S10 itself
  recommends, and blocking it is the false positive most likely to get a rule disabled.
- **`ssh` and `kubectl exec` are not** — the far end may be an appliance too.
- **Heredoc bodies are data**, unless fed to a shell. Found the hard way: the first version of this
  release commit was blocked by its own message.

### The guard had an off-switch the guarded agent could flip

Detection cached to `/tmp/.claude-appliance-host.$UID`, **read before hardware detection and
writable by the agent being guarded** — one `echo` disabled it permanently, and that echo was itself
an allowed command. The cache also never expired, so a single transient miss (driver not loaded,
`nvidia-smi` not yet on `PATH`) killed the guard silently and forever on real hardware. Cache
removed; detection is ~21ms and a pre-filter means only apt-shaped commands pay it. `nvidia-smi`
runs under `timeout 2`, because a wedged driver is this hardware class characteristic failure.

### `check-scaffold.sh` was lying, and running other peoples code

- **Check 1 printed `ok` after failing.** Its baseline was captured *after* the skills, commands and
  agents loops, so 57 real failures could print and still be summarised `ok`. This is the bug
  v1.5.0s notes claim to have fixed, in the check they name first. Checks 2 and 7/8 had never been
  converted at all.
- **The scaffold-repo predicate was `install.sh` + `README.md`** — which any library or tool project
  satisfies. The consequence was not only ~100 bogus failures: check 4 then **executed the target
  projects own `install.sh`, twice.** Proven with a side-effect marker. Tightened, and six checks
  now route through one predicate instead of three competing ones.
- **Check 14** walked a glob list that missed `templates/memory/` entirely and matched bare
  basenames, so one `kustomization.yaml` row satisfied both k8s locations.

An installed project now passes clean **with its own README, `install.sh` and `VERSION` present**,
and its installer is never executed.

### Claims that were wrong, including in a file v1.5.0 wrote

`tutorial-model.md` described a `/bootstrap` step that does not exist and was flatly wrong for the
LLM lane (which defers training proof and emits `train_sft.py`). Both tutorials demoed a hook by
saying "open the file and type" — `PreToolUse` fires on Claudes tool calls, never a human editor,
so the demo could not work. `setup.md`s own frontmatter listed five stages and omitted
`/threat-model`, propagating into `docs/REFERENCE.md` where check 6 kept it green. `README.md` and
the compliance crosswalk still scoped `security.md` to `S1`–`S9` after S10 shipped.

### The pattern

All four self-inflicted defects came from testing that a claim was self-consistent rather than
testing it against the thing it describes. **A test written after the implementation tests the
implementation.** 131 hook cases now, up from 85, written threat-first and failing before the fix.

_Not blocked, deliberately: `snap`. S10 is scoped to the apt/dpkg-managed image._'

# ---------------------------------------------------------------------------------------------
# Repo metadata — the description and topics still describe a computer-vision scaffold.

echo
echo "Refreshing repo description and topics..."
gh repo edit "$REPO" \
  --description "Claude Code scaffold for building AI platforms securely — agent/LLM security, Kubernetes, SRE, observability, identity, and supply chain, grounded in published framework canon (OWASP, NIST, CIS, SLSA). Data-science lanes included." \
  --add-topic ai-security \
  --add-topic llm-security \
  --add-topic agent-security \
  --add-topic prompt-injection \
  --add-topic platform-engineering \
  --add-topic kubernetes \
  --add-topic sre \
  --add-topic supply-chain-security \
  --add-topic devsecops \
  --remove-topic computer-vision

echo
echo "Done. Check: gh release list --repo $REPO"
