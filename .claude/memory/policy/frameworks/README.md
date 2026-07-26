# `policy/frameworks/` — the framework canon this repo's rules are sourced from

Supporting documentation for the professional-grade security frameworks the policy canon draws on.
This directory is **reference, not rules**: it records what each framework says, which version said
it, and what we took from it. The *musts* live one level up in `policy/<domain>.md`.

> **The division of labour.** Canon asserts a rule and cites the framework control ID that motivates
> it (`[LLM01]`, `[ASI06]`, `[CIS 5.2.5]`). This directory holds the framework text those IDs resolve
> to. Neither restates the other — a canon rule that reproduces a framework's prose belongs here, and
> a framework doc that invents an obligation belongs up there.

This deviates from the earlier convention that "methodology cites lineage; policy asserts rules",
under which canon carried zero external citations — see `memory/process/decision-log.md` for why it
changed. The compromise: canon stays citation-light (IDs only, no URLs, no prose), and everything a
reader would otherwise have to go find lives here.

## Why version numbers matter here more than anywhere else

Security frameworks move. The OWASP agentic list did not exist when this scaffold's first release
shipped; CIS Kubernetes has had multiple releases in a year; NIST SP 800-63 sat in draft for four
years before going final. **A framework doc with no version and no verification date is worse than no doc** — it
reads as current and silently isn't. So every file here carries an `**Identity:**` line and a
`**Verified:**` date, and `/skill-update` treats a stale verification the same way it treats a stale
tool pin.

If a fact cannot be confirmed against the publisher, it is written as `unverified` — never guessed.

## The lineage table

| Framework | Version · date | Publisher | Domain | What we adopt | What we leave |
|---|---|---|---|---|---|
| [OWASP Top 10 for LLM Applications](owasp-llm-top10.md) | v2.0 · 2025 | OWASP GenAI Security Project | AI/LLM app risk | The LLM01–LLM10 risk taxonomy as the vocabulary for model-layer threats | Its tooling recommendations — we pick our own |
| [OWASP Top 10 for Agentic Applications](owasp-agentic-top10.md) | 2026 · ASI01–ASI10 | OWASP GenAI Security Project | Agentic risk | The agent-specific threat set: goal hijack, tool misuse, identity abuse, memory poisoning, rogue agents | Maturity scoring — we gate on the phase gates instead |
| [MITRE ATLAS](mitre-atlas.md) | living · 2026 update | MITRE | AI adversary TTPs | Tactic/technique IDs for naming *how* an attack happens in threat models and red-team plans | The full technique catalogue — we reference, never copy |
| [NIST AI RMF](nist-ai-rmf.md) | AI 100-1 + AI 600-1 | NIST | AI risk management | GOVERN/MAP/MEASURE/MANAGE as the shape of the phase gates | Its org-level program structure — out of scope for a project scaffold |
| [CIS Kubernetes Benchmark](cis-kubernetes.md) | v2.0.1 · Jun 2026 | Center for Internet Security | Cluster config | Node/control-plane/workload config checks, as the target `kube-bench` asserts against | Scored-vs-unscored ceremony; we treat our subset as mandatory |
| [NSA/CISA Kubernetes Hardening Guide](nsa-cisa-k8s-hardening.md) | v1.2 · Aug 2022 | NSA + CISA | Cluster hardening | The hardening narrative: least-privilege pods, network separation, audit logging | Its air-gapped/classified assumptions |
| [NIST SP 800-190](nist-800-190.md) | 2017 | NIST | Container security | The container-risk decomposition (image, registry, orchestrator, host) | Its pre-Kubernetes-era specifics, superseded by CIS/PSS |
| [Kubernetes Pod Security Standards](k8s-pod-security-standards.md) | tracks k8s | Kubernetes project | Workload baseline | `restricted` as the default profile for every workload we generate | `privileged`; `baseline` only with a recorded exception |
| [SLSA](slsa.md) | v1.2 (v1.0 Apr 2023) | OpenSSF | Build provenance | Build levels L1–L3 as the ladder for artifact provenance; in-toto + Sigstore as the mechanism | The Source Track, until it stabilises |
| [NIST SSDF](nist-ssdf.md) | SP 800-218 v1.1 + 800-218A · 2024-07-26 | NIST | Secure SDLC | PO/PS/PW/RV practice groups, plus 218A's AI-model-specific tasks | Its acquirer-side guidance |
| [SBOM formats](sbom-formats.md) | CycloneDX 1.7 · SPDX 3.0 | OWASP · Linux Foundation | Inventory | CycloneDX as the emitted format (+ ML-BOM for models); SPDX accepted on input | Format advocacy — either is acceptable if complete |
| [OWASP Top 10 CI/CD Security Risks](owasp-cicd-top10.md) | 2022 | OWASP | Pipeline risk | CICD-SEC-01…10 as the pipeline threat vocabulary | — |
| [NIST SP 800-63](nist-800-63.md) | Rev. 4 · Jul 2025 | NIST | Digital identity | AAL/IAL/FAL tiers and phishing-resistant MFA as the authentication bar | Federal identity-proofing procedure |
| [OAuth 2.1 / OIDC](oauth-oidc.md) | OAuth 2.1 draft · OIDC Core 1.0 | IETF · OpenID Foundation | Authorization | PKCE-always, no implicit grant, short-lived scoped tokens | Legacy grant types we forbid outright |
| [SPIFFE/SPIRE](spiffe-spire.md) | SPIFFE 1.0 | CNCF | Workload identity | SVIDs as the workload-identity primitive; no long-lived service credentials | Mesh-specific integrations (mesh is parked) |
| [NIST CSF 2.0](nist-csf-2.md) | 2.0 · Feb 2024 | NIST | Control framework | GOVERN/IDENTIFY/PROTECT/DETECT/RESPOND/RECOVER as the crosswalk spine | Tier/profile assessment ceremony |
| [NIST SP 800-53](nist-800-53.md) | Rev. 5 | NIST | Control catalogue | Control IDs as crosswalk targets (AC-, AU-, CM-, IA-, SC-, SI-) | Full baseline tailoring — we map, we don't certify |
| [ISO/IEC 27001 + 42001](iso-27001-42001.md) | 27001:2022 · 42001:2023 | ISO/IEC | Management systems | Annex A / AI-management-system controls as crosswalk targets | Certification process |
| [EU AI Act](eu-ai-act.md) | Reg. (EU) 2024/1689 | European Union | AI regulation | Obligation *awareness* + the timeline that determines when they bite | Legal interpretation — this is not legal advice |
| [Google SRE](google-sre.md) | SRE Book / Workbook | Google | Reliability practice | SLI/SLO/error-budget mechanics, blameless postmortems, toil discipline | Google-scale org structure |

## The format every file here follows

```markdown
# <Framework> — <one line: what it is>

**Identity:** <publisher> · <version> · <publication date> · <canonical URL>
**Verified:** <YYYY-MM-DD> against the publisher.
**Canon citing it:** `<domain>.md` (<rule ids>) · …

> Two sentences: what it is, and why a scaffold for AI platforms carries it.

## The controls          <- the actual IDs, so a citation resolves
| ID | Title | In one line |

## What we adopt         <- concrete, tied to our rules
## What we leave         <- and why; silence here reads as "adopted everything"
## How it lands here     <- framework ID -> canon rule -> enforcing mechanism
| Framework ID | Canon rule | Mechanism (skill · hook · template) |
```

Three rules for authoring one:

1. **Cite the publisher, not a blog.** Secondary sources drift. The `**Identity:**` URL is the
   publisher's own page; if only a secondary source could be reached, say so on the `**Verified:**`
   line.
2. **"What we leave" is not optional.** A framework doc with no exclusions is a claim of total
   compliance, which is never true and is the kind of claim an auditor punishes.
3. **"How it lands here" must name a real mechanism.** A framework control with no canon rule and no
   enforcing skill/hook/template is decoration — either wire it or move it to "what we leave."

## Adding a framework

1. Author the file using the format above.
2. Add a row to the lineage table.
3. Cite its IDs from whichever canon rules it motivates — an unreferenced framework doc is dead
   weight, and `check-scaffold.sh` check 8 fails on citations that don't resolve here.
