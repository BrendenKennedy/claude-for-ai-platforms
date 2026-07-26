---
name: policy-as-code
description: >
  Enforcing platform rules mechanically — admission control, CI policy tests, and runtime detection,
  so a security rule is a check rather than a convention. Carries: Kyverno vs Gatekeeper/OPA and
  when each fits, validate/mutate/generate policy patterns, audit-then-enforce rollout so you don't
  break the cluster, conftest/Rego for the same rules in CI before the manifest merges, image
  signature verification at admission, Falco for runtime detection, and the three-layer model
  (edit-time hook, CI, admission) with the honest statement of which one is actually a boundary.
  Load when enforcing a platform rule across many workloads, wiring admission control, writing CI
  policy tests, or turning a repeated review comment into a check. Triggers: policy as code, OPA,
  Rego, Kyverno, Gatekeeper, admission controller, validating webhook, mutating webhook, conftest,
  Falco, runtime security, enforce pod security, cluster policy, block privileged containers, CIS
  compliance check, kube-bench. The rules themselves are `policy/platform-security.md`.
---

# policy-as-code — turning a rule people remember into a check that runs

**Pinned:** kyverno, opa/gatekeeper, conftest, falco, kube-bench — unpinned · authored 2026-07 · run
`/skill-update policy-as-code` once the tools are installed; CIS control numbering follows
`policy/frameworks/cis-kubernetes.md` (v2.0.1).

> On-demand: load this when a rule needs enforcing across many workloads rather than remembering. The
> *rules* are canon at `.claude/memory/policy/platform-security.md`; this skill is the enforcement
> machinery. Writing a single hardened manifest is `kubernetes`; pipeline wiring is `secure-cicd`.

## When this applies

A review comment you've made three times. A rule in canon with no mechanism. Wiring admission
control. Adding a CI policy gate. Detecting at runtime what you couldn't prevent.

## The three layers, and which one is real

`platform-security.md` states this and it's worth repeating because it determines where effort goes:

| Layer | Mechanism | Catches | Boundary? |
|---|---|---|---|
| **Edit** | `guard-k8s-manifests.py` (exit 2) | The misconfiguration as it's written | No — a guardrail |
| **CI** | `conftest` / Kyverno CLI on the PR | Anything authored outside a Claude session, or generated | No — bypassable by anyone with cluster access |
| **Admission** | Kyverno / Gatekeeper / PSS | Everything that reaches the API server | **Yes** |
| **Runtime** | Falco | What was already running when the policy changed, and what admission can't see | Detective, not preventive |

Only admission is enforced by the cluster. The earlier layers exist because finding out at admission
means finding out during a rollout, at which point the bad manifest is already merged and reviewed.
**Write the policy once, run it at all three.**

## Kyverno vs Gatekeeper

| | Kyverno | Gatekeeper (OPA) |
|---|---|---|
| Policy language | **YAML** — Kubernetes-native, no new language | **Rego** — powerful, genuinely hard to learn |
| Mutate / generate | Yes — can fix and create resources | Validation-focused |
| Scope | Kubernetes only | Anything (Rego runs on any JSON) |
| Best for | Kubernetes policy, most teams | Complex logic; policy reused beyond k8s |

**Default to Kyverno** for cluster policy — the YAML is reviewable by people who won't learn Rego,
which is what makes policy stick. Reach for OPA/Rego when the logic is genuinely complex, or when
you want the same policy over Terraform plans and manifests (`conftest`).

## Kyverno patterns

> **Start from the shipped baseline.** `.claude/templates/policies/kyverno-baseline.yaml` carries the
> cluster policies this scaffold's canon requires (`policy/platform-security.md`) already written —
> copy it into the project's `policies/` and adjust, rather than authoring from scratch. The
> `conftest` equivalent for CI is `templates/policies/conftest/platform.rego`.

**Validate** — the workhorse. Note `validationFailureAction: Audit` first; see rollout below.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: require-digest-pinned-images }
spec:
  validationFailureAction: Audit        # -> Enforce after the audit period (P4)
  background: true
  rules:
    - name: image-must-be-digest-pinned
      match:
        any: [{ resources: { kinds: [Pod] } }]
      validate:
        message: >-
          Images must be digest-pinned from an approved registry
          (platform-security.md P4, CIS 5.x). Use registry.example.com/name@sha256:...
        pattern:
          spec:
            containers:
              - image: "registry.example.com/*@sha256:*"
```

**Mutate** — apply a safe default rather than rejecting. Good for things authors forget and that have
an obviously correct value:

```yaml
    - name: default-deny-service-account-token
      match: { any: [{ resources: { kinds: [Pod] } }] }
      mutate:
        patchStrategicMerge:
          spec:
            +(automountServiceAccountToken): false     # P6
```

**Generate** — create the resources every namespace must have, so they can't be forgotten:

```yaml
    - name: every-namespace-gets-default-deny
      match: { any: [{ resources: { kinds: [Namespace] } }] }
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-all
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data: { spec: { podSelector: {}, policyTypes: [Ingress, Egress] } }
```

That last one is the highest-leverage policy in the set: it makes `P5` (default-deny networking) the
automatic state of every new namespace rather than a thing someone remembers.

**Verify images** — this is where `supply-chain.md` `C3` becomes real, because signing without
verification is theatre:

```yaml
    - name: verify-signature
      match: { any: [{ resources: { kinds: [Pod] } }] }
      verifyImages:
        - imageReferences: ["registry.example.com/*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/ORG/REPO/.github/workflows/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

## Rolling out without breaking the cluster

The way this goes wrong is shipping `Enforce` on day one and blocking a deploy at 2am.

1. **`Audit` first.** Policy runs, violations are recorded, nothing is blocked.
2. **Read the report.** `kubectl get policyreport -A` — expect existing violations; that's the point.
3. **Fix or exclude, explicitly.** Namespace exclusions for `kube-system` and vendor operators are
   normal; each is a decision-log entry (`platform-security.md`), not a quiet `exclude:` block.
4. **Flip to `Enforce`** for new resources, with the exclusions recorded.
5. **Keep the report.** It feeds `memory/process/control-coverage.md`.

Never exclude by wildcard. An exclusion nobody can enumerate is a policy nobody has.

## The same rules in CI

`conftest` runs Rego against rendered manifests before merge — the failure is a PR comment instead of
a failed rollout:

```bash
kubectl kustomize deploy/overlays/prod | conftest test -p policies/ -
kyverno apply policies/ --resource <(kubectl kustomize deploy/overlays/prod)   # same policies, CI
```

```rego
package main
deny[msg] {
  input.kind == "Deployment"
  c := input.spec.template.spec.containers[_]
  not c.resources.limits.memory
  msg := sprintf("%s: container %s has no memory limit (platform-security.md P3)",
                 [input.metadata.name, c.name])
}
```

**Test your policies.** A policy with no test asserting it *rejects* a bad input is a policy that
might be silently passing everything — the most common failure in a policy repo. Every rule gets a
fixture that must fail and one that must pass.

## Runtime detection — Falco

Admission checks what *could* run; Falco watches what *is* running (syscalls via eBPF). It's
detective, not preventive, and it covers what admission can't see: shell spawned in a container,
unexpected outbound connection, write to a binary directory, sensitive file read.

Tune before enabling alerts or the noise trains people to ignore it. Route to the same place as
telemetry (`observability`).

## Benchmarking the cluster

`kube-bench` asserts CIS Kubernetes Benchmark controls against the running cluster. Run it in CI
where the cluster is self-managed; on managed clusters, sections 1–4 are largely the provider's and
belong in `control-coverage.md` as their attestation rather than your finding. **Pair the benchmark
version to the cluster version** — v2.0.1 targets k8s 1.34/1.35, and a mismatch produces both false
passes and false failures.

## Gotchas

- **Audit mode forever.** A policy in `Audit` for six months is a report nobody reads. Set a date to
  flip it when you write it.
- **Policies that only run at admission.** Existing workloads were admitted under the old rules;
  `background: true` scans them, and the backlog is real.
- **Webhook failure policy.** `failurePolicy: Fail` means a broken policy controller blocks all
  deploys; `Ignore` means it silently stops enforcing. Both are wrong sometimes — choose per policy,
  deliberately, and monitor the webhook's own health.
- **Blocking without a message that says what to do.** Every policy message names the canon rule and
  the fix, or people work around it.
- **Assuming policy replaces the hook.** They catch different things at different times; the hook is
  what stops the manifest being written, and the policy is what stops it running.
