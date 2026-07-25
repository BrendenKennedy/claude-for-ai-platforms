# Architecture: how the security layers divide, and why

Companion to `architecture-skills-vs-agents.md`. That note explains why knowledge lives in skills
rather than an orchestrator agent; this one explains why a *security rule* lives in four different
places, and which place is authoritative for what. Pulled on demand — read it before adding a rule,
a guard, or a policy, so the new thing lands in the right layer.

## The four layers

| Layer | Artifact | Answers | Authoritative for |
|---|---|---|---|
| **Canon** | `memory/policy/<domain>.md` | *What must be true?* | The rule and its `why`. Wins on any conflict |
| **Skill** | `skills/<name>/SKILL.md` | *How do I do it?* | Idioms, commands, patterns, the current tooling |
| **Hook** | `hooks/guard-*.py` | *What stops me getting it wrong?* | Mechanical enforcement at the edit |
| **Agent** | `agents/<name>.md` | *Who checks the whole surface?* | Review, threat modelling, adversarial testing |

The rule that keeps them from duplicating each other: **canon states the obligation once, and
everything else points at it.** A skill that restates a canon rule will drift from it; a hook message
that explains the reasoning instead of naming the rule teaches people to argue with the hook.

## Why canon and skills are separate

Inherited from the parent scaffold, and it holds harder here. Canon is *stable* — "images are pinned
by digest" is true across cluster versions, cloud providers, and tooling generations. Skills are
*current* — the exact `cosign verify` invocation is not stable, and pretending otherwise produces
confidently stale instructions.

So: canon has no version pins and no tool names it can avoid. Tool skills carry a `**Pinned:**` line
and `/skill-update` keeps them honest. When a tool changes, one file changes.

## Why frameworks got their own subdirectory

The parent scaffold's convention was *"methodology cites lineage; policy asserts rules"* — canon
carried zero external citations. This fork changed it, deliberately, because the whole value
proposition here is that the rules are sourced from professional frameworks rather than invented.

The compromise that keeps canon readable: **canon cites control ids only** (`[LLM01]`, `[ASI06]`,
`[CIS 5.2]`); the framework text, version, publisher, verification date, and *what we leave* live in
`policy/frameworks/`. Canon gains a bracketed id per rule; it does not gain URLs, version numbers,
or framework prose.

`check-scaffold.sh` check 8 enforces the half that would otherwise rot: a cited id that resolves to
nothing fails CI.

**Why versions and verification dates are mandatory there and nowhere else in the repo:** security
frameworks move faster than the tools do. The OWASP agentic list did not exist when the parent
scaffold shipped. CIS Kubernetes had multiple releases in a year. NIST SP 800-63 sat in draft for
four years and then went final. An unversioned framework doc reads as current and silently isn't —
which is worse than no doc, because a reader trusts it.

## Why the same constraint is checked three times

A privileged pod is rejected at the edit (`guard-k8s-manifests.py`), in CI (`conftest`/Kyverno), and
at admission (Pod Security). That looks redundant. It isn't:

- **Only admission is a security boundary.** It is the only layer the cluster enforces, and the only
  one that catches a manifest authored outside this repo.
- **The edit-time hook is the cheapest feedback.** It fails in one second, in context, while the
  author is still thinking about the thing.
- **CI catches what neither sees** — generated manifests, Helm chart output, anything a human wrote
  in another editor.

Each layer catches what the previous one missed, and the honest statement of which one is a boundary
is in `platform-security.md` itself. **Never treat a green hook as clearance** — that is
`security.md` `S1`, and it is the sentence that keeps the whole arrangement from being
self-deceiving.

## Why hooks fail open, in a security scaffold

It looks backwards: a security guard that lets things through when confused. The reasoning is in
`security.md` `S1` and it is load-bearing —

**The hooks are not the boundary.** They are guardrails against agent *mistakes*. A determined
bypass (encoding, indirection, a tool the hook doesn't match) defeats them, and that is accepted.
What they buy is stopping the common accident cheaply and loudly.

Given that, a hook that fails *closed* on unparseable input trades a benefit it doesn't provide
(real adversary resistance) for a cost it certainly does (bricked sessions). And a hook that bricks
sessions gets deleted — at which point the guardrail provides nothing at all. Fail-open keeps the
guard installed, which is the only state in which it helps.

This is why `check-hooks.py` tests the fail-open path explicitly. It is the behaviour nobody thinks
to test and the one that decides whether the guard survives contact with real work.

## Why Kubernetes was un-parked

The parent scaffold recorded a deliberate decision to park Kubernetes: *"Compose covers the
support-service need at this scaffold's scale; orchestration is a platform decision, not a scaffold
one"* (`containers/SKILL.md`, plus the `2026-07-18-audit-and-lifecycle` session note and the
roadmap).

That reasoning was correct for a data-science scaffold, where orchestration is incidental to the
work. It is wrong for this fork, where orchestration *is* the work — an AI platform runs on a
cluster, and most of `platform-security.md` has no meaning without one.

The reversal is recorded in `memory/process/decision-log.md` rather than performed silently, because
the original decision was reasoned and a future reader deserves to see both halves.

**Service mesh remains parked**, and for the parent's reasoning: mTLS is covered as a *property* in
`identity-and-access.md` `I7` (which a project can satisfy with or without a mesh), and traffic
policy is a platform decision a scaffold shouldn't make. Revisit when a project needs it.

## Where a new rule goes

1. **Is it an obligation?** → canon, numbered, with a `why`, in the domain that owns it. Register it
   in the `governance` skill's index **and** fold its triggers into that skill's description — miss
   the second and the domain is unreachable.
2. **Is it a technique?** → the relevant skill. Point at the canon rule; don't restate it.
3. **Can a machine check it deterministically?** → a hook, or a policy in `templates/policies/`.
   Prefer the policy: it runs in CI and at admission, not only in a Claude session.
4. **Does it need judgement across a whole surface?** → an agent.
5. **Is it a published framework's control?** → a framework doc, with the id cited from the canon
   rule it motivates.

If a rule seems to want all five, it is probably two rules.
