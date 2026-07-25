# Supply chain policy — dependencies, artifacts, images, models, and tools

The canon for the `supply-chain` domain (registered in the `governance` skill). Universal rules are
concrete; org-specific values are marked `<PLACEHOLDER: …>`. Load this before adding a dependency,
building or publishing an artifact, choosing a base image, pulling model weights, wiring a CI
pipeline, or connecting an MCP server or third-party agent tool.

Rules are named (`C1`, `C2`, …) so a review finding or a decision-log entry can cite one. Each
carries a one-line **why**. Bracketed IDs cite the motivating framework — `[SLSA L2]`,
`[CICD-SEC-4]` — and resolve in `frameworks/`.

Sibling canon: the *development loop's* dependency discipline is `security.md` `S8` (which this
extends to everything we ship); how images run is `platform-security.md`; who the pipeline
authenticates as is `identity-and-access.md` `I3`.

## What "supply chain" means for an AI platform

Four input paths, not one. Every rule below applies across all four, and teams routinely secure only
the first:

| Path | What enters | The specific risk |
|---|---|---|
| **Code dependencies** | Packages, actions, charts | Typosquatting, dependency confusion, compromised maintainer |
| **Container images** | Base images, sidecars, operators | Inherited CVEs, mutable tags, unverified provenance |
| **Models and data** | Weights, adapters, RAG corpora, training data | Poisoning, and weights that execute code on load |
| **Agent tools** | MCP servers, plugins, tool definitions | Tool poisoning, rug pulls, silently-changed descriptions |

The fourth is the one with no mature ecosystem defence, and it is the one an AI platform depends on
most.

## Dependencies

**C1 — Every dependency enters through the lockfile, pinned, reviewed as a diff.** Python deps via
`uv add` (enforced by `guard-pyproject.py`); CI actions pinned by **commit SHA, not tag**; Helm charts
and operators pinned by version and digest; base images by digest (`C5`). No `pip install`
mid-session, no `curl | sh`, no `@latest`, no floating major versions. A dependency added without a
lockfile change did not really get added.
*Why: a mutable reference is an unreviewed dependency with the same access as a reviewed one, and a
tag on a third-party action is write access to your build. [CICD-SEC-3][CICD-SEC-8][SSDF PW.4]*

**C5 — Base images are pinned by digest, minimal, and rebuilt when their CVEs are fixed.** Prefer
distroless or slim bases; run as non-root; multi-stage so build tooling does not ship. Scanning runs
in CI and on a schedule against published artifacts, because an image that was clean at release is
not clean three months later. Findings are triaged, not accumulated — a scanner nobody acts on is
noise that trains people to ignore alerts.
*Why: most CVEs in a container come from the base image, not the application, and they arrive after
the release rather than during it. [SP 800-190][SSDF RV]*

## Artifacts we produce

**C2 — Every artifact we ship has an SBOM, generated at build time from the built artifact.** Not
from the source tree, not reconstructed afterwards — from what the build actually produced.
CycloneDX is the emitted format; SPDX is accepted on input. Model artifacts get an ML-BOM covering
the model and the datasets that produced it. The SBOM is attached to the artifact as an attestation,
not filed somewhere separate.
*Why: you cannot answer "are we affected by this CVE?" for components you cannot enumerate, and an
SBOM that does not travel with the artifact is not there when the question is asked. [CycloneDX][SSDF]*

**C3 — Sign what we ship; verify what we run.** Artifacts are signed with keyless Sigstore signing
(Fulcio-issued, short-lived, from the CI workflow's OIDC identity, logged in Rekor). Verification is
enforced at admission by `policy-as-code`, and between pipeline stages. **Signing without
verification is theatre** — the verification step is the control.
*Why: a signature nothing checks changes nothing, and the admission check is what actually prevents
an unsigned or substituted image from running. [SLSA][CICD-SEC-9]*

**C4 — Build provenance meets SLSA Build L2 minimum; L3 for anything reaching production.**
Provenance is generated and signed by the hosted build platform, not by the build script — so
whoever controls the build definition cannot forge it. The level actually achieved, and how it was
verified, is recorded in `memory/process/control-coverage.md`.
*Why: L1 provenance can be produced by the thing being attested, which makes it a claim rather than
evidence. [SLSA]*

## The pipeline itself

**C6 — The pipeline is a production system, and is treated as one.** Least-privilege, per-job scoped
identity (`identity-and-access.md` `I3`); no long-lived cloud credentials — federate via OIDC;
workflows triggered by untrusted forks receive **no secrets and no elevated identity**; build steps
supplied by the repository do not run with the credentials that publish artifacts; runners are
isolated between jobs; pipeline logs are telemetry and go where telemetry goes.
*Why: CI is usually the most over-privileged identity in the system — it can write to production and
read every secret — and it is the one nobody threat-models. [CICD-SEC-4][CICD-SEC-5][CICD-SEC-6]*

## Models and agent tools

**C7 — Model weights and datasets are artifacts with provenance, and loading them executes code.**
Record the source, version, license, and hash of every model, adapter, and corpus (the detail lives in
`model-governance.md` and `data-governance.md`). `weights_only=True` on `torch.load` unless the
checkpoint is your own and provably needs more; **never `weights_only=False` on a downloaded file**.
Prefer formats that do not unpickle. Fine-tuned outputs inherit the base model's license and its
provenance obligations.
*Why: a checkpoint is a program, deserialising it runs that program, and the model hub is an
unreviewed dependency source with a friendly UI. [LLM03][SSDF 800-218A]*

**C8 — Third-party agent tools and MCP servers are pinned, reviewed, and re-reviewed on change.**
Servers are referenced by pinned version or digest — never `npx -y <pkg>` without a version, never
`@latest`. The **tool descriptions and schemas** are part of the reviewed surface, not just the
version: a server can change what its tools claim to do without changing its version, which is how
tool poisoning and rug pulls work. Adding a server is a human decision (`guard-agent-config.py` asks);
what the tools may then do is bounded by `ai-security.md` `AI2`.
*Why: a tool description is injected directly into an agent's instruction context, so an MCP server
is not merely a dependency — it is a dependency with a prompt-injection channel and your credentials.
[ASI04]*

`<PLACEHOLDER: approved package registries and model hubs, and who approves a new source>`
`<PLACEHOLDER: the artifact registry and attestation store, and the CVE severity threshold that
blocks a release>`

## Recording a judgment call

Irreducible judgment calls — a dependency with no upstream fix, an unsigned vendor image, a model
from an unapproved hub, an MCP server that cannot be pinned — go in `supply-chain-decision-log.md`
beside this file. Append-only: *what / which rule / why / compensating control / review date*. A
reversal is a new entry. Created on the first call; absence means no exception has ever been granted.
