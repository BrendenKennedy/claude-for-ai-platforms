# CIS Kubernetes Benchmark — the cluster configuration baseline

**Identity:** Center for Internet Security · **v2.0.1** (June 2026 release, covering Kubernetes
v1.34 and v1.35) · https://www.cisecurity.org/benchmark/kubernetes
**Verified:** 2026-07-25 against CIS's benchmark page and its June 2026 release notes.
**Canon citing it:** `platform-security.md` (P1, P2, P6, P7, P8, P9)

> The line-by-line configuration standard for a Kubernetes cluster — what each control-plane flag,
> file permission, and workload setting should be. It is the thing `kube-bench` asserts against, which
> makes it the rare security framework that is directly, automatically checkable.

## The structure

Sections are grouped by what you control, which matters because managed clusters (EKS/GKE/AKS) hand
you only some of them:

| Section | Covers | Who controls it |
|---|---|---|
| 1 | Control-plane components — API server, scheduler, controller manager, etcd flags and file permissions | You, on self-managed; the provider on managed |
| 2 | etcd configuration — TLS, peer auth, encryption at rest | You / provider |
| 3 | Control-plane configuration — authentication and authorization modes, audit policy | Shared |
| 4 | Worker nodes — kubelet configuration and file permissions | You |
| 5 | Policies — RBAC, service accounts, Pod Security, network policies, secrets, image provenance | **Always you** |

Controls are numbered `<section>.<subsection>.<control>` (e.g. `5.2.5`) and split into Level 1
(broadly safe) and Level 2 (defense-in-depth, may break things). CIS also distinguishes Automated
from Manual assessment. Provider-specific variants exist (EKS, GKE, AKS) — use the one matching your
distribution.

## What we adopt

- **Section 5 in full, as mandatory.** These are workload-level policies that apply to every cluster
  regardless of who runs the control plane, and they are the ones a project team actually owns. They
  are the direct source of canon rules `P1`, `P2`, `P6`, `P7`.
- **Sections 1–4 as the target for the cluster we deploy onto**, asserted by `kube-bench` in CI where
  the cluster is self-managed, and accepted as the provider's responsibility where it is not — with
  the provider's attestation recorded in `memory/process/control-coverage.md`.
- **`kube-bench` as the mechanism.** A benchmark nobody runs is a document. `secure-cicd` wires it;
  results land in the control-coverage file.
- **The section-5 numbering as citation targets** so a hook message can say *"blocked: privileged
  container — `platform-security.md` P1, CIS 5.2.x"* and the reader can go read the rationale.

## What we leave

- **The Level 1 / Level 2 and Scored / Not Scored distinctions.** We treat our adopted subset as
  mandatory and record exceptions in the decision log instead. A control that is "recommended but not
  scored" tends to be a control nobody implements.
- **Provider-specific benchmark variants as canon.** Canon states the invariant; the `kubernetes` and
  `infra-aws` skills carry the distribution-specific how-to.
- **Full-benchmark remediation prose.** Long, and better read at the publisher.

## How it lands here

| CIS area | Canon rule | Mechanism |
|---|---|---|
| §5 Pod Security / privileged workloads | `P1`, `P2` | `guard-k8s-manifests.py` (exit 2) · PSS `restricted` in `templates/k8s/` |
| §5 RBAC and service accounts | `P6` | `guard-k8s-manifests.py` (wildcard RBAC) · `policy-as-code` |
| §5 Secrets management | `P7` | `guard-secrets.py` · `secrets-management` |
| §5 Network policies | `P5` | default-deny NetworkPolicy in `templates/k8s/` |
| §5 Image provenance | `P4` | `guard-k8s-manifests.py` (`:latest`/untagged) · `supply-chain-security` |
| §1–4 control plane, etcd, kubelet | `P8`, `P9` | `kube-bench` in `secure-cicd` · recorded in `control-coverage.md` |

## Gotcha

**The benchmark version tracks Kubernetes versions.** v2.0.1 targets k8s 1.34/1.35; running it against
a materially older or newer cluster produces both false passes and false failures. Check the pairing
before treating a `kube-bench` run as evidence — and re-verify this document when the cluster
upgrades, not on a calendar.
