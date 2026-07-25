# OAuth 2.1 and OpenID Connect — delegated authorization and federated authentication

**Identity:** IETF OAuth Working Group · **OAuth 2.1 (draft, consolidating RFC 6749 + security BCP
RFC 9700)** · https://oauth.net/2.1/ — OpenID Foundation · **OIDC Core 1.0** ·
https://openid.net/specs/openid-connect-core-1_0.html
**Verified:** 2026-07-25. OAuth 2.1 remains an Internet-Draft consolidating existing RFCs rather
than a new protocol; OIDC Core 1.0 is stable with errata. Treat "OAuth 2.1" as the name for current
best practice, not a new standard to migrate to.
**Canon citing it:** `identity-and-access.md` (I4, I5, I6, I8)

> The protocols underneath almost every "log in with…" and every service-to-service token in a modern
> platform. We carry them because the failure modes are specific, well-documented, and reproduced in
> almost every hand-rolled implementation.

## What OAuth 2.1 consolidates

OAuth 2.1 is a tidying of OAuth 2.0 plus its security BCP into one document. The substantive changes
are all removals and mandates:

| Change | Why |
|---|---|
| **PKCE required for all authorization-code flows** — public and confidential clients alike | Stops authorization-code interception |
| **Implicit grant removed** | Tokens in URL fragments leak through history, referrers, and logs |
| **Resource Owner Password Credentials grant removed** | Requires the client to handle the user's password — defeats the point |
| **Exact string matching for redirect URIs** | Wildcard matching is an open-redirect-to-token-theft pipeline |
| **Bearer tokens forbidden in query strings** | They end up in access logs and referrer headers |
| **Refresh tokens must be sender-constrained or one-time-use** | Limits the value of a stolen refresh token |

**OIDC** sits on top as the authentication layer: an `id_token` (a JWT about *who* the user is)
alongside OAuth's `access_token` (about *what* the bearer may do). Conflating the two is the single
most common OIDC design error — an `id_token` is not an API credential.

## The JWT validation checklist

Canon `I6` requires complete validation, because partial validation is the norm and every omission is
an exploit:

- Verify the **signature** against the issuer's published JWKS, with key rotation handled
- **Reject `alg: none`**, and pin the expected algorithm — do not trust the token's own `alg` header
- Check **`iss`** matches the expected issuer exactly
- Check **`aud`** contains this service — an unvalidated audience means any token from the same IdP
  works on every service
- Check **`exp`** and **`nbf`**, with minimal clock skew
- Validate **`nonce`** for OIDC authentication flows
- Prefer **short lifetimes over revocation lists** — revocation is hard, expiry is free

## What we adopt

- **All of OAuth 2.1's mandates as canon** (`I5`): PKCE always, no implicit, no password grant, exact
  redirect matching, no tokens in query strings.
- **The full JWT validation checklist** (`I6`) — it appears in canon as a checklist precisely because
  a rule saying "validate JWTs properly" is one nobody can be held to.
- **Server-side authorization on every request** (`I4`). A token proves who is calling; it does not
  decide what they may do. This is the rule that survives token compromise.
- **Token exchange (RFC 8693) as the mechanism for agent delegated authority** (`I8`): when an agent
  acts for a user, it gets a *narrowed*, short-lived token for that action — not the user's token,
  and not a standing service credential. This is the concrete answer to OWASP `ASI03`.

## What we leave

- **Legacy grant types**, which we forbid rather than document.
- **Vendor IdP configuration.** `authn-authz` carries the current how-to for the provider in use.
- **DPoP and mTLS-bound tokens as a blanket requirement.** Sender-constrained tokens are the right
  answer for high-value APIs; requiring them everywhere fails on integrations we do not control, so
  canon requires *short-lived and audience-bound* and treats sender-constraining as an escalation.

## How it lands here

| Element | Canon rule | Mechanism |
|---|---|---|
| PKCE, no implicit, exact redirects | `I5` | `authn-authz` |
| JWT validation checklist | `I6` | `authn-authz` · `security-reviewer` (explicit review item) |
| Server-side authorization per request | `I4` | `authn-authz` · `security-reviewer` |
| Short-lived, audience-bound tokens | `I5` | `authn-authz` · `secrets-management` |
| Token exchange for agent delegation | `I8` | `agent-security` · `agent-authority.md` |
| CI → cloud federation (no static keys) | `I3`, `C6` | `secure-cicd` (OIDC federation) |

## Gotcha

**"We use OAuth" says nothing about whether authorization is correct.** OAuth answers *who is
calling*; almost every real-world API authorization bug — IDOR, missing object-level checks, tenant
bleed — lives entirely on the other side of that question, in code the protocol never touches. Canon
`I4` exists because teams routinely treat a valid token as a completed authorization decision.
