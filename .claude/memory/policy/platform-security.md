# Platform security policy — clusters, workloads, images, and networks

The canon for the `platform-security` domain (registered in the `governance` skill). Universal rules
are concrete and hold for every project that deploys a workload; org-specific values are marked
`<PLACEHOLDER: …>`. Load this before writing a manifest, provisioning a cluster or namespace,
building a runtime image, or opening a network path.

Rules are named (`P1`, `P2`, …) so a hook message, a review finding, or a decision-log entry can cite
one. Each carries a one-line **why**. Bracketed IDs cite the framework that motivates the rule —
`[CIS 5.2]`, `[PSS]` — and resolve in `frameworks/`.

Sibling canon: identity, RBAC subjects, and credentials are `identity-and-access.md`; where an image
or dependency *came from* is `supply-chain.md`; what the workload is allowed to do as an agent is
`ai-security.md`. This file governs the runtime substrate.

## Three enforcement points, deliberately

The same constraint is checked three times, and each layer catches what the previous one missed:

| Layer | Mechanism | Catches |
|---|---|---|
| **Edit** | `guard-k8s-manifests.py` (exit 2) | The misconfiguration before it is ever committed |
| **CI** | `conftest` / Kyverno policies in `secure-cicd` | Anything authored outside a Claude session, or generated |
| **Admission** | Pod Security admission + `policy-as-code` | Everything, including what bypassed both — this is the only one the cluster enforces |

**Only the admission layer is a security boundary.** The first two are guardrails in the sense of
`security.md`'s threat model: they stop the common accident cheaply and loudly, and a determined
bypass defeats them. Never treat a passing hook as clearance for a workload the cluster would reject.

## Workload configuration

**P1 — Every workload runs under Pod Security `restricted`.** Non-root, `allowPrivilegeEscalation:
false`, all capabilities dropped (except `NET_BIND_SERVICE` where genuinely needed), a seccomp
profile set, and a read-only root filesystem unless the workload provably cannot. Namespaces carry
`enforce`, `audit`, and `warn` labels at `restricted`, set at namespace creation. `baseline` requires
a decision-log entry naming the workload and the field; `privileged` requires that plus a named human
owner and applies only to infrastructure components (CNI, CSI, node agents).
*Why: the container isolation boundary is a shared kernel, so configuration is doing the work a
hypervisor would otherwise do. [PSS][CIS 5.2][NSA/CISA]*

**P2 — No host namespace, host filesystem, or host device access.** `hostNetwork`, `hostPID`,
`hostIPC`, `hostPath` volumes, and privileged device mounts are refused. A workload that needs host
data gets it through an API, not the host filesystem.
*Why: each of these collapses the container boundary entirely — a `hostPath` mount of `/` is a root
shell on the node with extra steps. [PSS][CIS 5.2][SP 800-190]*

**P3 — Every workload declares resource requests and limits.** CPU and memory on every container,
including init and sidecar containers. Namespaces carry a `ResourceQuota` and a `LimitRange`.
*Why: an unlimited workload is a denial-of-service vector against every other workload on the node,
and for GPU-backed inference it is also a cost incident. [CIS 5.x]*

**P4 — Images are pinned by digest and pulled from an approved registry.** `image: repo/name@sha256:…`
— never `:latest`, never an untagged reference, never a mutable tag in production. The registry is
one the project controls or has explicitly approved, and `imagePullPolicy` is consistent with digest
pinning. Signature verification happens at admission (`supply-chain.md` `C3`).
*Why: a mutable tag means the thing you reviewed and the thing that runs are different artifacts, and
nothing in the cluster will tell you they diverged. [SP 800-190][CIS 5.x]*

## Network

**P5 — The network is default-deny.** Every namespace has a `NetworkPolicy` denying all ingress and
egress, with narrow allow rules added per workload for the specific peers and ports it needs. Egress
to the internet is explicit and enumerated, not the default. Workloads that need no network get none.
*Why: flat pod networking turns any single compromised workload into lateral access to everything in
the cluster, and it is the default state of every Kubernetes install. [NSA/CISA][CIS 5.3]*

**P10 — Tenancy boundaries are enforced by namespace, policy, and quota — never by convention.**
Where workloads of different sensitivity or different tenants share a cluster, separation is
structural: distinct namespaces, network policies denying cross-namespace traffic, distinct service
accounts and RBAC, resource quotas, and — where the sensitivity gap warrants it — distinct node pools.
"They're in the same cluster but they don't talk to each other" is a statement about current
behaviour, not a control.
*Why: mixing sensitivity levels on shared infrastructure is the classic container risk, and namespace
alone is an organisational boundary, not a security one. [SP 800-190][NSA/CISA]*

## Authorization and secrets

**P6 — RBAC is least-privilege and never wildcard.** No `*` in `verbs`, `resources`, or `apiGroups`
in any Role or ClusterRole this project authors. `cluster-admin` is never bound to a workload.
Prefer namespaced `Role` over `ClusterRole`; bind to a specific ServiceAccount, never to `default`,
`system:authenticated`, or a group. `automountServiceAccountToken: false` unless the workload calls
the Kubernetes API.
*Why: wildcard RBAC is how a workload compromise becomes a cluster compromise, and it is almost
always the result of copying an example rather than a deliberate decision. [CIS 5.1][NSA/CISA]*

**P7 — Secrets are never plaintext in a manifest, a repository, or an image.** No literal `data:` or
`stringData:` values in committed YAML. Secrets are delivered by an external secret manager, a
CSI driver, or projected short-lived tokens; where a Kubernetes `Secret` object is used, it is
created out-of-band and encryption at rest is on. Environment variables holding secrets are visible
in `kubectl describe`, pod specs, and crash dumps — prefer mounted files.
*Why: a secret in git is a secret that must be rotated, and history is immortal (`security.md` `S4`).
[CIS 5.4][NSA/CISA]*

## Cluster and evidence

**P8 — The control plane and etcd are hardened, with encryption at rest.** Anonymous authentication
off, appropriate authorization mode, TLS everywhere including etcd peer and client traffic, encryption
at rest for secrets, and the API server not exposed to the internet. On a managed cluster this is
substantially the provider's responsibility — record which controls are theirs, and their attestation,
in `memory/process/control-coverage.md` rather than assuming.
*Why: etcd holds every secret in the cluster in a single place, and "the provider handles it" is only
true for the parts they actually handle. [CIS 1–3][NSA/CISA]*

**P9 — Audit logging is on, and shipped off-cluster.** The API server audit policy captures at least
authentication failures, RBAC denials, secret access, exec and port-forward, and workload mutations.
Logs go to a destination the cluster's own credentials cannot delete.
*Why: an audit log an attacker with cluster access can erase is not evidence, and this is the control
that determines whether an incident can be investigated at all. [NSA/CISA][CIS 3.2]*

**P11 — Data stores are never internet-reachable and never default-credentialed.** Every database,
cache, queue, vector store, graph store, and search index sits in a private subnet or a
cluster-internal network, reachable only from the workloads that need it (`P5`). Authentication is
on and the shipped default credential is gone before the service accepts a connection. Specifically:
no `publicly_accessible` managed database, no `0.0.0.0/0` on a database port, no Redis or
Elasticsearch or MongoDB bound to a public interface, and no store relying on network position as
its only authentication. Where an operator or client needs access, it goes through a bastion, a
VPN, or a proxy with its own authentication — never a public endpoint with a password.
*Why: unauthenticated, internet-exposed data stores are the most reliably exploited class of
misconfiguration there is, they are found by internet-wide scanning within hours, and every instance
of it began as a default that nobody changed. `guard-iac.py` blocks the shapes it can see; this rule
covers the ones it cannot. [CIS 5.3][NSA/CISA][SP 800-190]*

`<PLACEHOLDER: approved container registries, and who approves a new one>`
`<PLACEHOLDER: the cluster's tenancy model — dedicated, namespace-per-team, or shared — and the
sensitivity classes permitted to share a node pool>`

## Recording a judgment call

Irreducible judgment calls — a workload that genuinely needs `hostNetwork`, a `baseline` namespace, a
registry exception, a wildcard RBAC rule in a vendored chart — go in
`platform-security-decision-log.md` beside this file. Append-only: *what / which rule / why*. A
reversal is a new entry. Created on the first call; absence means no exception has ever been granted.
