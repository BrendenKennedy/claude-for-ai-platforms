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
  gh release create "$tag" \
     --repo "$REPO" \
     --target "$target" \
     --title "$title" \
     --notes "$notes"
  echo "ok    $tag -> $target"
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
