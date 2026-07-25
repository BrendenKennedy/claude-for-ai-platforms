---
name: gitops
description: >
  Declarative continuous delivery to Kubernetes with Argo CD or Flux — git as the source of truth
  for what runs, and reconciliation as the mechanism. Carries: the pull vs push model and why the
  cluster no longer needs to hand CI credentials, repository structure (app repo vs config repo,
  and why they separate), environment promotion by digest, sync policy and self-heal, drift
  detection, secrets in a GitOps repo, progressive delivery with automatic rollback on SLO burn, and
  the rollback that makes `reliability.md` R3 real. Load when setting up continuous delivery,
  structuring a config repo, promoting between environments, wiring rollback, or debugging a sync
  that won't converge. Triggers: gitops, Argo CD, ArgoCD, Flux, continuous delivery, deploy to
  kubernetes, sync, reconciliation, drift detection, environment promotion, promote to prod, canary,
  blue green, progressive delivery, rollback a deploy, app of apps, kustomize overlay per
  environment. Cluster mechanics are `kubernetes`; pipeline hardening is `secure-cicd`.
---

# gitops — the cluster converges on git, instead of CI pushing at it

**Pinned:** argocd / flux — unpinned · authored 2026-07 · run `/skill-update gitops` once one is
chosen and installed.

> On-demand: load this when delivery to a cluster is the question. Manifest content is `kubernetes`;
> pipeline hardening and the gates before delivery are `secure-cicd`; secret handling in a config
> repo is `secrets-management`; the rules on reversible change are canon (`reliability.md` `R3`).

## When this applies

Setting up delivery. Structuring a config repo. Promoting between environments. Wiring rollback.
Debugging a sync that won't converge.

## Pull beats push, and the reason is credentials

| | Push (CI runs `kubectl apply`) | Pull (GitOps) |
|---|---|---|
| Credentials | **CI holds cluster admin** | Controller runs *in* the cluster; CI never gets a kubeconfig |
| Drift | Undetected until the next deploy | Detected continuously, optionally auto-reverted |
| What's running | Whatever the last apply did | Whatever git says — always |
| Rollback | Re-run an old pipeline | `git revert` |

**The credential argument is the security one.** In the push model, CI — already the most
over-privileged identity (`supply-chain.md` `C6`) — also holds cluster admin, and every fork PR is
one PPE bug away from it. In the pull model that credential doesn't exist.

## Repository structure

**Separate the app repo from the config repo.** The app repo holds source and builds images; the
config repo holds manifests and is what the cluster watches. Separation means a config change doesn't
rebuild, a rollback doesn't revert code, and the two have different reviewers.

```
config-repo/
  apps/inference-api/
    base/                  deployment.yaml service.yaml networkpolicy.yaml kustomization.yaml
    overlays/
      dev/    kustomization.yaml   # images: newTag/newName -> dev digest
      staging/kustomization.yaml
      prod/   kustomization.yaml   # prod digest, replicas, PDB
```

## Promotion is a digest moving between overlays

```yaml
# overlays/prod/kustomization.yaml
images:
  - name: registry.example.com/inference-api
    digest: sha256:3f8a...c21          # P4 — the exact artifact staging validated
```

Promotion = a PR changing that digest. Reviewable, revertible, and it guarantees **the identical
artifact** moves forward — not a rebuild that happens to have the same tag. Pair with signature
verification at admission (`policy-as-code`) so an unpromoted image can't run even if the manifest
says so.

## Argo CD sync policy

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: inference-api-prod, namespace: argocd }
spec:
  project: platform
  source:
    repoURL: https://github.com/ORG/config-repo.git
    targetRevision: main                    # a branch or tag — never HEAD of anything mutable-ish
    path: apps/inference-api/overlays/prod
  destination: { server: https://kubernetes.default.svc, namespace: platform }
  syncPolicy:
    automated:
      prune: true                           # remove what git no longer declares
      selfHeal: true                        # revert manual cluster edits
    syncOptions: [CreateNamespace=false]     # namespaces carry PSS labels — declare them explicitly
```

- **`selfHeal: true` is the drift control.** A `kubectl edit` in production gets reverted within
  minutes, which is what makes "git is the source of truth" a fact rather than a slogan.
- **`prune: true` is right and sharp.** Deleting a manifest deletes the resource. Combine with
  `prevent-deletion` annotations on stateful resources.
- **Auto-sync dev and staging; consider manual sync for prod** so promotion is a deliberate click as
  well as a merge — or auto-sync prod and rely on the PR as the gate. Pick one; the failure is having
  neither.
- **`CreateNamespace=false`.** An auto-created namespace has no Pod Security labels (`P1`) and no
  default-deny NetworkPolicy (`P5`) — declare namespaces as manifests so they carry both.

## Secrets in a config repo

Everything is in git, and secrets can't be (`P7`). Options, in order — the detail is
`secrets-management`:

1. **External Secrets Operator** — commit an `ExternalSecret` (a pointer, not a value). Preferred.
2. **Sealed Secrets** — encrypted to the cluster's key; only that cluster decrypts.
3. **SOPS** — encrypted values in git; Flux supports decryption natively, Argo via a plugin.

## Progressive delivery and rollback

`reliability.md` `R3` — reversible by mechanism, and exercised.

- **Rollback = `git revert` + sync.** That's the whole procedure, and it's why GitOps makes `R3`
  achievable rather than aspirational. Practise it before you need it.
- **Argo Rollouts / Flagger** for canary or blue-green, with analysis driven by the SLIs from
  `observability` — **automatic rollback on SLO burn** is the pairing that turns a bad deploy into a
  five-minute blip.
- Health checks: Argo waits for resources to report healthy before marking a sync successful, which
  depends on the readiness probes in `kubernetes` being honest.

## Debugging a sync that won't converge

| Symptom | Usual cause |
|---|---|
| Stuck `Progressing` | Pods not becoming Ready — it's a workload problem; go to `kubernetes`'s ladder |
| `OutOfSync` immediately after sync | A mutating admission webhook or controller is changing the resource. Add `ignoreDifferences` for the field it owns |
| Perpetual diff on a field you don't set | A defaulted field; same fix |
| `ComparisonError` | Bad manifest, unreachable repo, or missing CRD |
| Synced but old code running | The digest didn't change — check the overlay actually got the new one |
| Reverts a change you made | `selfHeal` working correctly. Change git |

## Gotchas

- **`kubectl edit` in production.** Reverted by `selfHeal`, or — worse, without it — invisible and
  lost at the next sync. This is the habit GitOps exists to end.
- **`targetRevision: HEAD`** on a busy branch: the cluster follows every merge, including the one
  that wasn't ready.
- **Prune on, `prevent-deletion` off**, then a refactor removes a PVC manifest and the data with it.
- **One repo, one Application, everything.** A blast radius covering every app; split by app or team.
- **Auto-created namespaces** — covered above; it silently drops your two most important defaults.
- **The config repo unprotected.** It is now the production control plane: branch protection, required
  review, and signed commits belong on it more than on the app repo.
