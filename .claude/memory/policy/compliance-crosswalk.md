# Compliance crosswalk — this repo's rules mapped to external frameworks

**This is reference, not canon.** It asserts no obligations of its own and has no decision log —
every rule it references is stated and justified in its own canon file. It exists so that a team
facing a questionnaire, an audit, or a customer security review can answer *"which of your controls
covers this?"* without re-deriving the mapping each time.

> ⚠️ **A mapping is not an implementation, and an implementation is not a certification.** A row
> saying `I2 → 800-53 IA-2` means "our rule I2 lives in the neighbourhood of IA-2," not "we satisfy
> IA-2." What is *actually implemented*, with evidence, lives in
> `memory/process/control-coverage.md` — that file is the honest one, and it is the one to answer a
> questionnaire from. This file is the index.

## How the mapping works

**NIST CSF 2.0 is the spine.** SP 800-53, ISO 27001 Annex A, SOC 2 Trust Services Criteria, and most
vendor questionnaires already publish CSF mappings, so mapping our rules to CSF once gives the rest
transitively. That keeps one authored column and several derived ones, instead of six authored
columns that drift apart. Framework details: `frameworks/nist-csf-2.md`.

Canon rule prefixes: `S` security (dev loop) · `AI` ai-security · `P` platform-security ·
`I` identity-and-access · `C` supply-chain · `R` reliability · `D` data-governance ·
`M` model-governance.

## AI and agent security

| Rule | CSF 2.0 | SP 800-53 | ISO 27001:2022 | SOC 2 | AI-specific |
|---|---|---|---|---|---|
| `AI1` untrusted content is data | PR.DS, PR.PS | SI-10 | A.8.26, A.8.28 | CC6.6 | LLM01, ASI01; AI RMF MAP/MANAGE |
| `AI2` least agency | PR.AA-05 | AC-6 | A.8.2, A.8.3 | CC6.3 | LLM06, ASI02; 42001 lifecycle |
| `AI3` human approval for irreversible | GV.RR, PR.AA | AC-3, CM-5 | A.5.15 | CC6.3, CC8.1 | ASI09; AI Act Art. 14 (human oversight) |
| `AI4` corpora + memory are attack surface | PR.DS-01, ID.RA | SI-7, SC-28 | A.8.10, A.8.24 | CC6.1 | LLM04, LLM08, ASI06; SSDF 800-218A |
| `AI5` output is untrusted input | PR.PS-06 | SI-10, SI-15 | A.8.26, A.8.28 | CC6.6 | LLM05, ASI05 |
| `AI6` per-agent scoped identity | PR.AA-01, PR.AA-05 | AC-2, IA-2, IA-9 | A.5.16, A.8.2 | CC6.1, CC6.2 | ASI03 |
| `AI7` inter-agent messages carry no authority | PR.AA-05, PR.DS-02 | AC-4, SC-8 | A.8.20, A.8.22 | CC6.7 | ASI07, ASI08 |
| `AI8` model + prompt provenance | ID.AM-08, GV.SC | CM-8, SA-10 | A.5.19, A.8.9 | CC8.1 | LLM03, ASI04; 42001; AI Act Art. 11–12 |
| `AI9` bounded blast radius | PR.IR-04, DE.CM | SC-5, SC-6 | A.8.6 | A1.1 | LLM10, ASI08 |
| `AI10` system prompt is not a secret store | PR.DS-01 | IA-5, SC-28 | A.5.17, A.8.24 | CC6.1 | LLM07 |
| `AI11` sensitive output filtered at boundary | PR.DS-01, PR.DS-02 | SI-15, SC-28 | A.8.12 | CC6.7 | LLM02; AI Act Art. 13 |
| `AI12` reconstructable agent behaviour | DE.CM-09, DE.AE | AU-2, AU-3, AU-12 | A.8.15, A.8.16 | CC7.2 | ASI10; AI Act Art. 12 (record-keeping) |

## Platform security

| Rule | CSF 2.0 | SP 800-53 | ISO 27001:2022 | SOC 2 | Prescriptive source |
|---|---|---|---|---|---|
| `P1` PSS `restricted` | PR.PS-01 | CM-6, CM-7 | A.8.9 | CC6.6, CC8.1 | PSS; CIS K8s §5.2 |
| `P2` no host namespace/filesystem | PR.PS-01, PR.IR-01 | CM-7, SC-39 | A.8.9, A.8.22 | CC6.6 | PSS; SP 800-190 |
| `P3` resource requests + limits | PR.IR-04 | SC-5, SC-6 | A.8.6 | A1.1 | CIS K8s §5 |
| `P4` images pinned by digest | ID.AM-08, GV.SC-06 | CM-8, SA-12 | A.5.19, A.8.9 | CC8.1 | SP 800-190; CIS K8s §5 |
| `P5` default-deny network | PR.IR-01 | AC-4, SC-7 | A.8.20, A.8.22 | CC6.6 | NSA/CISA; CIS K8s §5.3 |
| `P6` least-privilege RBAC, no wildcards | PR.AA-05 | AC-2, AC-6 | A.8.2, A.8.3 | CC6.1, CC6.3 | CIS K8s §5.1; NSA/CISA |
| `P7` no plaintext secrets in manifests | PR.DS-01 | IA-5, SC-28 | A.5.17, A.8.24 | CC6.1 | CIS K8s §5.4 |
| `P8` control plane + etcd hardened, encrypted | PR.DS-01, PR.PS-01 | SC-8, SC-28 | A.8.24 | CC6.6, CC6.7 | CIS K8s §1–3; NSA/CISA |
| `P9` audit logging shipped off-cluster | DE.CM-09, PR.PS-04 | AU-4, AU-9, AU-6 | A.8.15, A.8.16 | CC7.2, CC7.3 | NSA/CISA; CIS K8s §3.2 |
| `P10` enforced tenancy boundaries | PR.IR-01, PR.AA-05 | AC-4, SC-2, SC-7 | A.8.22, A.8.31 | CC6.1, CC6.6 | SP 800-190; NSA/CISA |
| `P11` data stores not internet-reachable, not default-credentialed | PR.IR-01, PR.AA-03 | SC-7, AC-3, IA-5 | A.8.20, A.8.5 | CC6.1, CC6.6 | CIS K8s §5.3; NSA/CISA |

## Identity and access

| Rule | CSF 2.0 | SP 800-53 | ISO 27001:2022 | SOC 2 | Prescriptive source |
|---|---|---|---|---|---|
| `I1` unique attributable identities | PR.AA-01 | AC-2, IA-2 | A.5.16 | CC6.1, CC6.2 | 800-63 |
| `I2` MFA; phishing-resistant for admin | PR.AA-03 | IA-2(1), IA-2(2) | A.8.5 | CC6.1 | 800-63B AAL2/AAL3 |
| `I3` short-lived platform-issued workload creds | PR.AA-01, PR.AA-05 | IA-5, IA-9 | A.5.17 | CC6.1 | SPIFFE; CICD-SEC-6 |
| `I4` server-side authz per request, per object | PR.AA-05 | AC-3, AC-6 | A.5.15, A.8.3 | CC6.3 | OWASP |
| `I5` scoped, short-lived, audience-bound tokens | PR.AA-05 | AC-3, IA-5 | A.5.17, A.8.5 | CC6.1, CC6.3 | OAuth 2.1; RFC 9700 |
| `I6` complete JWT validation | PR.AA-03, PR.DS-02 | IA-5, SI-10 | A.8.5, A.8.26 | CC6.1 | OIDC Core; OAuth 2.1 |
| `I7` mutually authenticated service traffic | PR.DS-02, PR.AA-05 | SC-8, SC-23 | A.8.20, A.8.21 | CC6.7 | SPIFFE |
| `I8` delegated agent authority, narrowed | PR.AA-05 | AC-3, AC-6 | A.5.15, A.8.2 | CC6.3 | ASI03; RFC 8693 |
| `I9` credential rotation, scheduled + on exposure | PR.AA-01 | IA-5 | A.5.17 | CC6.1 | 800-53 IA-5 |

## Supply chain

| Rule | CSF 2.0 | SP 800-53 | ISO 27001:2022 | SOC 2 | Prescriptive source |
|---|---|---|---|---|---|
| `C1` lockfile-pinned dependencies | GV.SC-06, ID.AM-08 | CM-8, SA-12 | A.5.19, A.8.9 | CC8.1 | SSDF PW.4; CICD-SEC-3/8 |
| `C2` SBOM per artifact | ID.AM-08, GV.SC | CM-8, SA-12 | A.5.19, A.8.9 | CC8.1 | CycloneDX; SSDF |
| `C3` sign what we ship, verify what we run | PR.DS-01, GV.SC-06 | SI-7, SA-12 | A.8.9, A.8.24 | CC8.1 | SLSA; CICD-SEC-9 |
| `C4` SLSA Build L2 min / L3 prod | GV.SC-06 | SA-10, SA-12 | A.8.25, A.8.30 | CC8.1 | SLSA |
| `C5` base images pinned, rebuilt on CVE | ID.RA-01, PR.PS-02 | RA-5, SI-2 | A.8.8 | CC7.1 | SP 800-190; SSDF RV |
| `C6` the pipeline is a production system | PR.AA-05, PR.PS-01 | AC-6, CM-5, SA-15 | A.8.31, A.8.32 | CC6.3, CC8.1 | CICD-SEC-4/5/6 |
| `C7` model + dataset provenance; loading executes code | GV.SC, ID.AM-08 | SA-12, SI-7 | A.5.19, A.8.9 | CC8.1 | SSDF 800-218A; LLM03 |
| `C8` MCP servers + agent tools pinned and reviewed | GV.SC-06 | SA-9, SA-12 | A.5.19, A.5.21 | CC8.1 | ASI04 |

## Reliability

| Rule | CSF 2.0 | SP 800-53 | ISO 27001:2022 | SOC 2 | Prescriptive source |
|---|---|---|---|---|---|
| `R1` SLIs and SLOs defined | ID.AM, DE.CM | CP-2, SI-4 | A.5.30, A.8.16 | A1.1 | SRE |
| `R2` error budget governs velocity | GV.RR, GV.OC | CP-2 | A.5.30 | A1.1 | SRE |
| `R3` reversible change, exercised | PR.PS-01 | CM-3, CM-4, CP-10 | A.8.32 | CC8.1, A1.2 | SRE; CSF RC |
| `R4` timeouts, bounded retries, breakers | PR.IR-04 | SC-5 | A.8.6 | A1.1 | SRE; ASI08 |
| `R5` degrade, don't collapse | PR.IR-03, RC.RP | CP-2, SC-5 | A.5.30 | A1.2 | SRE |
| `R6` runbook per alert | DE.AE, RS.MA | IR-4, SI-4 | A.5.26, A.8.16 | CC7.2, CC7.4 | SRE |
| `R7` incident command + written timeline | RS.MA-01, RS.CO | IR-4, IR-5, IR-6 | A.5.24, A.5.25, A.5.26 | CC7.4 | SRE; CSF RS |
| `R8` blameless postmortem, tracked actions | RC.RP, RS.AN | IR-4(1), IR-8 | A.5.27 | CC7.5 | SRE; CSF RC |

## Development-loop security, data, and model governance

| Rule | CSF 2.0 | SP 800-53 | ISO 27001:2022 | SOC 2 |
|---|---|---|---|---|
| `S1`–`S9` (threat model, secrets, egress, agent identity, dev supply chain) | PR.AA, PR.DS, GV.SC | AC-6, IA-5, SC-28, SA-12 | A.5.17, A.8.12, A.8.24 | CC6.1, CC6.7 |
| `S10` (vendor-managed appliance host: no unsanctioned system-package mutation) | PR.PS-01, PR.PS-02, ID.AM-02 | CM-2, CM-5, CM-7, SI-2 | A.8.9, A.8.19, A.8.32 | CC7.1, CC8.1 |
| `D1`–`D6` (licensing, PII, provenance, splits, retention) | GV.OC, ID.AM-07, PR.DS | PT-2, PT-3, SI-12, RA-3 | A.5.34, A.8.10, A.8.11 | P-series (Privacy) |
| `D7` (retrieval corpus governance + integrity) | PR.DS-01, ID.AM-07 | SI-7, SC-28, PT-2 | A.8.10, A.8.11 | CC6.1, P-series |
| `D8` (store-level tenancy enforced by the query) | PR.AA-05, PR.DS-01 | AC-3, AC-4, SC-2 | A.5.15, A.8.3 | CC6.1, CC6.3 |
| `D9` (encryption at rest and in transit, incl. derivatives) | PR.DS-01, PR.DS-02 | SC-8, SC-28 | A.8.24 | CC6.7 |
| `D10` (tested restore; deletion reaches derived artifacts) | RC.RP, PR.DS-11 | CP-9, CP-10, SI-12, PT-2 | A.8.13, A.8.10 | A1.2, P-series |
| `M1`–`M13` (reproducibility, provenance, eval, model cards) | GV.SC, ID.AM-08 | CM-8, SA-10, SI-7 | A.8.9, A.8.25 | CC8.1 |
| `M14`–`M16` (third-party models, prompt versioning, trajectory eval) | GV.SC-06, ID.AM-08 | CM-8, SA-9, SA-11 | A.5.19, A.5.21, A.8.29 | CC8.1 |

## AI-specific regulation and standards

| Obligation | Where our evidence lives |
|---|---|
| ISO/IEC 42001 — AI policy, roles, lifecycle | `memory/policy/` canon + `governance` skill + `PROCESS.md` gates |
| ISO/IEC 42001 — AI impact assessment | `PROCESS.md` P1 + `model-governance.md` (model cards, disparity reporting) |
| EU AI Act Art. 9 — risk management | `memory/process/risk-register.md` · `/threat-model` |
| EU AI Act Art. 10 — data governance | `data-governance.md` |
| EU AI Act Art. 11–12 — technical documentation, record-keeping | `model-governance.md` (model cards) · tracker runs · `AI12` |
| EU AI Act Art. 13 — transparency | `AI11` · `guardrails` · `serving` |
| EU AI Act Art. 14 — human oversight | `AI3` · `memory/process/agent-authority.md` |
| EU AI Act Art. 15 — accuracy, robustness, cybersecurity | `agent-evaluation` · `llm-red-teaming` · all security canon |
| EU AI Act Art. 17 — quality management | `PROCESS.md` + `/gate` |

**On the EU AI Act specifically:** classification is a legal determination this repo cannot make, and
the timeline has already moved once. See `frameworks/eu-ai-act.md`, and involve counsel rather than
this table.

## Using this file

- **Answering a questionnaire?** Start from `memory/process/control-coverage.md` (what is actually
  implemented, with evidence) and use this file to find which of our rules a question maps to.
- **Finding gaps?** `/compliance` runs the `compliance-mapper` agent across this table and
  `control-coverage.md` and reports what is unmapped, unimplemented, or unevidenced.
- **Adding a canon rule?** Add its row here. A rule with no crosswalk row is invisible to every
  external conversation the project will eventually have.
