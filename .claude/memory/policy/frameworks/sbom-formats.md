# SBOM formats — CycloneDX and SPDX

**Identity:** **CycloneDX** (OWASP) v1.7 current · https://cyclonedx.org/ — **SPDX** (Linux
Foundation) v3.0 current, ISO/IEC 5962:2021 · https://spdx.dev/
**Verified:** 2026-07-25. CycloneDX 1.7 and SPDX 3.0 reported as current specification versions;
confirm the exact minor at the publisher before pinning a schema version in CI.
**Canon citing it:** `supply-chain.md` (C2, C5, C7)

> A software bill of materials is the inventory that makes every other supply-chain control possible:
> you cannot patch, or answer "are we affected?", for components you cannot enumerate. Two formats
> dominate, both are ISO-recognised, and the argument between them matters far less than having one.

## The two formats

| | CycloneDX | SPDX |
|---|---|---|
| Steward | OWASP | Linux Foundation |
| Current | v1.7 | v3.0 (ISO/IEC 5962:2021 covers 2.2) |
| Designed for | Security use cases — vulnerability correlation, VEX | License compliance and provenance |
| Encodings | JSON, XML, Protobuf | JSON, YAML, RDF, tag-value, spreadsheet |
| Strength | Compact; first-class vulnerability and VEX support; extends to ML models (ML-BOM) and services | Rich licensing model; deep provenance; long regulatory pedigree |

**They are not rivals in practice.** Most tooling emits both, conversion is routine, and essentially
every regulation or customer requirement that asks for an SBOM accepts either.

### The related artifacts

- **VEX** (Vulnerability Exploitability eXchange) — the statement that a CVE present in your SBOM is
  *not exploitable in your context*. Without VEX, a complete SBOM produces an unmanageable alert
  volume and gets ignored; this is the most common way an SBOM program dies.
- **ML-BOM** — CycloneDX's extension for machine-learning components: models, datasets, and their
  properties. This is the piece that makes SBOM meaningful for an AI platform rather than only its
  surrounding code.

## What we adopt

- **CycloneDX as the emitted format** (canon `C2`), because the primary use here is security
  correlation and because ML-BOM covers model and dataset components. SPDX is accepted on input —
  if a supplier ships SPDX, that is fine.
- **An SBOM per released artifact, generated at build time from the built artifact** — not from the
  source tree, and not reconstructed later. An SBOM assembled by reading the manifest misses what the
  build actually installed.
- **The SBOM is attached and signed, not filed.** It ships as an attestation alongside the artifact
  (`C3`), so the inventory travels with the thing it describes.
- **ML-BOM for model artifacts** (`C7`): models and the datasets that produced them are components,
  and `model-governance.md` already requires the provenance an ML-BOM wants.
- **VEX from the start.** Canon `C5` requires triage of scanner findings, and VEX is the machine-
  readable form of that triage.

## What we leave

- **The format argument.** We pick CycloneDX for concrete reasons and accept SPDX; a project with a
  reason to invert that should record it in the decision log and move on.
- **Full-depth transitive inventory as a gate.** Depth is bounded by what the build tooling can
  actually resolve; we record the depth achieved rather than claim completeness we can't verify.
- **SBOM as a compliance artifact only.** An SBOM nothing consumes is a file. Ours feeds scanning and
  admission checks, or it isn't worth generating.

## How it lands here

| Element | Canon rule | Mechanism |
|---|---|---|
| Generate SBOM per artifact | `C2` | Syft in `templates/security-ci.yml` · `supply-chain-security` |
| Attach + sign the SBOM | `C2`, `C3` | cosign attest in `secure-cicd` |
| Scan against the SBOM | `C5` | Grype / Trivy in `secure-cicd` |
| Triage findings (VEX) | `C5` | `supply-chain-security` · `risk-register.md` |
| ML-BOM for models and datasets | `C7` | `model-governance.md` · `data-governance.md` |

## Gotcha

**An SBOM is a snapshot, and artifacts outlive it.** A container image signed with a clean SBOM in
January is full of CVEs by March without a single byte changing. That is why canon pairs `C2`
(generate it) with `C5` (rebuild base images on CVE) — the inventory is only useful if something
re-reads it on a schedule. An SBOM generated once at release and never revisited answers a question
nobody is still asking.
