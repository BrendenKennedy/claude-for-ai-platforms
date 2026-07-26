---
name: kubernetes
description: >
  Running workloads on Kubernetes — the manifests, the operational commands, and the hardened
  defaults this scaffold generates. Carries: the Deployment/Service/Ingress shape with a
  PSS-`restricted` securityContext, requests+limits and the QoS classes they buy, the three probes
  and how to get them wrong, ConfigMap/Secret mounting, Kustomize base+overlays, Helm when it earns
  itself, rollout and rollback, HPA and GPU scheduling for inference, and the debugging ladder for
  CrashLoopBackOff / ImagePullBackOff / Pending / OOMKilled. Load when writing or reviewing a
  manifest, deploying, debugging a pod, scaling, or wiring GPU inference. Triggers: kubernetes,
  k8s, kubectl, manifest, deployment, pod, service, ingress, namespace, kustomize, helm, probe,
  liveness, readiness, resource limits, HPA, autoscaling, CrashLoopBackOff, ImagePullBackOff,
  OOMKilled, pod pending, rollout, rollback, node selector, taint, toleration, GPU scheduling.
  Admission policy is `policy-as-code`; images are `containers`; the musts are
  `policy/platform-security.md`.
---

# kubernetes — workloads that are hardened because the default template is

**Pinned:** kubectl, kubernetes — unpinned · authored 2026-07 · run `/skill-update kubernetes` once a
cluster version is known (`kubectl version`); API shapes below target 1.29+ and PSS/CIS pairing
follows `policy/frameworks/cis-kubernetes.md` (v2.0.1 → k8s 1.34/1.35).

> On-demand: load this to write, review, deploy, or debug a workload. The non-negotiable rules are
> canon at `.claude/memory/policy/platform-security.md` (`P1`–`P10`) and win on any conflict. Cluster
> *policy enforcement* is `policy-as-code`; image building is `containers`; secret backends are
> `secrets-management`; delivery is `gitops`; SLOs are `reliability-sre`.
>
> **Note on lineage:** this scaffold deliberately parked Kubernetes through v0.9.0; v1.0.0 un-parked
> it — see `memory/process/decision-log.md`.

## When this applies

Writing or reviewing a manifest. Deploying. Debugging a pod. Scaling. Scheduling GPU inference.

## The hardened Deployment — start from this, always

Everything security-relevant here is required by canon, and `guard-k8s-manifests.py` blocks the diff
that removes it. This is the shape `/bootstrap` generates and `templates/k8s/` ships.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: inference-api, namespace: platform }
spec:
  replicas: 3
  selector: { matchLabels: { app: inference-api } }
  template:
    metadata: { labels: { app: inference-api } }
    spec:
      serviceAccountName: inference-api          # never `default` (P6)
      automountServiceAccountToken: false        # unless it calls the k8s API (P6)
      securityContext:                           # pod level (P1)
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: api
          # digest-pinned, approved registry (P4) — never :latest
          image: registry.example.com/inference-api@sha256:3f8a...c21
          securityContext:                       # container level (P1)
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          resources:                             # both, always (P3)
            requests: { cpu: "500m", memory: "1Gi" }
            limits:   { cpu: "2",    memory: "2Gi" }
          ports: [{ containerPort: 8080, name: http }]
          startupProbe:                          # gates the other two
            httpGet: { path: /healthz, port: http }
            failureThreshold: 30
            periodSeconds: 5
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            periodSeconds: 10
          volumeMounts:
            - { name: tmp, mountPath: /tmp }     # readOnlyRootFilesystem needs writable tmp
      volumes:
        - { name: tmp, emptyDir: {} }
```

The namespace carries the enforcement labels, set at creation (`P1`):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: platform
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit:   restricted
    pod-security.kubernetes.io/warn:    restricted
```

And default-deny networking (`P5`) — the single highest-value manifest in the repo:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all, namespace: platform }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```
Then add narrow allow rules per workload. **DNS egress must be explicitly allowed** or everything
breaks in a way that looks like an application bug — allow UDP/TCP 53 to `kube-system`.

## Resources and QoS

Requests are what the scheduler reserves; limits are what the kernel enforces.

| Class | Condition | Eviction order |
|---|---|---|
| **Guaranteed** | requests == limits, all containers | Last — use for latency-critical inference |
| **Burstable** | requests < limits | Middle — the default for most services |
| **BestEffort** | neither set | **First. Never ship this.** (`P3`) |

**CPU limits throttle; memory limits kill.** Exceeding a CPU limit slows you down (CFS throttling,
which shows up as mysterious p99 latency); exceeding a memory limit is an immediate `OOMKilled`. For
latency-sensitive services, set CPU requests generously and consider omitting the CPU limit while
keeping the memory limit — a deliberate, recorded choice, not an oversight.

## Probes — the three, and the classic mistakes

| Probe | Question | Failure means |
|---|---|---|
| **startup** | Has it finished booting? | Keep waiting; suppresses the other two |
| **readiness** | Can it serve *right now*? | Removed from Service endpoints; **not** restarted |
| **liveness** | Is it wedged beyond recovery? | **Container restarted** |

- **A liveness probe that checks dependencies is an outage amplifier.** If the database is down and
  liveness checks it, every pod restarts, in a loop, forever. Liveness = "is this process wedged?"
  Dependencies belong in readiness.
- **No startup probe on a slow starter** (model loading!) means liveness kills it mid-boot →
  CrashLoopBackOff that looks like a crash. Model servers loading weights need `startupProbe` with a
  generous `failureThreshold`.
- Readiness should fail during shutdown so traffic drains before the process exits; pair with
  `terminationGracePeriodSeconds` and a `preStop` sleep.

## Kustomize — base plus overlays

Preferred over Helm for first-party workloads: no templating language, and the output is real YAML
you can read.

```
deploy/
  base/            kustomization.yaml, deployment.yaml, service.yaml, networkpolicy.yaml, rbac.yaml
  overlays/
    dev/           kustomization.yaml (replicas: 1, dev image tag)
    prod/          kustomization.yaml (replicas: 3, resource bumps, PDB)
```
```bash
kubectl kustomize deploy/overlays/prod          # render and READ it
kubectl apply -k deploy/overlays/prod --dry-run=server   # validate against the real API
```

Use **Helm** for third-party software you didn't write (ingress controllers, operators, Prometheus).
Pin the chart version and digest (`C1`), and `helm template` it into review before installing —
a chart is arbitrary YAML with cluster access.

## Operating

```bash
kubectl rollout status deploy/inference-api -n platform      # watch, don't guess
kubectl rollout undo   deploy/inference-api -n platform      # the R3 mechanism
kubectl rollout history deploy/inference-api -n platform

kubectl get events -n platform --sort-by=.lastTimestamp      # the first debugging command
kubectl describe pod <pod> -n platform                       # the second
kubectl logs <pod> -n platform --previous                    # logs of the crashed instance
kubectl auth whoami                                          # S8 — which identity am I?
kubectl auth can-i --list -n platform                        # what can it actually do?
```

`kubectl delete`, `drain`, and `cordon` are confirm-gated by `validate-bash.sh` — irreversible means
a human clicks (`security.md` `S1`).

## Debugging ladder

| Symptom | Usual cause |
|---|---|
| `ImagePullBackOff` | Wrong digest/tag, missing `imagePullSecret`, registry unreachable — `describe` says which |
| `CrashLoopBackOff` | App exits on boot (`logs --previous`), or **liveness killing a slow starter** (add `startupProbe`) |
| `Pending` | Nothing schedulable: insufficient CPU/memory, no GPU node, unsatisfied taint/affinity, unbound PVC. `describe` gives the scheduler's reason verbatim |
| `OOMKilled` (exit 137) | Memory limit too low, or a leak. Check actual usage before raising blindly |
| `CreateContainerConfigError` | Missing ConfigMap/Secret key |
| Ready but no traffic | Service selector doesn't match pod labels, or readiness failing — `kubectl get endpoints` |
| Intermittent p99 spikes | **CPU throttling** at the limit |
| Connections time out | Default-deny NetworkPolicy with no allow rule (and check DNS) |

## Autoscaling and GPU inference

- **HPA** on a custom metric that reflects load — for LLM serving, queue depth or concurrent requests
  beats CPU, which is a poor proxy for GPU saturation. Set `minReplicas` ≥ 2 for anything with an
  availability SLO.
- **Scale-up is slow** when the image is tens of gigabytes and the model loads at start. Pre-pull
  images, keep warm replicas, and measure cold-start honestly against the latency SLO
  (`reliability-sre` `R1`).
- **GPUs:** request `nvidia.com/gpu` as a resource; GPUs are not shareable by default, so a request of
  1 takes the whole device. Use taints + tolerations to keep non-GPU work off GPU nodes, and a node
  selector to pin to the right accelerator class.
- **PodDisruptionBudget** for anything with an SLO, or a node drain takes the whole service down.

## Gotchas

- **`kubectl apply` on a manifest you didn't render.** With overlays or Helm, always render and read
  first — the diff between what you wrote and what applies is where surprises live.
- **`readOnlyRootFilesystem: true` without a writable `/tmp`.** Half of Python's ecosystem writes
  temp files; mount an `emptyDir`.
- **Secrets as env vars** appear in `describe`, in pod specs, and in crash dumps. Mount as files
  (`P7`).
- **`latest` in a dev overlay.** It propagates, and then prod isn't reproducible (`P4`).
- **Editing live objects with `kubectl edit`.** The change is invisible to git and gone at the next
  apply. Use `gitops`.
- **Assuming a NetworkPolicy is enforced.** It requires a CNI that implements it — with some CNIs the
  object applies cleanly and does nothing. Verify with an actual connection test.
