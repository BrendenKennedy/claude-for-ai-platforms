# NIST SSDF — Secure Software Development Framework (+ the AI profile)

**Identity:** NIST · SP 800-218 v1.1 (SSDF, February 2022) + **SP 800-218A** (Secure Software
Development Practices for Generative AI and Dual-Use Foundation Models, final **2024-07-26**) ·
https://csrc.nist.gov/pubs/sp/800/218/a/final
**Verified:** 2026-07-25. SP 800-218A publication date and its status as an SSDF Community Profile
augmenting SP 800-218 v1.1 confirmed at NIST CSRC.
**Canon citing it:** `supply-chain.md` (C1, C2, C6, C7) · `model-governance.md` ·
`compliance-crosswalk.md` · shapes `PROCESS.md` P4 and P5 gates

> The practice framework for building software securely, and — via 218A — the only major standards
> body document that says specifically what changes when the thing you are building is an AI model.
> We carry both because 218A is the direct answer to "what does secure development mean for a model,
> not just for code?"

## The four practice groups (SP 800-218 v1.1)

| Group | Name | What it asks |
|---|---|---|
| **PO** | Prepare the Organization | Define security requirements, roles, toolchains, and criteria for software security checks |
| **PS** | Protect the Software | Protect code from unauthorized change, provide a verification mechanism, archive each release |
| **PW** | Produce Well-Secured Software | Design for security, review the design, reuse well-secured components, review code, test, configure secure defaults |
| **RV** | Respond to Vulnerabilities | Identify and confirm vulnerabilities, assess and remediate, and analyse root cause to prevent recurrence |

Practices are cited as `PO.1.1`, `PW.4.1`, `RV.1.3` and so on — these are the IDs that appear in
federal attestation forms and in `compliance-crosswalk.md`.

## What SP 800-218A adds for AI

218A does not replace the SSDF; it overlays AI-specific tasks onto the same practice IDs. The
substance worth carrying:

- **Training data is a supply-chain input.** Its provenance, integrity, and licensing must be tracked
  the way dependency provenance is — poisoning enters through the data path, not the code path.
- **Models are artifacts with provenance requirements.** Where a model came from, what produced it,
  and what it was evaluated against belong in the release record.
- **Model weights need protection from unauthorized modification**, the same PS-group obligation code
  has.
- **AI-specific testing.** Adversarial testing and red-teaming are named development activities, not
  optional extras — this is the standards-body basis for making `/redteam` a phase gate rather than a
  nice-to-have.
- **Dual-use and misuse consideration** during design, which lands in `model-governance.md`'s release
  rules rather than in security canon.

## What we adopt

- **PS and PW as the shape of the P4 (Build & Harden) gate**, RV as the shape of P7's vulnerability
  response, PO as what the policy canon and `settings.json` already are.
- **218A's "training data is supply chain"** → canon `C7` and the corpus-provenance rules in
  `data-governance.md`. This is the cleanest external justification for treating a RAG corpus with
  the seriousness of a dependency.
- **218A's adversarial-testing-as-a-development-practice framing** → the P5 gate requires a recorded
  red-team run (`llm-red-teaming`, `/redteam`).
- **Practice IDs as crosswalk targets**, because they are what an attestation actually asks for.

## What we leave

- **The acquirer-side guidance.** 800-218 addresses software *acquirers* as well as producers; a
  project scaffold is squarely on the producer side.
- **Federal attestation ceremony.** We map to the practice IDs so a team that needs to attest has the
  evidence trail; we do not generate attestation forms or claim conformance.
- **Its organisational-maturity framing.** PO-group practices about org-wide roles and training are
  real, and out of scope for a repo.

## How it lands here

| Practice | Canon rule | Mechanism |
|---|---|---|
| PO.1–PO.5 (requirements, toolchain, criteria) | policy canon itself | `governance` skill · `settings.json` · `secure-cicd` |
| PS.1–PS.3 (protect code, verify integrity, archive) | `C2`, `C3`, `C4` | branch protection · cosign · SBOM per release |
| PW.4 (reuse well-secured components) | `C1`, `C5` | `env-uv` (lockfile) · digest-pinned base images |
| PW.7–PW.8 (review and test) | — (process) | `code-reviewer` · `security-reviewer` · `testing` |
| PW.9 (secure defaults) | `P1`, `AI2` | `templates/k8s/` PSS-restricted · least-agency tool grants |
| RV.1–RV.3 (find, assess, remediate, root-cause) | `C5`, `R8` | Trivy/Grype in `secure-cicd` · `/postmortem` |
| 218A: training-data provenance | `C7` | `data-governance.md` · `supply-chain-security` |
| 218A: model artifact protection | `C7` | `model-governance.md` (checkpoint provenance) |
| 218A: adversarial testing | `AI1`, gate item | `llm-red-teaming` · `/redteam` · P5 exit gate |

## Gotcha

SSDF is a **practice** framework: it tells you to have a process for something, not what the answer
should be. "PW.4.1: reuse existing well-secured software" does not tell you which packages are
well-secured. Pair it with the prescriptive documents — `slsa.md` for build integrity,
`cis-kubernetes.md` for configuration — or you get a compliant process producing insecure software.
