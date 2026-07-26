# 2026-07-25 — AI-platform security fork

**Focus:** Fork `claude-for-datascience` 0.9.0 into `claude-for-ai-platforms` 1.0.0 — an AI platform
engineering + AI security scaffold, keeping the DS layer underneath.

> The singular `claude-for-ai-platform` appears in the increment-1 follow-ups below. That was the
> proposed name; the repo was actually created as **`claude-for-ai-platforms`** (plural). Those
> mentions are left as written rather than back-edited — see *Repo split* at the end.

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

---

## Increment 3 (same day) — dogfood pass + publisher verification

**Focus:** point the scaffold's own tooling at its own 133-file diff, and verify the cloud skills
against publishers. v1.2.0.

### What the dogfood pass actually found

Two real defects, both in my own work, both now fixed:

1. **`permissions.allow` was broader than its own comment claimed.** A permission prefix matches the
   start of the command string and cannot exclude a later flag, so `trivy:*` permitted
   `trivy plugin install` (code execution), `conftest:*` permitted `conftest push` (egress),
   `semgrep:*` permitted `--autofix` (rewrites files), and `helm template:*` permitted
   `--post-renderer` (executes a binary). The comment asserted every entry was read-only. Entries are
   now subcommand-scoped; `semgrep` and `helm template` removed entirely because no prefix can make
   them safe.
2. **`check-scaffold.sh` check 9 swallowed its own exit status** — `python3 … || fails=…` makes `$?`
   always 0, so a failure printed `FAIL` and `ok` together. Caught by its own negative test, which
   is the argument for writing negative tests.

**And a genuine no-defect result**, reported as such rather than padded: the shipped k8s templates
pass 165 policy assertions, all 8 policy self-tests reject their bad fixtures, every shipped template
passes its guard hook, and `mcp-json.example` correctly asks rather than blocks. That check had never
run before and is now check 9b in CI.

### Cloud verification

Three corrections and two additions that matter operationally: EKS Pod Identity vs IRSA is not a
free choice (Fargate still needs IRSA); Cloud Run's timeout *defaults* to 5 minutes; GCP Data Access
audit logs are off by default **except BigQuery**; **AKS network policy is creation-time only**; and
Azure OpenAI's 30-day abuse-monitoring retention has an exemption available only on EA/MCA, not
pay-as-you-go. All three cloud skills now carry `**Verified:**` lines naming what was and wasn't
confirmed. The Azure Functions timeout ceiling could not be confirmed and is stated without a number.

### Design notes

- The skill-name half of check 9 was **dropped**: 25 legitimate backticked hyphenated tokens (agent
  names, canon file stems, CLI tools) would have been false positives, and a noisy check gets
  deleted. Only the rule-id half shipped.
- `platform-security.md` `P#` collides with `PROCESS.md` phase numbering (`P1`–`P7`). No live
  ambiguity — the checks only read backticked ids and all `P1`–`P11` resolve — but a backticked
  `P3` meaning "phase 3" would silently resolve to a platform rule. Worth knowing; not worth a rule
  renumbering.

## Increment 4 — the review agent's findings (v1.3.0)

I tagged v1.2.0 "dogfood pass complete" while the `security-reviewer` dispatch was still running.
Its findings landed after the tag, and one invalidated that release's central claim. **The v1.2.0
framing was premature and the changelog now says so.**

### The headline defect — the guards were blind to `Edit`

`guard-k8s-manifests.py` and `guard-agent-config.py` scanned `content` + `new_string` and then gated
on anchors a diff hunk never contains (`apiVersion:`/`kind:`; the literal `"allow"`). A hunk carries
neither, so **every check silently skipped**. An `Edit` inserting `privileged: true` exited 0. An
`Edit` widening `permissions.allow` exited 0 with no ask — in every mode including
`bypassPermissions`, where that ask is the only remaining human in the loop. Only whole-file `Write`
was ever protected, and a manifest is normally changed by `Edit`.

**Found by the agent, not by me**, and my own `check-hooks.py` reported green throughout because all
56 cases used `Write`. That is the more durable lesson than the defect: coverage counted in *cases*
rather than in *tool paths* measures nothing. The suite is now 87 cases with an `Edit`-shaped helper
and real on-disk fixtures; the five hooks that had zero cases now have block/allow/fail-open
coverage, which makes `settings.json`'s coverage claim true for the first time.

Both defects were verified broken by hand before the fix and **verified fixed by hand after** — not
only through the suite that missed them:

```
1) Edit inserting `privileged: true`  -> exit=2  (was 0, silent)   P1 privileged container
2) Edit widening permissions.allow    -> exit=0, ask=True (was 0, no ask)
```

### Scoreboard: two mine, six the agent's

Mine (increment 3): the allow-list breadth, and check 9's swallowed exit status. The agent's: the
Edit-path blindness in both hooks, the `security-ci.yml` cluster (unpinned scanners, unused
`security-events: write`, missing `persist-credentials: false`, uninstalled `conftest` → exit 127),
the `guard-iac.py` port-**range** gap (`0`–`65535` open to the world passed while a narrow port-22
rule was blocked — strictly worse against the worse rule), the `scan-untrusted-content.py` Read-path
`json.dumps` escaping that killed every `^`-anchored pattern, the `validate-bash.sh` B4 ordering
evasion, and check 8b being vacuous for CIS (`cite.split()[0]` reduced everything to `"CIS"`).

Reviewing my own diff found the things I already knew to look for. Dispatching a reviewer found the
class of thing I had a blind spot for — an untested code path — which is exactly the argument for
the agent existing.

### Residual, unverified — stated, not dropped

- **Compound-command prefix matching.** Whether Claude Code splits `trivy fs . && …` before matching
  `Bash(trivy fs:*)`. Needs a live permission-system test. If it does not split, the allow-list
  narrowing is necessary but **not sufficient**. Recorded in `settings.json` in those words.
- **`kustomize build` / `kubectl kustomize`** take a remote URL and can exec a plugin under explicit
  alpha flags. Kept — rendering is the core workflow — but the comment says so now.
- Whether another hook shares the Edit-path assumption in a form the 87 cases don't reach.

### A false positive I chose to keep

The order-independent B4 fix in `validate-bash.sh` now matches a `Bash` command whose text merely
*describes* a Secret read — it blocked writing the changelog entry about itself via a heredoc.
Narrowing it to exclude prose would reintroduce the evasion. Documented in the changelog with the
workaround (use the file tools) rather than weakened. This is the one place in the session where I
accepted a false positive instead of fixing it, and it should be revisited if it fires again.

## Repo split — resolved, with a name correction

The user created **`BrendenKennedy/claude-for-ai-platforms`** (plural, private, `fork: false`,
default branch `main`) — a **standalone repo, not a GitHub fork**. That was the right call and the
reasoning is worth keeping:

- Pulling DS improvements is `git remote add upstream`, a **git** feature. The GitHub fork
  relationship is not required for it. The only thing a fork adds is one-click cross-repo PRs, and
  since the user owns both repos, pushing a branch to the parent achieves the same thing.
- Forks are excluded from GitHub code search by default and have issues off by default — a real
  cost for a scaffold whose pitch is "drop it into any project."
- The divergence is a rewrite, not an overlay: **91 new files, 42 inherited files modified, 65
  untouched, +12,703/−524**. The "forked from" badge would misdescribe it.

**The name differed from every document in the repo** — 24 occurrences of the singular
`claude-for-ai-platform` across 13 files, including the README title, both documented clone URLs,
and the clone URL embedded in `/upgrade`. That last one is the one that mattered: a wrong URL in the
command whose entire job is fetching the upstream release fails *silently* for every downstream
project. Renamed before the push, in two groups:

- **Product/repo name** — `README.md`, `CLAUDE.md`, `docs/TUTORIAL.md`, `commands/upgrade.md`,
  `commands/intake.md`, `install.sh`, and the `CHANGELOG.md` header (which still said "all notable
  changes to claude-for-datascience"). `docs/REFERENCE.md` regenerated via `build-reference.py`
  rather than hand-edited, since check 7 diffs it against frontmatter.
- **AWS IAM identity** — `infra-aws/SKILL.md`, `templates/aws-iam-policy.json`,
  `templates/README.md`, and a `validate-bash.sh` comment name an IAM user/policy/role, not the
  repo. Renamed for consistency: a principal called `…-platform` inside a repo called `…-platforms`
  is a 20-minute debugging tax. Pre-fork changelog entries naming the old `claude-for-datascience`
  IAM role were **left alone** — they were accurate when written.

**No version bump.** Nothing ever shipped under the singular name and there are no tags in this
clone, so a `1.3.1` for a name no user ever saw would be invented history.

## Increment 6 — the split was reversed (v1.4.0)

One command from pushing the split, the user asked the better question: why two repos, when
`/intake` could just ask which kind of project this is?

They were right, and the evidence was already in hand. The fork was **a superset, not a
divergence** — `/intake` already classified into two families and already flipped `skillOverrides`
per lane, so the machinery existed and was proven. Against that: 65 of 107 inherited files
untouched (pure duplication), branch 11 commits ahead of `main` with **zero divergence**, and the
`check-scaffold.sh` exit-status bug as a live example of the cherry-picking tax a split would have
imposed forever. Merged as a clean fast-forward; renamed to **`claude-for-ml-platforms`**.

### The merge only worked because both wings gate

This is the part that mattered. Merging two families into one repo makes the always-on set the
*union* of both — every project paying for what it didn't pick. Always-on was **17 skills**; it is
now **5** (the chassis). The security/platform spine and the DS core are both archetype-gated, and
`skillListingBudgetFraction` came back down 0.04 → 0.03.

**`agent-security` needed care rather than a sed.** It was made always-on eight days earlier on an
explicit rationale — *security defaults must not be opt-in* — and re-gating it as a side effect of a
context optimisation would have been exactly the kind of quiet reversal this repo's own doctrine
warns about. The resolution that made it defensible: **the skill was never the floor.** The floor is
the hooks (always on, zero context) plus the canon (on-demand); both hold regardless of profile. So
it gates on *"is there an LLM or agent in this at all?"* — asked **separately from the archetype**,
because the archetype maps wrong in both directions: a tabular project calling a model has an
agentic surface, an inference platform serving a classifier may not. Residual risk (a project that
adds an agent later and never flips it on) is real, recorded in `project-definition.md` where
`/gate` reads it — not argued away.

### §3.9 scales instead of applying uniformly

A uniform security track asks a CV project about admission control, which is how a checklist loses
legitimacy and starts getting bypassed — the same failure `secure-cicd` warns about for pipelines.
Three sizes now (platform lane · model-building with an LLM · model-building without), and
**`N/A — <archetype>` is a valid recorded gate answer** while silence is not.

### What this cost and didn't

Nothing was wasted: every file was already on the branch, and the merge was a fast-forward. The
`claude-for-ai-platform(s)` naming work from increment 5 was superseded within the hour — a real
cost of having planned the split first, though the naming *audit* it forced (the `/upgrade` clone
URL) would have been needed either way.

## Still open

- **The `claude-for-ai-platforms` repo is now orphaned** — created, never pushed to, superseded.
  The user should delete it, or keep it as a redirect placeholder.
- **The GitHub repo rename is a user action** — `claude-for-datascience` →
  `claude-for-ml-platforms`. The docs already name the new one, so the documented clone URLs are
  wrong until that rename happens. GitHub redirects the old URL afterwards.
- **The push itself** was resolved for `main` (merged and pushed). What remains blocked:
  `add_repo` (needed to widen the session's git proxy beyond
  `claude-for-datascience`) returns `requires approval` and the prompt does not reach this surface;
  `git ls-remote` against the new repo fails with `could not read Password`, confirming the proxy
  rejects it. The rename and verification are done and committed on
  `claude/ai-platform-security-fork-d8z8ha`; the user runs the three remote commands locally.
- **`origin` deliberately left pointing at `claude-for-datascience`** so the standing branch
  instruction is not silently redirected. Re-point it once the DS-side branch is settled.
- **A parent bug to send upstream:** `check-scaffold.sh`'s `python3 … || fails=…` swallows `$?`
  (always 0). Found here, applies to `claude-for-datascience` too. Not filed — cross-repo PRs
  need an explicit ask.
