# SPIFFE / SPIRE — workload identity without secrets

**Identity:** CNCF · SPIFFE specification 1.0 (graduated project) · https://spiffe.io/
**Verified:** 2026-07-25. SPIFFE is a CNCF graduated project with a stable 1.0 specification; SPIRE
is its reference implementation.
**Canon citing it:** `identity-and-access.md` (I3, I7)

> The answer to "how does service A prove to service B that it is service A, without a shared secret
> anyone can steal?" In a Kubernetes-based AI platform most identities are workloads, not people, and
> this is the standard that covers them.

## The primitives

| Concept | What it is |
|---|---|
| **SPIFFE ID** | A URI naming a workload: `spiffe://trust-domain/ns/prod/sa/inference-api`. Human-readable, hierarchical, and stable across restarts and reschedules. |
| **SVID** | The credential proving that identity — an X.509 certificate or a JWT. **Short-lived by design** (minutes to hours) and rotated automatically. |
| **Trust domain** | The root of trust an identity belongs to; cross-domain trust is explicit federation, not a shared CA. |
| **Workload API** | A local endpoint a workload calls to get its own SVID. **It presents no credential to do so** — the agent identifies it by attesting its properties. |
| **Attestation** | How the platform decides what a workload is: node attestation (which machine) plus workload attestation (which pod, service account, selector). |

**SPIRE** is the reference implementation: a server holding the trust domain's CA, and per-node
agents that attest workloads and issue SVIDs.

## Why it matters here

The chain it eliminates is the one every platform accumulates: a service needs a credential → the
credential is stored in a secret → the secret is mounted into the pod → the secret is long-lived
because rotating it means a redeploy → it ends up in a `.env`, a CI variable, and eventually a git
history. SPIFFE removes the credential entirely: the workload's *identity is derived from its
platform properties*, and the certificate proving it expires before anyone can exfiltrate and reuse
it usefully.

For an agent platform this is the concrete implementation of canon `AI6` (agent identity is distinct,
scoped, attributable) and the structural fix for OWASP `ASI03` (agent identity and privilege abuse):
each agent gets its own SPIFFE ID, so "which agent did this?" has an answer at the transport layer
rather than in application logs.

## What we adopt

- **No static, long-lived workload credentials** (canon `I3`). Where SPIFFE/SPIRE is deployed, SVIDs;
  where it is not, the platform's native equivalent — Kubernetes projected service-account tokens
  with an audience, IRSA/Workload Identity on cloud, OIDC federation from CI. The rule is *the
  property*, not the product, and canon is written that way so a project without SPIRE can still
  comply.
- **mTLS between services with identity-based authorization** (`I7`): the peer's SPIFFE ID is the
  authorization input, not its IP or network position.
- **Per-agent identities** rather than one shared platform service account — attributability is a
  security control, not a logging nicety.
- **Short lifetimes over revocation.** A credential that expires in an hour needs no revocation
  infrastructure.

## What we leave

- **Service-mesh integrations.** Istio and Linkerd consume SPIFFE identities natively, but service
  mesh is deliberately parked in this scaffold (see `memory/process/decision-log.md`), so canon
  states the identity property and leaves mesh wiring out.
- **Cross-cloud federation topology.** Real, and a platform-architecture decision rather than a
  scaffold rule.
- **SPIRE as a requirement.** It is one implementation. Requiring a specific product in canon would
  make most projects non-compliant on day one for no security gain.

## How it lands here

| Element | Canon rule | Mechanism |
|---|---|---|
| Short-lived, platform-issued workload credentials | `I3` | `authn-authz` · `secrets-management` |
| mTLS with identity-based authz between services | `I7` | `authn-authz` · `kubernetes` |
| Per-agent distinct identity | `AI6` | `agent-security` · `agent-authority.md` |
| No long-lived secrets to rotate | `I9`, `S2` | `secrets-management` · `guard-secrets.py` |

## Gotcha

**Workload identity solves authentication, not authorization.** An SVID proves a caller is
`spiffe://…/sa/inference-api`; whether that workload may read a given object is a separate decision
that still has to be made, and made server-side (`I4`). Platforms that deploy SPIRE and then allow
any authenticated workload to call any service have swapped a credential-theft problem for a lateral-
movement problem — which is why canon pairs `I7` with `P5` (default-deny networking).
