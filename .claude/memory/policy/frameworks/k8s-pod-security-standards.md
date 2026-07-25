# Kubernetes Pod Security Standards — the workload baseline

**Identity:** Kubernetes project · versionless, tracks the Kubernetes release ·
https://kubernetes.io/docs/concepts/security/pod-security-standards/
**Verified:** 2026-07-25. Three profiles (`privileged`, `baseline`, `restricted`) and the Pod
Security admission controller are stable and unchanged in shape; individual field requirements track
the Kubernetes version in use.
**Canon citing it:** `platform-security.md` (P1, P2)

> Kubernetes' own answer to "what should a pod be allowed to do", expressed as three cumulative
> profiles and enforced by a built-in admission controller. It is the most directly actionable
> hardening standard in this directory: it is not advice, it is a switch you turn on.

## The three profiles

| Profile | Intent | In practice |
|---|---|---|
| **`privileged`** | Unrestricted | No constraints at all. For infrastructure workloads that genuinely need host access (CNI, CSI, node agents) — and nothing else. |
| **`baseline`** | Prevents known privilege escalations | Blocks host namespaces, privileged containers, most `hostPath` volumes, dangerous capabilities, and unsafe sysctls. Permits running as root. |
| **`restricted`** | Hardened, current best practice | Everything in `baseline`, plus: must run as non-root, `allowPrivilegeEscalation: false`, seccomp profile set (`RuntimeDefault` or `Localhost`), all capabilities dropped except `NET_BIND_SERVICE`, and volume types limited. |

### The enforcement mechanism

Pod Security admission is built into Kubernetes and configured **per namespace** with labels, in
three independent modes:

```yaml
pod-security.kubernetes.io/enforce: restricted   # reject violating pods
pod-security.kubernetes.io/audit:   restricted   # record them in the audit log
pod-security.kubernetes.io/warn:    restricted   # warn the applying user
```

Enforce blocks, audit records, warn informs — they can be set to different profiles, which is the
supported migration path: `warn`/`audit` at `restricted` while `enforce` is still at `baseline`.

## What we adopt

- **`restricted` is the default for every workload this scaffold generates** (`P1`). Templates in
  `templates/k8s/` are written to pass it, so the secure configuration is the one you get for free
  and any weakening is a visible diff.
- **Namespace labels set at creation**, all three modes at `restricted` — not added later, because
  "we'll tighten it after launch" is how clusters end up permanently at `baseline`.
- **`baseline` only with a recorded exception** in the `platform-security` decision log, naming the
  workload and the field it needs. `privileged` requires the same plus a named human owner.
- **The mechanism itself as the argument for `policy-as-code`.** PSS enforces the profile at the API
  server; it does not enforce *anything else* — resource limits, image provenance, and required
  labels need Kyverno or Gatekeeper. PSS is necessary and not sufficient.

## What we leave

- **PodSecurityPolicy.** Removed in Kubernetes 1.25. If you find PSP in a manifest or a guide, it is
  dead; PSS plus an admission policy engine replaced it.
- **Per-field remediation prose.** The Kubernetes docs carry it and stay current; our templates carry
  the working example.

## How it lands here

| PSS element | Canon rule | Mechanism |
|---|---|---|
| `restricted` profile as default | `P1` | `templates/k8s/` baseline · `/bootstrap` generates it |
| Host namespaces / `hostPath` blocked | `P2` | `guard-k8s-manifests.py` (exit 2, pre-cluster) |
| Non-root, no privilege escalation, caps dropped | `P1` | `guard-k8s-manifests.py` · `kubernetes` |
| Namespace enforce/audit/warn labels | `P1`, `P10` | `templates/k8s/` · `kubernetes` |
| What PSS does *not* cover | `P3`, `P4`, `P5` | `policy-as-code` (Kyverno) · `guard-k8s-manifests.py` |

## Gotcha

**PSS only runs at the API server, which is late.** By the time admission rejects a pod, the bad
manifest is already committed, reviewed, and deployed by CI — you find out during rollout. That is
why this scaffold checks the same constraints three times: `guard-k8s-manifests.py` at the edit,
`conftest`/Kyverno in CI at the pull request, and PSS at admission as the backstop. Each layer
catches what the previous one missed, and only the last one is enforced by the cluster.
