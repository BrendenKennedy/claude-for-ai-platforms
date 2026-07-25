---
name: supply-chain-security
description: >
  Proving where artifacts came from and what's inside them — SBOM, signing, provenance, and
  scanning. Carries: Syft for CycloneDX SBOM generation from the built artifact (not the source
  tree), Trivy/Grype scanning with a triage discipline that survives contact with volume, cosign
  keyless signing via Sigstore (Fulcio + Rekor) and the verification step that makes signing
  matter, SLSA build levels and in-toto attestations, digest pinning, base-image rebuild cadence,
  and model/weight provenance including why loading a checkpoint executes code. Load when
  publishing an artifact, adding scanning, wiring signing or attestation, pinning a base image, or
  pulling model weights. Triggers: SBOM, CycloneDX, SPDX, Syft, Trivy, Grype, CVE, vulnerability
  scan, image scanning, cosign, sigstore, sign the image, attestation, provenance, SLSA, in-toto,
  Rekor, supply chain, dependency confusion, typosquatting, pin by digest, weights_only, safetensors,
  model provenance. Pipeline wiring is `secure-cicd`; the musts are `policy/supply-chain.md`.
---

# supply-chain-security — knowing what you shipped, and proving it

**Pinned:** syft, grype, trivy, cosign — unpinned · authored 2026-07 · run `/skill-update
supply-chain-security` once installed. Format/spec versions follow
`policy/frameworks/sbom-formats.md` (CycloneDX 1.7 · SPDX 3.0) and `policy/frameworks/slsa.md` (v1.2).

> On-demand: load this when producing or consuming an artifact. The non-negotiable rules are canon at
> `.claude/memory/policy/supply-chain.md` (`C1`–`C8`). Where these run in the pipeline is
> `secure-cicd`; verification *at admission* is `policy-as-code`; image building is `containers`;
> MCP servers and agent tools are `mcp-security`.

## When this applies

Publishing an artifact. Adding scanning. Wiring signing. Choosing or updating a base image. Pulling
model weights.

## The four input paths

Teams secure the first and forget the rest (`supply-chain.md`):

| Path | Enters via | Control |
|---|---|---|
| Code dependencies | `uv add`, actions, charts | `C1` — lockfile, SHA-pinned actions |
| Container images | base images, sidecars, operators | `C5`, `P4` — digest pinning, rebuild on CVE |
| **Models and data** | weights, adapters, corpora | `C7` — provenance, and loading executes code |
| **Agent tools** | MCP servers, plugins | `C8` — see `mcp-security` |

## SBOM — generate from the artifact, not the source

```bash
syft registry.example.com/api@sha256:3f8a... -o cyclonedx-json > sbom.json
```

**From the built artifact.** An SBOM generated from `pyproject.toml` describes what you asked for;
one generated from the image describes what you got — including everything the base image brought.
Those differ, and the difference is where the CVEs are.

Attach it, don't file it (`C2`) — the inventory must travel with the thing it describes:

```bash
cosign attest --predicate sbom.json --type cyclonedx registry.example.com/api@sha256:3f8a...
```

For models, emit an **ML-BOM** covering the model and the datasets that produced it — the CycloneDX
extension that makes SBOM meaningful for an AI platform rather than only its surrounding code.

## Scanning, and the triage that keeps it useful

```bash
grype registry.example.com/api@sha256:3f8a... --fail-on critical
trivy image --severity HIGH,CRITICAL --ignore-unfixed registry.example.com/api@sha256:3f8a...
trivy config deploy/            # IaC + manifest misconfiguration, not just CVEs
trivy fs --scanners secret .    # secrets in the tree
```

**The failure mode is volume, not detection.** A scan reporting 400 findings with no triage gets
muted, and then a real one is missed. What works:

- **`--ignore-unfixed` by default.** A CVE with no upstream patch is a risk register entry
  (`risk-register.md`), not a build failure — failing on it just teaches people to add exceptions.
- **Fail on Critical, report on High**, with a documented threshold in canon's placeholder.
- **VEX for the rest.** "Present but not exploitable in our context" is a machine-readable statement,
  not a spreadsheet comment. Without VEX an SBOM program dies of noise.
- **Re-scan published artifacts on a schedule.** An image clean at release is not clean in three
  months, and nothing changed. This is the pairing of `C2` with `C5` — the inventory only helps if
  something re-reads it.

## Signing and verification

Keyless via Sigstore — the signing identity is the CI workflow's OIDC identity, so there is **no key
to steal or rotate** (the same principle as `I3`):

```bash
# In CI, with id-token: write permission — no secrets involved
cosign sign --yes registry.example.com/api@sha256:3f8a...

# Verification — this is the control. Signing alone is theatre (C3).
cosign verify registry.example.com/api@sha256:3f8a... \
  --certificate-identity-regexp '^https://github\.com/ORG/REPO/\.github/workflows/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Fulcio issues the short-lived cert, Rekor logs the signing event so a signature can't be quietly
minted. **Verify at admission** (`policy-as-code`'s `verifyImages`) and between pipeline stages — a
signature nothing checks changes nothing.

Pin the identity regex tightly. `--certificate-identity-regexp '.*'` verifies that *somebody* signed
it, which is not the question.

## Provenance — SLSA

Build L2 minimum, L3 for production (`C4`). L2 means the **hosted build platform** generates and
signs the provenance, not your build script — so whoever controls the build definition can't forge
it. On GitHub, artifact attestations get you there without bespoke work:

```yaml
permissions: { id-token: write, attestations: write, contents: read }
steps:
  - uses: actions/attest-build-provenance@v2
    with: { subject-name: ${{ env.IMAGE }}, subject-digest: ${{ steps.build.outputs.digest }} }
```

Record the level actually achieved, and how it was verified, in
`memory/process/control-coverage.md` — the level is the attestation, not the intention.

## Base images

```dockerfile
FROM python:3.12-slim@sha256:1a2b...  AS build
# ... build, install into a venv ...
FROM gcr.io/distroless/python3-debian12@sha256:9f8e...
COPY --from=build /venv /venv
USER 10001
```

Digest-pinned (`C5`, `P4`), minimal, non-root, multi-stage so build tooling doesn't ship. **Most CVEs
in a container come from the base image, not your code** — so rebuilding on a base update is the
highest-yield patching you do, and it needs to be a scheduled job rather than a reaction.

## Models and weights (`C7`)

A checkpoint is a program. Deserialising it runs that program.

- **`weights_only=True`** on `torch.load`, always, for anything downloaded. Never
  `weights_only=False` on a file you didn't produce.
- **Prefer `safetensors`** — the format exists precisely because pickle-based checkpoints execute
  arbitrary code on load.
- **Record source, version/revision, license, and hash** in the run manifest (`model-governance.md`
  `M13`, `M14`). Pin to a revision, not a branch: model hubs are mutable.
- **Fine-tuned outputs inherit the base model's license** and its provenance obligations.
- Treat a model hub as an unreviewed dependency source with a friendly UI, because that's what it is.

## Gotchas

- **Scanning the image but not the manifests.** `trivy config` finds the misconfigurations that
  `guard-k8s-manifests.py` and `policy-as-code` also catch — three layers, deliberately.
- **Signing without verifying.** The most common half-implemented control in this whole area.
- **`latest` in a Dockerfile `FROM`.** Your build is not reproducible and your SBOM describes an
  artifact that no longer exists.
- **SBOM at release, never again.** Snapshot, not a subscription — see the re-scan point above.
- **Trusting a lockfile hash to mean "reviewed."** It means "unchanged since I last didn't read it."
  The pin makes changes *visible in a diff*; someone still has to look.
- **Dependency confusion.** A private package name that also exists publicly can resolve to the
  public one. Scope internal packages, and pin the index.
