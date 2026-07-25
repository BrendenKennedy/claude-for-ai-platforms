---
name: secrets-management
description: >
  Getting credentials to workloads without them landing in git, an image, or a log. Carries: the
  preference ladder (no secret at all via workload identity, then a secret manager, then an
  encrypted-in-git fallback), External Secrets Operator and the CSI Secrets Store driver, Vault and
  cloud secret managers, SOPS/age and sealed-secrets for GitOps repos, why a Kubernetes Secret is
  base64 not encryption, mounting as files rather than env vars, rotation that has actually been
  exercised, and the response to an exposed credential. Load when a workload needs a credential,
  wiring a secret backend, putting secrets in a GitOps repo, or responding to a leak. Triggers:
  secrets management, Vault, External Secrets Operator, ESO, SOPS, sealed secrets, CSI secrets
  store, AWS Secrets Manager, kubernetes secret, secret rotation, credential rotation, leaked
  credential, secret in git, encrypt secrets, .env in production, service account key. Protocols
  and token validation are `authn-authz`; the musts are `policy/identity-and-access.md` and
  `policy/security.md`.
---

# secrets-management — the best secret is the one that doesn't exist

**Pinned:** external-secrets, vault, sops, kubectl — unpinned · authored 2026-07 · run
`/skill-update secrets-management` once a backend is chosen.

> On-demand: load this when a credential has to reach a workload. The non-negotiable rules are canon:
> `identity-and-access.md` (`I3`, `I9`) and `security.md` (`S2`–`S5`), plus `platform-security.md`
> `P7`. Token *validation* is `authn-authz`; how the pipeline authenticates is `secure-cicd`.

## When this applies

A workload needs a credential. Choosing a backend. Putting secrets near a GitOps repo. Rotating.
Responding to a leak.

## The ladder — work down it, don't start at the bottom

| # | Approach | Use when |
|---|---|---|
| **1** | **No secret at all** — workload identity | Reaching a cloud API, another internal service, or a registry. IRSA / GKE Workload Identity / SPIFFE SVIDs / projected SA tokens / CI OIDC federation |
| **2** | **Secret manager, fetched at runtime** | A genuine external credential (third-party API key, DB password). ESO, CSI driver, Vault Agent |
| **3** | **Encrypted in git** | GitOps repos with no manager available. SOPS/age or sealed-secrets |
| **4** | Plaintext in a manifest or repo | **Never** (`P7`) |

**Most "secrets management" problems are actually identity problems.** Before choosing a vault, ask
whether the credential needs to exist at all — a static cloud access key replaced by IRSA is one
fewer secret to store, rotate, audit, and leak. That's `I3`, and it's the highest-leverage move here.

## A Kubernetes Secret is not encrypted

It is **base64-encoded**, which is an encoding, not a control. Anyone with `get secrets` in the
namespace reads it in plaintext, and it sits in etcd. So:

- Turn on **encryption at rest** for secrets in etcd (`P8`) — off by default on self-managed clusters.
- Restrict `get`/`list` on secrets by RBAC; `list` across a namespace is effectively "read them all."
- Prefer an external manager so the Secret object is a short-lived cache rather than the source.

**Mount as files, not environment variables** (`P7`). Env vars appear in `kubectl describe`, in the
pod spec, in crash dumps, in child processes, and in anything that logs its environment. Files can be
`0400`, and they can be updated in place on rotation without a restart.

```yaml
volumeMounts: [{ name: api-creds, mountPath: /etc/creds, readOnly: true }]
volumes:      [{ name: api-creds, secret: { secretName: api-creds, defaultMode: 0400 } }]
```

## External Secrets Operator — the common answer

Syncs from a real manager into Kubernetes Secrets. The credential of record lives in the manager;
the cluster holds a cache. Nothing sensitive is in git.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: api-creds, namespace: platform }
spec:
  refreshInterval: 1h                       # picks up rotation without a redeploy
  secretStoreRef: { name: aws-secrets, kind: SecretStore }
  target: { name: api-creds }
  data:
    - secretKey: provider_api_key
      remoteRef: { key: prod/inference/provider-api-key }
```

The `SecretStore` authenticates with **workload identity** (IRSA / Workload Identity), not a stored
key — otherwise you've just moved the bootstrap secret one level and gained nothing.

**CSI Secrets Store driver** is the alternative: mounts secrets as a tmpfs volume without creating a
Secret object at all. Fewer copies; requires the driver and a CSI-aware pod spec.

## Secrets in a GitOps repo

GitOps wants everything in git, and secrets can't be. Two honest options:

- **SOPS + age/KMS** — encrypt the values, commit the file, decrypt at apply time. The diff still
  shows *which keys* changed, which is useful. Key management is now your problem.
- **Sealed Secrets** — encrypt with the cluster controller's public key; only that cluster can
  decrypt. Simple; the sealed value is cluster-specific, so promotion between environments means
  re-sealing.

Both are option **3** on the ladder. Prefer ESO if a manager exists.

## Rotation (`I9`)

Every credential that can't be short-lived needs a documented owner, an interval, and a procedure
**that has actually been run at least once**. An untested rotation procedure fails during the
incident that requires it — which is the only time you'll need it.

What makes rotation survivable: applications **re-read** credentials rather than caching at startup
(or the file-mount refresh does it for them); support **two valid credentials at once** during
overlap, so rotation isn't an outage; and the rotation is automated, because a manual quarterly task
slips to annual and then stops.

## Responding to an exposed credential

`security.md` `S4` — **rotate first, then clean up.** In order:

1. **Rotate at the provider.** Immediately. Before anything else.
2. **Revoke the old one** explicitly if the provider allows it — issuing a new one doesn't always
   invalidate the old.
3. **Check for use.** Provider access logs, CloudTrail, audit logs — did anyone use it? This
   determines whether you have an incident (`reliability-sre` `R7`) or a near miss.
4. **Then** purge from history, images, and logs.
5. **Record it.** A postmortem if it was used; a decision-log entry either way.

**Deleting the line does nothing.** Git history is immortal, the image layer still has it, and the
log aggregator indexed it.

## Gotchas

- **The bootstrap secret.** Every system needs one credential to get the others; if it's a static key
  in a repo you've secured nothing. Workload identity is what breaks the recursion.
- **`kubectl get secret -o yaml`** prints plaintext into the transcript — `security.md` `S3`, and
  `validate-bash.sh` confirm-gates it.
- **Secrets in CI logs.** Masking is best-effort; a base64'd or JSON-embedded secret defeats it. Don't
  echo, and set `id-token: write` federation instead of storing keys (`C6`).
- **Secrets in container image layers.** A `RUN` that uses a credential leaves it in the layer even
  if a later layer deletes it. Use build secrets mounts.
- **`.env` in production.** `.env` is a development convenience (`S2`). In a cluster it's a file
  someone copied by hand, with no rotation, no audit, and no owner.
- **Rotating the secret but not the sessions.** Tokens minted with the old credential often outlive
  it; check what's still valid.
