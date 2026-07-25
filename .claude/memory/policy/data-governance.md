# Data governance — the canon for datasets, labels, licensing & PII

Authored policy for a computer-vision / data-science project. This file is the **single source of truth**
for how data may enter, live in, and leave this repo. The `governance` skill only points here; the
`datasets` and `data-dvc` skills carry the *how* (splits, label formats, DVC commands) — this file is the
*must*. Canon wins on any conflict.

Rules are named (`D1`, `D2`, …) so a change, a review, or a decision-log entry can cite one. Each carries
a one-line **why**. Where a rule depends on your org or jurisdiction, it's marked `<PLACEHOLDER: …>` —
fill it once, here, and don't restate it elsewhere.

---

## D1 — Every dataset records its source and license before use
Record, in the dataset's provenance manifest (D3), the **origin** (URL / vendor / capture) and the
**exact license** of every dataset and every externally-sourced sample. Do **not** train, fine-tune,
evaluate, or redistribute on data whose license forbids it, or whose license is unknown, without a
**recorded approval** in the decision log (see below).
- Scraped / "found on the internet" images are **not** license-free — treat unknown as **prohibited**
  until cleared.
- Model outputs used as training data (distillation, synthetic labels) inherit the **source model's**
  usage terms — check them too.
- Commercial vs. research-only licenses differ: `<PLACEHOLDER: which use classes this project ships under
  — e.g. internal-research-only, or commercial-product>`.

*Why: license violations are legal and reputational liabilities that a model silently launders into a
product; the constraint must be recorded at ingest, not reconstructed after shipping.*

## D2 — Minimize sensitive imagery; document a lawful basis; honor retention limits
For any data depicting **faces, license plates, medical content, minors, biometric identifiers, or private
locations/documents**:
- **Minimize** — collect only what the task needs; prefer blurring/cropping/aggregation over storing raw
  identifiers; prefer consented or synthetic data where feasible.
- **Document a lawful basis** — record why holding this data is permitted (consent, contract, legitimate
  interest, public dataset with a compliant license) under `<PLACEHOLDER: applicable regime — e.g. GDPR,
  CCPA, HIPAA, institutional IRB>`.
- **Minors & medical** get the strictest handling: `<PLACEHOLDER: org rule — e.g. no minors' faces
  without guardian consent; PHI only in the HIPAA-controlled environment>`.
- Never commit raw sensitive imagery into git; it lives in DVC-tracked, access-controlled storage (D3),
  never in a public template repo.

*Why: sensitive imagery carries legal duties and real harm to real people; the cheapest control is to not
hold what you don't need, and to know your basis for what you do.*

## D3 — Every dataset has a recorded, versioned origin — no mystery data
Every dataset and derived artifact is **tracked with DVC** (see the `data-dvc` skill) so a git commit pins
an exact byte-for-byte version, plus a **provenance manifest** recording: source, license (D1), capture/
download date, version/revision, and any transform applied to get from raw to this artifact.
- No dataset enters a training or eval run without a DVC pointer and a manifest entry — an experiment must
  be reproducible from `git checkout <sha>` + `dvc pull`.
- Reference data by its pinned version, never by a mutable path like `data/latest/`.
- A new dataset revision is a **new version**, not an in-place overwrite — history is append-only.

*Why: irreproducible or untraceable data makes every result built on it unfalsifiable, and makes a later
license or PII problem impossible to scope.*

## D4 — Splits are defined once; the eval set is never touched
Train/val/test splits are defined **one time** with a fixed, recorded seed and respected everywhere (see
the `datasets` skill for mechanics).
- **Never** fit, tune, select features/hyperparameters, or compute **normalization statistics** (mean/std,
  class weights, PCA, quantiles) on validation or test data — stats come from **train only** and are
  applied to val/test.
- When samples share a source (same patient/subject, same video/scene, same camera, near-duplicate frames,
  same time window), split at the **group / subject / temporal** level so no source straddles the boundary.
- The test set is opened for final reporting only; repeated peeking is leakage too. Frozen split
  definitions are versioned with the data (D3).

*Why: any information that crosses from eval into training inflates the metric and produces a model that
looks better than it is — the single most common way a CV result turns out to be a lie.*

## D5 — Labels carry their own provenance and a quality signal
For every annotation set, record **who or what produced it** (in-house annotator, vendor, crowd, a model's
pseudo-labels), the **labeling guideline/version** used, and a **quality signal**:
- inter-annotator **agreement** (e.g. Cohen's/Fleiss' κ, mask IoU) on a reviewed subset, or the
  audit/adjudication process for single-annotated data;
- known **label noise** or class-definition ambiguities, noted so downstream doesn't trust them blindly.
- **Model-generated / pseudo-labels are marked as such** and never silently mixed with gold labels; their
  license also flows from the source model (D1).
- Relabeling produces a **new labeled version** (D3), never an in-place edit.

*Why: a model can only be as trustworthy as its labels; unknown annotator, guideline, or agreement means
you can't tell model error from label error.*

## D6 — Retention and deletion are bounded and enforceable
Hold data only as long as the recorded lawful basis (D2) and project need justify.
- Define a **retention window** per sensitive dataset: `<PLACEHOLDER: org retention schedule — e.g. raw
  faces deleted N months after model acceptance>`.
- Support **deletion / subject-access requests**: because DVC pins bytes to commits, a true delete means
  purging the blob from the DVC remote **and** rewriting/retiring the pointer — plan for it, don't assume
  git makes data immortal. `<PLACEHOLDER: org deletion procedure + who approves>`.
- On deletion, record what was removed and why (append-only) so the *absence* is itself auditable.

*Why: "keep everything forever" converts a one-time collection into an unbounded, growing liability, and
some regimes make deletion a legal obligation, not a courtesy.*

## D7 — A retrieval corpus is a governed dataset, and an attack surface
Anything ingested into a vector store, knowledge base, or agent memory is a dataset under D1–D6 — source,
license, PII treatment, provenance, and retention all apply — **plus** the integrity requirements that
come from it being reachable by a model at inference time.
- **Record the source of every ingested document**, at the granularity you would need to remove it. "We
  indexed the wiki" is not provenance; a per-document source, ingest date, and content hash is.
- **Never ingest from a user-writable location without review.** A corpus fed by uploads, tickets, or
  scraped pages is a corpus an attacker can write to (`ai-security.md` `AI4`).
- **Scope retrieval by tenant and enforce the scope at query time**, in the retrieval filter — never by
  instructing the model to ignore documents it can see. Embeddings leak: a store that returns another
  tenant's chunk has already breached, whatever the model does with it.
- **Deletion must reach the derived artifacts.** Removing a source document does not remove its
  embeddings, its cached chunks, or its presence in agent memory — D6's deletion procedure covers all of
  them or it does not work.
- **Retention applies to memory too.** Durable agent memory holds user content by definition; give it a
  bounded lifetime.

*Why: retrieval corpora are assembled quickly, from sources nobody licensed, and then quietly become the
highest-privilege input to the model — a poisoned or over-scoped corpus defeats every prompt-level
control, and a corpus with no per-document provenance cannot be cleaned once it is wrong.*

---

## Recording a judgment call
When a real case forces an irreducible decision — clearing an ambiguous license, accepting a dataset with
minor PII risk, permitting a group-split exception — append one entry to
**`data-governance-decision-log.md`** (beside this file): **what** was decided, **which rule** (D#) it
bears on, and **why**. The log is append-only and never edits a past entry (a reversal is a new entry).
Canon states the rule; the log records the judgment — keep them separate.
