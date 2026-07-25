---
description: One-time project bootstrap — generate the conf/ tree and the train/eval entry points the skills assume, then back-fill the placeholders that only become answerable once that code exists.
disable-model-invocation: true
---

Create the project skeleton this scaffold's skills already describe — **archetype-aware**:
deep-learning/CV (§3, with anomaly-detection and pipeline variants), tabular (§3e), time-series
(§3f), and LLM fine-tuning (§3g). `/intake` picks the **stack**; this picks the **shape**. Until it
runs, `config-hydra` documents a `conf/` tree that doesn't exist, the lane skills document entry
points that don't exist, and "config over constants" governs nothing.

Run it **after** `/intake`, **once**, on a fresh scaffold. Throughout, `<pkg>` means the project's Python
package under `src/` (read it from `pyproject.toml` — do not invent one).

## 1. Interview (use the **AskUserQuestion** tool)

The skeleton's shape depends on the task; don't guess it. **First read
`.claude/memory/process/project-definition.md`** (written by `/intake` step 0) — its **Setup
implications** section may already answer the questions below; present those as pre-selected
options to confirm, don't re-ask blind. Then ask, batched into one call:

- **Archetype** (from the definition doc — confirm, don't re-derive): **deep-learning / CV**
  *(default)* · **tabular** · **time-series** · **LLM fine-tuning**. This selects the entire
  skeleton: CV/DL → the remaining questions here + §3; tabular → §3e (its own questions:
  target column, optional group column, classification vs regression); time-series → §3f
  (time column, target, horizon + frequency, seasonal period, optional series-id); LLM → §3g
  (base model, data path).
- **Dataset name** (all archetypes) — the short slug used for `conf/dataset/<name>.yaml` and
  `data/<name>/`. This is the value `/intake` had to leave as a `<PLACEHOLDER>` in
  `config-hydra`, `datasets`, and `data-dvc`.
- **CV task** (CV/DL lane only) — image classification *(default)* / object detection / semantic
  segmentation / **anomaly detection** (industrial defect finding) / **a multi-stage pipeline**
  (localize the item, then judge it). This decides the model, the loss, the metric, the label
  format, and — for anomaly detection and pipelines — the entire data and training shape. If the
  answer is a pipeline, **load the `pipelines` skill** and see step 3c.
- **Model/backbone to start from** (CV/DL lane only) — e.g. `resnet18` (torchvision). For anomaly
  detection, ask which **method family** instead (see step 3b) — it changes whether there's a
  training loop at all.

If the user doesn't know the dataset yet, use `example` with `synthetic: true` and say so in the report — a
config group that runs on random tensors beats a placeholder that runs on nothing.

**If you can't ask** (non-interactive run, subagent, CI): don't stall and don't guess silently. Use the
defaults, and state loudly in the report that they were assumed, so the user can correct them before real
work lands on top.

## 2. Load the skills that own each piece — don't improvise

This command is a **sequencer, not a source of truth**. Before writing each file, load the skill that owns
it and follow it; if this command and a skill ever disagree, **the skill wins**:

| Writing… | Load first |
|---|---|
| `conf/` tree, the defaults list, `@hydra.main` | `config-hydra` |
| `train.py` — loop, seeding, checkpointing, AMP, resume | `training` |
| `eval.py` — deterministic eval, metric choice | `evaluation` |
| tracker calls inside both entry points | the tracking skill that `/intake` turned on |
| splits, label format, `SPLIT_SEED` | `datasets` |
| the tabular skeleton (§3e) — pipelines, CV strategy, persistence | `tabular` (+ `wrangling` for frame handling) |
| the time-series skeleton (§3f) — backtest, causal features, baselines | `timeseries` |
| the LLM skeleton (§3g) — SFT shape, decontamination, golden prompts | `finetune-unsloth` + `llm-eval` |
| the tests that prove it works | `testing` |

## 3. Generate the skeleton

The tree below is the **deep-learning/CV shape**; §3e–§3g replace it per archetype. §3a
(structure-not-a-dataset), §3d (delivery templates), and §4–§6 apply to **every** archetype.
Every path below is named in a skill — this is the layout they refer to, so **changing a path here means
updating that skill in the same commit**.

```
conf/
  config.yaml              # defaults list + run-wide values. MUST declare: seed, epochs, experiment,
                           #   run_name, device, ckpt (null), resume (null), tracking.uri
  model/<backbone>.yaml
  optimizer/adamw.yaml     # + sgd.yaml
  scheduler/cosine.yaml    # + step.yaml — a real group, not loose keys in config.yaml
  dataset/<name>.yaml      # data_dir: ${oc.env:DATA_ROOT}/<name>; synthetic: true|false
src/<pkg>/
  env.py                   # load_env() — dotenv, called ONCE at each entry point's top (see below)
  seed.py                  # seed_everything(seed) — RNGs + cuDNN flags. THE one definition of "seeded".
  train.py                 # @hydra.main(config_path="../../conf", config_name="config")
  eval.py                  # own entry point; scores a checkpoint, never a tail of train
  data/
    splits.py              # SPLIT_SEED (fixed, NOT cfg.seed), split manifest read/write
    dataset.py             # torch Dataset + transforms (deterministic preprocess vs. random aug)
  models/
    factory.py             # build_model(cfg) -> nn.Module
models/                    # checkpoint outputs: best.pt, last.pt (data-versioned, not git)
```

Four keys in `config.yaml` are load-bearing and easy to miss:
- **`ckpt: null` AND `resume: null`** — Hydra is struct-mode: overriding a key the config never declared dies
  with `ConfigCompositionException`. Both are required — `ckpt=` by `eval.py` and `resume=` by the resume
  run (step 5). Declaring only `ckpt` is the classic mistake: everything passes until the resume step.
- **`device: cuda`** — the default *assumes* the GPU; entry points fall back to CPU when
  `torch.cuda.is_available()` is False. To force CPU on a GPU box, override `device=cpu`.
- **`tracking.uri: ${oc.env:...}`** — for MLflow this MUST be a database URI; 3.x raises on the old
  `./mlruns` file store. See `tracking-mlflow`.

**Something must actually load `.env`, or every `${oc.env:...}` is a lie.** Hydra's `oc.env` resolver reads
the *process* environment — it does **not** read `.env`. Without an explicit `load_dotenv()`, the config
silently depends on whatever the user happened to export in their shell, and works on one machine and not
the next. Emit `src/<pkg>/env.py` with a `load_env()` that calls `load_dotenv(override=False)` (real env
vars beat the file), and call it at the **top of each entry point** — never mid-logic, and never
`os.environ` from library code (config-over-constants).

**No data yet? Generate against tensors, via config — not a hardcoded branch.** The dataset group gets a
`synthetic: true` flag and `dataset.py` returns a random-tensor `Dataset` of the right shape. This keeps the
"no data" case *inside* the config system, so the same `train.py` runs on day one and on real data later —
flip one flag. It's also what makes step 5 runnable at all.

### 3a. The bootstrap rule about data: STRUCTURE, NOT A DATASET

**This command emits structure and contracts. It must not bake a specific dataset into the code.** The
skeleton outlives any one dataset — the same repo gets pointed at a new client, a new line, a new product
next month. A benchmark hardcoded into `dataset.py` becomes a tax paid forever.

So:
- **Emit a dataset *contract*, not a dataset.** One sample type (e.g. an `ADSample`/`Sample` dataclass) that
  every adapter returns. Everything downstream — the loop, the metrics, the tests — depends on the contract,
  never on a directory tree.
- **Express the layout as a *folder convention* whose names all come from config.** Directory names, file
  extensions, mask suffixes, an optional category level: config keys, not string literals in Python.
  A public benchmark (MVTec-AD, COCO, ImageFolder) is then just *one* `conf/dataset/<name>.yaml` — an
  example of the convention, not a privileged citizen.
- **Ship `conf/dataset/_template.yaml`** — the copy-me file for the next dataset, with the layout keys and
  the leakage rule spelled out. **Onboarding a dataset must cost one YAML file and zero Python.**
- **Only write a new adapter class when the data genuinely isn't folders** (a manifest CSV, a database, one
  big HDF5). That's the one case that should cost code, and it still returns the same contract type.
- **Never download a dataset during bootstrap.** Wire the layout, verify on `synthetic: true`, and leave the
  download to a human — it's slow, often large, and frequently license-encumbered (MVTec-AD, for instance,
  is CC BY-NC-SA: research-only, and a client deliverable is not research). Licensing is `governance`'s call,
  not yours.

If you find yourself writing the string `"train/good"` in a `.py` file, stop: that belongs in a YAML.

### 3b. If the task is anomaly detection, the shape changes — read this before writing code

Do **not** emit the classification skeleton with the labels renamed. Load `datasets` (one-class layout,
normal-only training) and `evaluation` (AUROC/AUPRO, never accuracy) first, then:

- **Data:** the fit set is **normal parts only**; defects appear **only** at test. `dataset.py` must not
  accept a defect into the fit split — assert it, and make it a test (a defect in the fit set silently
  teaches the model that the defect is normal; nothing crashes, the model just stops working).
- **Ask which method family**, because it decides whether `train.py` even has a loop:
  - **Gradient-trained** (autoencoder, student–teacher, normalizing-flow) — the normal `training` loop
    applies, but there is no label `y` and the loss is reconstruction/distillation error.
  - **Fit, not trained** (PaDiM, PatchCore, memory-bank/embedding methods) — **no backward pass at all**:
    run a frozen backbone over the normal set and store features. Do NOT fabricate an optimizer, scheduler,
    AMP, or an epoch loop to fill the template — emit a `fit.py` shape instead, and say so. The "checkpoint"
    is the fitted memory bank; still save it with config + git SHA.
- **Eval:** image-level AUROC + pixel-level AUROC/AUPRO, per defect type. If you emit `accuracy`, you have
  written the wrong eval — on a line running 99.5% good parts, calling everything "good" scores 99.5%.

### 3c. If the task is a multi-stage pipeline, the seam is the project

**Load the `pipelines` skill first — it owns this, and the single-task skills do not.** A cascade
(detect → crop → score) is not two projects stapled together; every interesting failure lives in the seam.
Non-negotiables when emitting it:

- **Stages are pure functions between contracts:** `Image → Detections → Crops → Scores`. Each stage is
  independently runnable and testable. No stage reaches around another; no stage re-opens the source image
  to patch up an upstream mistake.
- **ONE split manifest, shared by every stage**, defined at the part/lot level. A detector trained on
  images that appear in stage 2's test set contaminates the result even though stage 2 never saw them.
  Assert it in a test.
- **One crop implementation**, deterministic (fixed padding, resize, sort order), called by BOTH fit and
  eval. Two crop paths = a distribution shift you built yourself.
- **`eval.py` reports THREE numbers in one run:** per-stage (detector mAP), oracle-input (stage 2 on
  ground-truth crops), and end-to-end (stage 2 on predicted crops, **with missed detections folded in as
  system misses**). The gap between the last two is what stage 1 costs you. A pipeline eval that reports
  only stage 2's metric is hiding every missed detection.
- **Pin the upstream checkpoint hash into the downstream artifact**, and freeze the upstream stage while
  fitting the downstream one.
- **No upstream model yet? Start with the ORACLE stage** — stage 1 returns the ground-truth region (or the
  whole image as one region) behind the same contract, config-selectable. The pipeline is green end-to-end
  on day one, and the real detector drops into the same slot with zero downstream change. This is never
  throwaway: you need the oracle path permanently for the ablation above.

### 3d. Instantiate the delivery templates

`.claude/templates/` ships starter files for the *target* project — copy each to its destination
(never-clobber, §4's rule applies) and fill the marked slots:

| Template | → Destination | Fill |
|---|---|---|
| `dot-env.example` | `.env.example` | keep the tracker block `/intake` chose, delete the other; `<pkg>` in the header |
| `pre-commit-config.yaml` | `.pre-commit-config.yaml` | nothing — suggest `uvx pre-commit install` in the report |
| `project-ci.yml` | `.github/workflows/ci.yml` | nothing — it runs exactly the offline tier |

Also ensure the target's `.gitignore` covers `.env` (add it if absent — an `.env.example` next to an
unignored `.env` is a credential leak waiting to happen). Then seed the **resource matrix**
(`.claude/memory/process/resources.md`) with the rows the skeleton just created — `DATA_ROOT`
and the tracker (env keys, credential references) — replacing the illustrative rows; the matrix
and `.env.example` stay in sync from this moment on. Report each instantiated file in §7.

### 3e. Tabular archetype — the sklearn shape (no torch anywhere)

**Load `tabular` + `wrangling` first** (splits stay `datasets`' discipline). Do not copy DL keys
that mean nothing here — no `device`, `ckpt`, `resume`, AMP, or scheduler groups; the persistence
story is a joblib round-trip, not checkpoints.

```
conf/
  config.yaml              # seed, experiment, run_name, tracking.uri, target, cv.folds, defaults
  model/hist_gbm.yaml      # HistGradientBoosting* — the boosting default with zero extra deps
  model/logreg.yaml        # the interpretable rung of the ladder (baselines are gates)
  dataset/<name>.yaml      # path: ${oc.env:DATA_ROOT}/<name>.parquet · synthetic: true|false ·
                           #   target / group / categorical / numeric columns — config, not literals
src/<pkg>/
  env.py · seed.py         # same contracts as the DL shape
  data/load.py             # frame loading + the synthetic frame (mixed dtypes, group col, target)
  data/splits.py           # SPLIT_SEED; group-aware manifest — the group column never straddles splits
  pipeline.py              # build_pipeline(cfg) -> sklearn Pipeline (ColumnTransformer + model);
                           #   ALL learned preprocessing lives inside it — the leakage armor
  train.py                 # fit on train, score val, log to tracker — and compute + log the Dummy
                           #   baseline AUTOMATICALLY every run; a number without its floor is noise
  eval.py                  # loads models/model.joblib, scores the untouched holdout ONCE
models/model.joblib        # pipeline + model persisted as ONE artifact; sklearn version recorded
```

### 3f. Time-series archetype — the backtest IS the skeleton

**Load `timeseries` first** (the regressor mechanics may borrow `tabular`). Non-negotiables: no
shuffled split exists anywhere in this shape; MASE is baked in so every result is read against
the naive gates.

```
conf/config.yaml           # seed, horizon, freq, season, backtest: {n_origins, gap}
conf/dataset/<name>.yaml   # time / target / series-id columns · synthetic: true|false
src/<pkg>/
  data/load.py             # parse tz-aware UTC at the boundary; sort by time — order is not a contract
  data/splits.py           # rolling-origin manifest with an EMBARGO GAP >= the longest feature window
  features.py              # causal lags/rolling ONLY — shift(1) before any rolling op, enforced by test
  baselines.py             # naive + seasonal-naive — the gates every model must beat (MASE < 1)
  train.py                 # fit per origin, aggregate MASE/sMAPE across origins vs BOTH baselines
  eval.py                  # final holdout = the most recent horizon-length window, touched once
```
The synthetic series is trend + seasonality + noise — so the seasonal-naive baseline is
non-trivial and the proof run means something.

### 3g. LLM fine-tuning archetype — data + eval harness now, training when the GPU arrives

**Load `finetune-unsloth` + `llm-eval` first.** This lane's bootstrap deliberately emits only the
parts provable **without** a GPU or the heavy deps — a fabricated "training success" on CPU would
be a lie, and this command doesn't lie in its §7 report.

```
conf/config.yaml           # seed, base_model, max_seq_length, data paths, lora: {r, alpha, ...}
src/<pkg>/
  data/prep.py             # jsonl chat records -> template-applied text; train/eval split with
                           #   DECONTAMINATION (exact + n-gram overlap) — this lane's leakage
  train_sft.py             # the Unsloth + TRL shape per the skill, import-guarded: if unsloth is
                           #   absent it exits with the install pointer — never a fabricated fallback
  eval_golden.py           # golden-prompt regression harness: fixed prompts + expected checks,
                           #   deterministic decoding params from config
golden/prompts.jsonl       # the golden set — versioned with the data (data-dvc)
```

### 3h. Platform archetypes — the deployable surface IS the skeleton

For **agent platform · RAG service · inference platform · eval harness · MLOps platform**, the
`train.py`/`eval.py` shape above is the wrong skeleton. What this lane needs proven on day one is
that a hardened workload deploys, a policy rejects a bad one, telemetry arrives, and an eval gate
runs. Generate:

```
deploy/
  base/          namespace.yaml (PSS restricted labels) · deployment.yaml · service.yaml
                 networkpolicy-default-deny.yaml · rbac.yaml · kustomization.yaml
  overlays/dev/  kustomization.yaml (image digest, replicas: 1)
  overlays/prod/ kustomization.yaml (image digest, replicas, PDB, resource bumps)
policies/        kyverno/ or rego/ — the baseline set + a fixture that MUST fail and one that MUST pass
observability/   otel-collector.yaml (with the redaction processor wired) · dashboards/
evals/           harness + cases/ (capability) + safety/ (red-team regression, gated absolutely)
.github/workflows/security.yml
src/<pkg>/       the service itself; agents/ + tools/ if the lane is agent-shaped
```

Instantiate from `.claude/templates/k8s/`, `templates/policies/`, `templates/security-ci.yml`, and
`templates/otel-collector.yaml` — **do not hand-write the manifests.** The templates already satisfy
`platform-security.md` `P1`–`P10`; anything you write from scratch will be blocked by
`guard-k8s-manifests.py`, which is the system working, not an obstacle.

Load the skills that own each piece before generating: `kubernetes` (workload shape),
`policy-as-code` (the policy set), `observability` (what to emit), `secure-cicd` (the gate ladder),
`agent-evaluation` (the eval harness), and — for agent-shaped lanes — `agent-security` for the tool
boundary.

**Two files this lane must also create**, because they are the ones nothing else will:
- `.claude/memory/process/agent-authority.md` (T13) — the declared tool surface per agent. Seed it
  from the tools you generate; `guard-agent-config.py` checks edits against it.
- `.claude/memory/process/slo-register.md` (T10) — seeded empty with the service named, so `/slo`
  has somewhere to write.

**Prove it (§5 applies, adapted):** `kubectl kustomize deploy/overlays/dev` renders; `conftest test
-p policies/ -` passes against the rendered output **and** `conftest verify -p policies/` shows the
bad fixture is actually rejected; the eval harness runs on its example case; `python3
.claude/scripts/check-hooks.py` passes. A skeleton whose policy fixture doesn't fail is a policy
that isn't enforcing anything — that is the check people skip.

## 4. Never clobber (but *do* extend)

Before **creating** a file: if it already exists and is non-empty, **stop and ask** — do not overwrite. This
command's job is to fill a void; the moment there's real code, the user's code wins.

That's a rule about *replacing* files, not touching them. Additive edits to pre-existing files are expected
and correct — do them, and report each: the smoke test (repoint determinism at `seed_everything`, add the
leakage test), the package `__init__.py` (a hello-world `main()` can go once real entry points exist), and
`pyproject.toml` (e.g. registering a pytest marker, and a `[tool.ruff] line-length = 100` block so the
post-edit ruff hook doesn't throw un-autofixable E501 on prose-heavy modules — see `env-uv`).

The line: **add to a file, never rewrite it out from under the user.** If an existing file's *logic* must
change to make the skeleton work, that's not a bootstrap edit — stop and ask. In particular: if a workaround
seems to require reaching into `os.environ` from library code, you have found a bug in a skill, not a license
to violate config-over-constants. Report it.

## 5. Prove it runs (don't just claim it)

Per `testing`, a green-looking command that never ran is worse than no test. Run these for real:

1. Lint/format, then the existing suite — it must still pass.
2. **Extend the smoke** so it covers the new code: point the determinism test at `<pkg>.seed.seed_everything`
   (so it exercises the helper the loop actually calls), and add a **leakage** test — split index sets are
   pairwise disjoint, and for anomaly detection, **zero anomalous samples in train**.
3. **Train, for real:** one epoch, CPU, `synthetic: true` if there's no data. Then **prove it wrote what it
   claims** — a tracker run exists with the resolved params + git SHA, and `models/best.pt` + `last.pt` are
   on disk. "Exit code 0" is not evidence. (Fit-not-trained AD: run the fit and confirm the memory bank
   persisted.)
4. **Eval, for real:** load the checkpoint back. Do not skip this because train passed — the train path never
   exercises `torch.load`, and reading a checkpoint back is where the failures live (`weights_only`,
   struct-mode keys, device mismatch). A skeleton whose checkpoints can't be *read* is not a working skeleton.
5. **Resume, for real:** re-run train from `last.pt`. It's the one path where a wrong `weights_only` or
   RNG-restore bug hides until the day you actually need it.
6. **Archetype variants of 3–5:**
   - **Tabular (§3e):** fit on the synthetic frame → reload `models/model.joblib` → eval-once path.
     The leakage test asserts the pipeline's learned statistics come from **train only** (fit on
     train, verify val transforms use train-fit parameters), and that the group column never
     straddles splits.
   - **Time-series (§3f):** run ≥2 backtest origins for real; report vs BOTH baselines; the
     **causality test** asserts every feature at time *t* is computable from data strictly before
     *t* (perturb the future, features must not change).
   - **LLM (§3g):** data-path proof only — prep round-trips a synthetic jsonl, decontamination
     catches a planted duplicate, the golden harness dry-runs against a stub scorer. Training
     proof is **deferred to the first real run — state this loudly in §7**; do not simulate it.

## 6. Back-fill the now-answerable placeholders

Re-run `grep -rn "<PLACEHOLDER" .claude/ CLAUDE.md README.md`. The hits are **two different families sitting
side by side in the same files** — read each, don't sweep:

- **Resolve now (code-dependent):** the dataset slug in `config-hydra` / `datasets` / the data-versioning
  skill, and any entry-point path. You just created the thing they were waiting on.
- **Resolve now — `testing/SKILL.md`'s four `/bootstrap fills this` slots.** Step 5 computed every
  answer; write them in: the package import check (`uv run python -c "import <pkg>"` with the real
  package name), the tiny-data-smoke invocation (the real test-file path from step 5.2), the seed-helper
  path (`<pkg>.seed.seed_everything`), and the Preconditions `.env` keys — read them straight from the
  `.env.example` you instantiated in §3d. A verification skill whose commands are blank teaches
  the agent to guess; these four lines are the whole point of that skill.
- **Leave (human-decision):** the data remote URL, `software-architect`'s architecture principles,
  `governance`'s policy domains, and the org-specific rules in `memory/policy/`. Don't invent values — a
  wrong policy is worse than a visible blank.

## 7. Report

- **Created:** each file, one line each. **Skipped:** anything that already existed (step 4).
- **Assumed:** any interview answer you defaulted because you couldn't ask.
- **Verified:** the exact commands from step 5 and their real output (test count, the tracker run id, the
  metric). Never claim a success you didn't observe.
- **Still needs you:** every remaining `<PLACEHOLDER`, plus any data-remote that isn't configured (without
  one, a git SHA does not pin recoverable data).

Then remind the user this is one-time — re-run only to reshape the skeleton, and never over real code.
