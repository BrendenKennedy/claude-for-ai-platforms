# NSA/CISA Kubernetes Hardening Guide — the hardening narrative

**Identity:** National Security Agency + Cybersecurity and Infrastructure Security Agency · **v1.2**
(August 2022) · https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF
**Verified:** 2026-07-25. v1.0 August 2021, v1.1 March 2022, v1.2 August 2022 (corrections and
clarifications). **No newer revision found** — this is the current version, and it is old enough that
Kubernetes-version-specific details should be checked against `cis-kubernetes.md` before being
treated as current.
**Canon citing it:** `platform-security.md` (P2, P5, P8, P9, P10)

> Where CIS gives you a checklist, this gives you the argument: *why* these settings, what the threat
> is, and how the pieces compose into a defensible cluster. We carry it because it is the readable
> narrative that makes the CIS controls make sense, and because government-backed hardening guidance
> carries weight in a compliance conversation that a blog post does not.

## What it covers

| Area | The guidance |
|---|---|
| Pod security | Run containers as non-root, with immutable filesystems, without privilege; use a policy mechanism to enforce it rather than relying on authors |
| Network separation | Deny by default; segment with network policies; firewall the control plane; encrypt in transit |
| Authentication & authorization | Disable anonymous auth, use strong auth, apply RBAC least-privilege, avoid long-lived tokens |
| Log auditing | Enable audit logging, collect it **off-cluster**, monitor for the events that indicate compromise |
| Threat detection & upgrade | Scan images and pods for vulnerabilities and misconfiguration; patch promptly; periodically review settings |
| etcd | Mutual TLS between etcd and the API server; encryption at rest; restrict access |

Its threat model is explicit and worth reading: supply chain compromise, malicious threat actors, and
insider threats — with the observation that most real Kubernetes compromises come from
misconfiguration rather than exotic exploitation.

## What we adopt

- **Default-deny networking as a canon rule** (`P5`). This guide is the clearest statement of why:
  flat pod networking means one compromised workload reaches everything.
- **Audit logs shipped off-cluster** (`P9`). An audit log an attacker with cluster access can delete
  is not an audit log. This is the rule most often skipped in project clusters.
- **Policy-mechanism enforcement over author discipline** (`P1`). The guide's framing — that pod
  security must be *enforced*, not requested — is why `policy-as-code` exists as a skill and why
  `guard-k8s-manifests.py` blocks rather than warns.
- **etcd hardening + encryption at rest** (`P8`).
- **Its threat-model section** as an input to `/threat-model` for any project running on Kubernetes.

## What we leave

- **Air-gapped and classified-environment assumptions.** Some guidance presumes an operating context
  most projects do not have.
- **Version-specific flag detail.** v1.2 predates several Kubernetes releases; where it and
  `cis-kubernetes.md` v2.0.1 disagree on a specific flag or API, **CIS wins on the specifics** and
  this document wins on the reasoning. Canon states the invariant so the disagreement never reaches
  a rule.
- **Its example manifests.** Superseded by Pod Security Standards `restricted`; our baseline lives in
  `templates/k8s/`.

## How it lands here

| Guidance area | Canon rule | Mechanism |
|---|---|---|
| Pod security enforcement | `P1`, `P2` | `guard-k8s-manifests.py` · `policy-as-code` (Kyverno) |
| Network separation | `P5` | default-deny NetworkPolicy in `templates/k8s/` · `kubernetes` |
| Authentication & RBAC | `P6`, `I1`, `I3` | `authn-authz` · `guard-k8s-manifests.py` |
| Audit logging off-cluster | `P9` | `observability` · `templates/otel-collector.yaml` |
| etcd hardening | `P8` | `platform-security.md` · recorded in `control-coverage.md` |
| Scanning & patching | `C5` | `supply-chain-security` · `secure-cicd` |
| Multi-tenancy | `P10` | `kubernetes` · `policy-as-code` |

## Gotcha

**This document is from 2022 and Kubernetes is not.** Treat it as durable *reasoning* and dated
*specifics*. Anything it says about a particular API version, flag name, or deprecated feature needs
checking against the running cluster before you act on it — which is exactly why canon cites it for
principles (`P5`, `P9`, `P10`) and cites CIS for configuration.
