# Identity and access policy — who is calling, and what they may do

The canon for the `identity-and-access` domain (registered in the `governance` skill). Universal
rules are concrete; org-specific values are marked `<PLACEHOLDER: …>`. Load this before adding
authentication, issuing or validating a token, granting a permission, wiring service-to-service
traffic, or giving an agent authority to act for someone.

Rules are named (`I1`, `I2`, …) so a review finding or a decision-log entry can cite one. Each
carries a one-line **why**. Bracketed IDs cite the motivating framework — `[800-63 AAL2]`,
`[OAuth 2.1]` — and resolve in `frameworks/`.

Sibling canon: cluster RBAC *objects* are `platform-security.md` `P6`; secrets in the development
loop are `security.md`; what an agent may do with delegated authority is also `ai-security.md` `AI2`
and `AI6` — this file governs how that authority is issued, proven, and bounded.

## The two identity populations

Most platform security writing is about humans; in a Kubernetes-based AI platform, **most identities
are workloads**, and they need different controls. Keep them distinct:

| | Human identities | Workload identities |
|---|---|---|
| Proving identity | Phishing-resistant MFA via an IdP | Platform attestation — what the workload *is* |
| Credential lifetime | Session-scoped | Minutes to hours, auto-rotated |
| The failure mode | Phishing, credential reuse | Long-lived secrets in a repo or image |
| Governing rule | `I2` | `I3` |
| Framework | `nist-800-63.md` | `spiffe-spire.md` |

Applying assurance levels to a service account, or attestation to a person, is a category error and
produces controls that satisfy neither.

## Authentication

**I1 — Every principal is uniquely identifiable; no shared accounts, ever.** Each human, each
workload, and each agent authenticates as itself. Shared credentials, shared service accounts across
workloads, and "the deploy user" are prohibited. Every action traces to one principal.
*Why: shared identity destroys attribution and makes least privilege arithmetically impossible — the
shared account gets the union of everyone's needs. [800-53 AC-2][CSF PR.AA]*

**I2 — Human access uses multi-factor authentication; administrative access is phishing-resistant.**
AAL2 is the floor for any human access. **AAL3 — phishing-resistant, verifier-impersonation-resistant
(WebAuthn/FIDO2, passkeys, hardware keys)** — is required for anything administrative: cluster admin,
cloud console, production secrets, CI/CD configuration, and IdP administration. SMS and TOTP do not
meet the administrative bar.
*Why: TOTP does not survive a real-time relay, and administrative credentials are precisely what a
targeted phish is after. [800-63B AAL2/AAL3]*

**I3 — Workload credentials are short-lived and platform-issued. No static secrets.** Workloads
receive identity from the platform. The mechanism per environment — the rule is the *property*, not
the product, so a project on any of these complies:

| Environment | The mechanism |
|---|---|
| Any cluster running SPIRE | SPIFFE SVIDs (X.509 or JWT), auto-rotated |
| Kubernetes, in-cluster | Projected ServiceAccount tokens with an explicit `audience` and short `expirationSeconds` |
| AWS | IRSA or EKS Pod Identity — the pod's SA maps to a role; no keys anywhere |
| GCP | Workload Identity Federation — the KSA binds to a Google service account |
| Azure | Azure Workload Identity — the SA federates to a managed identity |
| CI → cloud | OIDC federation, with the trust policy scoped to the repo **and the branch** |

Long-lived API keys, static cloud access keys, and mounted credential files are prohibited for
service-to-service authentication. This applies to CI/CD as a workload: **no long-lived cloud
credentials in a pipeline** — federate.
*Why: a credential that does not expire is a credential that will eventually be found in a repo, a
log, or an image layer, and rotating it means a redeploy nobody schedules. [SPIFFE][CICD-SEC-6]*

**I9 — Credentials are rotated on a schedule, and immediately on exposure.** Every credential that
cannot be short-lived has a documented owner, a rotation interval, and a rotation procedure that has
actually been executed at least once. Exposure means rotate-first — deleting the line does nothing
(`security.md` `S4`).
*Why: an untested rotation procedure fails during the incident that requires it. [800-53 IA-5]*

## Authorization

**I4 — Authorization is decided server-side, on every request, against the specific object.** A valid
token proves who is calling; it decides nothing else. Every request re-checks: is this principal
permitted this action on *this* object, in *this* tenant? Client-supplied identifiers, roles, or
tenant claims are inputs to the check, never the result of it. Filtering a UI is not authorization.
*Why: almost every real API authorization bug — IDOR, tenant bleed, missing object-level checks —
lives on the far side of a correctly validated token, in code the auth protocol never touches.
[OWASP][800-53 AC-3]*

**I5 — Tokens are scoped, short-lived, and audience-bound.** The narrowest scope that completes the
task, the shortest lifetime the workflow tolerates, and an `aud` naming the intended service. OAuth
2.1 mandates apply: PKCE on every authorization-code flow, no implicit grant, no
resource-owner-password grant, exact-string redirect URI matching, and no bearer tokens in query
strings. Refresh tokens are one-time-use or sender-constrained.
*Why: scope and lifetime are what bound the damage of the token compromise you should assume will
happen; revocation is hard and expiry is free. [OAuth 2.1][RFC 9700]*

**I6 — JWT validation is complete, or it is not validation.** Verify the signature against the
issuer's JWKS with rotation handled; **reject `alg: none` and pin the expected algorithm** rather
than trusting the token's own header; check `iss` exactly; check `aud` contains this service; check
`exp` and `nbf` with minimal skew; validate `nonce` on OIDC authentication flows. An `id_token` is
not an API credential.
*Why: every item on this list is a published, exploited vulnerability class, and partial validation
is the norm rather than the exception. [OIDC Core][OAuth 2.1]*

## Service-to-service and delegated authority

**I7 — Service-to-service traffic is mutually authenticated, and authorized on identity.** mTLS or an
equivalent, with the peer's verified identity — not its IP, not its network position, not its
namespace — as the authorization input. Network reachability is not permission; `platform-security.md`
`P5` (default-deny) and this rule are two halves of one control.
*Why: internal networks are not trusted networks, and a compromised workload's first move is to talk
to its neighbours. [SPIFFE][800-53 SC-8]*

**I8 — Agent authority is delegated, narrowed, time-bound, and revocable.** When an agent acts for a
user or another service, it receives a *narrowed* credential for that specific action — via token
exchange (RFC 8693) or equivalent — never the principal's own token and never a standing credential
carrying more authority than the task. The agent's effective permissions are the intersection of its
own identity (`ai-security.md` `AI6`) and the delegated scope, and the delegation expires with the
task. Every delegated action is attributable to both the agent and the principal it acted for.
*Why: an agent holding a user's unrestricted token *is* that user for every purpose, including for
every subsequent hijack, and nothing downstream can tell the difference. [ASI03][RFC 8693]*

`<PLACEHOLDER: the org's identity provider and the groups/claims that map to administrative access>`
`<PLACEHOLDER: the secrets backend and how workload credentials are issued — Vault, ESO, cloud
workload identity, SPIRE>`
`<PLACEHOLDER: rotation intervals per credential class, and who owns each>`

## Recording a judgment call

Irreducible judgment calls — a static credential an external integration forces on you, an
administrative account that cannot yet take a hardware key, a broadened token scope — go in
`identity-and-access-decision-log.md` beside this file. Append-only: *what / which rule / why /
compensating control / review date*. A reversal is a new entry. Created on the first call; absence
means no exception has ever been granted.
