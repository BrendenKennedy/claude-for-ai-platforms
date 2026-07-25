---
name: datasets
description: >
  Defining and handling a dataset — the split discipline, layout, and provenance everything
  downstream depends on (universal across archetypes), plus the CV lane's label formats. Carries the
  rules that bite: split ONCE with a fixed seed and no leakage (group/subject/temporal split when
  samples share a source), the provenance manifest (source/license/version), deterministic
  preprocessing vs random augmentation, stats computed on train only — and for CV work: label
  formats (COCO JSON, YOLO txt, Pascal VOC XML) + the conversion traps, on-disk image layout, one-
  class anomaly-detection layout (normal-only fit set). Load before making a split, adding or
  converting annotations, computing class balance or normalization stats, or wiring a new dataset
  in. Triggers: dataset, split, train/val/test, holdout, leakage, group split, temporal split,
  stratify, class imbalance, COCO, YOLO, Pascal VOC, bounding box, label format, convert
  annotations, manifest, normalization stats, mean std, augmentation, eval set, don't touch test.
---

# datasets — split discipline, provenance, and (for CV) label formats

> **Where the data physically lives** — object storage layout, Parquet, Iceberg/Delta table formats,
> partitioning — is `object-and-lakehouse`. This skill owns what a dataset *is* and the discipline
> around it; that one owns the bytes. A retrieval corpus is a dataset under `data-governance.md`
> `D7`, with its own skill for the store (`vector-stores`).
>
> On-demand: load this before you make a split, add/convert annotations, compute dataset stats, or wire a
> new dataset in. It carries the discipline that keeps results honest — split once, respect it everywhere,
> and never let the eval set touch training. The `training`/`evaluation` skills consume what you define
> here; the licensing/PII rules live in `governance` → `data-governance`, not here.

## When this applies
Defining or splitting a dataset, choosing/converting a label format, laying out files on disk, writing the
provenance manifest, computing class balance or normalization stats, or deciding what's preprocessing vs
augmentation. Data **versioning** of the result is `data-dvc`; this skill defines *what* gets versioned.

## Split discipline (the thing that decides whether your numbers mean anything)
- **Define splits ONCE, deterministically.** Materialize train/val/test as an explicit, committed
  artifact — a split manifest (`{sample_id: split}` in a CSV/JSON) or fixed file lists — seeded with a
  single constant (`<PLACEHOLDER: SPLIT_SEED>`). Never re-split on the fly at load time; every run, every
  tool, every teammate reads the *same* assignment.
- **Split on the right unit — group when samples share a source.** If multiple samples come from one
  subject/patient/scene/camera/video, a random per-image split leaks that source across train and val.
  Split on the **group key**, not the image:
  - **Group/subject split** — all frames of one patient/scene go to exactly one split.
  - **Temporal split** — for anything time-ordered (video, streaming capture), train on the past and
    evaluate on the future; a random split lets near-duplicate adjacent frames leak.
  - **Stratify** on the label when classes are rare, but stratify *within* the group constraint, not
    against it — group disjointness wins over perfect class balance.
- **Three splits, three jobs:** train (fit weights) · val (tune hyperparameters, pick checkpoints,
  early-stop) · test (touched once, at the end, for the reported number). Backs the always-on
  **never-leak-the-eval-set** convention.

## Label formats — what you'll meet and when
| Format | Shape | Typical use | Boxes encoded as |
|---|---|---|---|
| **COCO JSON** | one big JSON (`images`/`annotations`/`categories`) | detection, segmentation, keypoints; the eval de-facto standard (mAP) | absolute `[x, y, w, h]`, top-left origin |
| **YOLO txt** | one `.txt` per image, one row per box | YOLO-family training (Ultralytics) | **normalized** `class cx cy w h` (0–1, center) |
| **Pascal VOC XML** | one `.xml` per image | older detection sets, some tooling | absolute `[xmin, ymin, xmax, ymax]` |

- **Convert deliberately, and re-verify after.** The bug is almost always the box convention: COCO's
  `[x,y,w,h]` vs VOC's `[xmin,ymin,xmax,ymax]` vs YOLO's **normalized center** form — a conversion that
  forgets to divide by image `W,H`, or mixes corner/center, silently shifts every box. Round-trip a few
  samples and **render boxes over the image** to confirm, don't trust counts alone.
- Keep the **canonical** annotations in one format (COCO JSON is the safest hub — richest, best-supported)
  and generate the others as derived artifacts, versioned via `data-dvc`.

## Layout + provenance manifest
Keep a predictable tree and, next to it, a manifest that records where the data came from:

```
data/<PLACEHOLDER: dataset_name>/
  raw/            # immutable source, exactly as received — never edited in place
  annotations/    # canonical labels (e.g. COCO JSON)
  splits/         # committed split manifest(s) — the single source of truth for train/val/test
  MANIFEST.md     # provenance: source, license, version, collection date, known caveats
```

- **`MANIFEST.md` records provenance** — **source** (where/how collected or the download URL), **license**
  (and any redistribution / commercial limits), **version** (bump on any relabel or re-collection),
  sample count, and known biases/caveats. Licensing and any **PII/consent** obligations are governed —
  consult `governance` → `data-governance` before ingesting or sharing; don't restate that policy here.
- **`raw/` is immutable.** All cleaning/relabeling produces new derived artifacts; you never mutate the
  source. Large binaries are tracked by `data-dvc`, not committed to git.

### Anomaly detection has a different shape — and a different leakage rule
Industrial/factory defect datasets are **one-class**: you fit on **normal parts only** and never show the
model a defect. The *shape* below is the invariant; the **directory names are not** — a client's line will
call them `pass/` and `inspection/`, not `train/good/`. Drive the names from config (see the folder-convention
adapter in `/bootstrap`) so a new site costs a YAML file, not a new dataset class. MVTec-AD is simply the
best-known instance of this shape:

```
data/<dataset>/                  #        (MVTec-AD names, as one example)
  <normal_dir>/                  # train/good/                 NORMAL ONLY — the entire fit set
  <test_dir>/<normal_name>/      # test/good/                  normal parts held out for test
  <test_dir>/<defect_type>/      # test/scratch/, test/dent/   SEEN ONLY AT TEST
  <mask_dir>/<defect_type>/      # ground_truth/scratch/       per-defect masks — often ABSENT at a client
```

> **MVTec-AD is CC BY-NC-SA 4.0 — non-commercial research only.** It's the right benchmark to validate a
> method; it is *not* something you can quietly ship inside a paying client's deliverable. That's a
> `governance` → `data-governance` call before it's a modelling one.

The rules that bite here, which the generic split discipline above does **not** cover:
- **A defect image in `train/` is a silent catastrophe.** It doesn't crash anything — it teaches the model
  that the defect is normal, so the model quietly stops flagging exactly what you built it to catch. Assert
  in code that the train split contains zero anomalous samples; make it a test (see `testing`).
- **You still need a validation set, and it must come from `train/good`.** Hold out normal parts for
  val — never borrow from `test/`, or your threshold is tuned on the test set.
- **Threshold selection needs *some* defects.** If you must use defective samples to pick an operating
  point, carve a *separate* small defect-val set out of `test/` **once**, commit it to the split manifest,
  and never score the final number on it. Reusing test defects to pick the threshold is the most common
  way AD papers (and pipelines) inflate their numbers.
- **Group by part/lot/camera.** Frames of the same physical part or the same production lot must not
  straddle train and test — same group-split rule as above, and easy to miss when filenames look random.

## Class balance & dataset stats (compute on TRAIN only)
- Report per-class counts and imbalance before training — it dictates loss weighting, sampling, and which
  metrics are honest (accuracy lies under imbalance; see `evaluation`).
- **Normalization stats (channel mean/std) are fit on TRAIN only**, then applied unchanged to val/test.
  Fitting them on the full set is leakage — quiet, and it inflates every number.

## Deterministic preprocessing vs random augmentation (draw the line)
- **Preprocessing is deterministic and applies to ALL splits** — resize/letterbox, color-space convert,
  the normalization above. Same input → same output, every split, every run.
- **Augmentation is random and applies to TRAIN ONLY** — flips, crops, color jitter, mosaic, etc. It must
  be **off** for val/test (evaluate on clean, deterministic inputs), and its RNG is seeded via the
  `training` skill's determinism rules so a run reproduces.

## Gotcha
**Leakage is the silent killer — it never errors, it just makes your metrics lie.** Define the split once,
commit it, and respect it everywhere: never fit weights, tune hyperparameters, select features, or compute
normalization stats on val/test. When samples share a subject/scene/video/camera, **group-split** — a
random per-image split of grouped data is the single most common way good-looking results turn out fake.
When in doubt, ask "could the model have seen anything correlated with this eval sample during training?"
— if yes, the split is wrong.
