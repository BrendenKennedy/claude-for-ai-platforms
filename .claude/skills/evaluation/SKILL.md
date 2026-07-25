---
name: evaluation
description: >
  Measuring a model — the metric that matches the task, a deterministic eval script separate from
  training, run comparison via the tracker, and error analysis instead of one aggregate number.
  Carries: metrics by task (classification: accuracy/precision/recall/F1/confusion matrix; detection
  & segmentation: mAP@IoU, IoU, PR curves), picking the operating point, the touch-the-test-set-ONCE
  rule, error analysis (worst cases, per-class, data slices), qualitative prediction visualization,
  and calibration. Load when building an eval harness, reporting a score, deciding a threshold, or
  explaining why a model fails. Triggers: evaluate, evaluation, eval script, metric, accuracy,
  precision, recall, F1, confusion matrix, ROC, AUC, PR curve, threshold, operating point, mAP, IoU,
  dice, per-class, error analysis, worst cases, failure cases, slice, calibration, ECE, compare
  runs, is it good enough.
---

# evaluation — measuring the model, honestly

> On-demand: load this before writing an eval harness, reporting a score, or picking a threshold. It
> carries how this repo picks a metric, runs eval deterministically apart from training, and pairs every
> aggregate number with error analysis. It does **not** own split integrity — that's `datasets` — nor
> run comparison plumbing, which is `tracking-mlflow`.
>
> **For LLM and agentic systems, go to `agent-evaluation` instead.** Trajectory and tool-call
> correctness, LLM-as-judge discipline, RAG metrics, and safety/red-team suites are a different
> measurement problem and live there. This skill covers classic supervised metrics — which still
> apply underneath (a judge is a classifier; calibration and slice analysis are the same ideas), so
> the two compose rather than compete. Whether a difference is real is `statistics`, either way.

## When this applies
Building or changing an eval script, choosing which metric to report, deciding an operating point /
threshold, comparing candidate runs, or diagnosing *why* a model underperforms. If you're about to print
a single accuracy and call it done, this skill is the correction.

## Pick the metric to match the task
The metric encodes what "good" means — choose it from the task and the cost of each error, not by habit.
- **Classification** — `accuracy` only when classes are balanced *and* errors cost the same. Otherwise
  report `precision` / `recall` / `F1` per class, and a **confusion matrix** to see *which* classes
  collide. Class imbalance ⇒ prefer macro-F1 (per-class mean, so rare classes count) and PR-AUC over
  ROC-AUC. For probabilistic outputs, sweep the **PR curve** rather than fixing 0.5.
- **Detection** — `mAP` averaged over IoU thresholds (report `mAP@0.5` and `mAP@[.5:.95]`), where a
  prediction counts as a hit only above an **IoU** overlap threshold with a ground-truth box. Inspect the
  per-class PR curves, not just the mean.
- **Segmentation** — mean **IoU** (Jaccard) / Dice per class over the mask; watch boundary vs. interior
  errors and tiny/rare classes that a global mean drowns out.
- **Anomaly detection** (industrial/factory defect finding) — the model emits an **anomaly score**, not a
  class, so the metric set is its own thing:
  - **Image-level AUROC** — can it tell a defective part from a good one at all? The headline number.
  - **Pixel-level AUROC** — does the heatmap land *on* the defect? Beware: defects are a tiny fraction of
    pixels, so pixel AUROC looks high even for a mediocre localizer. Report **AUPRO** (per-region overlap)
    or pixel **AP** alongside it — they don't let a big blurry blob score well.
  - **NEVER report accuracy.** A line running 99.5% good parts gets 99.5% accuracy by calling everything
    good. Accuracy on an AD test set measures the defect rate, not the model.
  - Defect *types* are usually unseen in training; report AUROC **per defect type** — a model can ace
    `scratch` and completely miss `contamination`, and the mean hides it.

**Operating point:** a threshold-free metric (AUC/mAP) ranks models; deployment needs one chosen
**operating point**. Pick the threshold on the **validation** set from the PR curve at the
precision/recall trade the task demands (e.g. high-recall screening vs. high-precision alerting) — never
on the test set. Record the chosen threshold as an artifact so eval and serving agree.

For **anomaly detection** this is the whole ballgame, and it's a business decision before it's a modelling
one: an escaped defect (false negative) and a scrapped good part (false positive) have different costs, and
the factory knows those numbers. Pick the score threshold on validation against *that* ratio, log it as an
artifact, and never re-tune it on test.

## A deterministic eval script, separate from training
Eval lives in its own entry point (`<PLACEHOLDER: eval.py / src/<pkg>/eval.py>`), not a tail appended to
the train loop — so any checkpoint can be scored without retraining, and the two never share mutable
state.
- **Deterministic:** seed everything, `model.eval()` + `torch.no_grad()` (or `inference_mode`), fixed
  transforms (no train-time augmentation/shuffle), fixed batch order. The same checkpoint + same data
  must yield the same number every run. (Reproducibility is an always-on convention — see `CLAUDE.md`.)
- **Config-driven:** checkpoint path, split, thresholds, and metric set flow through the config system
  (`config-hydra`), never hardcoded — so an eval is reproducible from its recorded config alone.
- **Log to the tracker:** write metrics, the confusion matrix, PR curves, and sample predictions to
  MLflow via `tracking-mlflow`, keyed to the run that produced the checkpoint.

## Compare runs through the tracker, not by eye
Model selection happens on **validation** metrics compared in `tracking-mlflow` — sort/filter runs on the
chosen metric, confirm the configs differ only where you intended, and check the gap is real (not run-to-
run seed noise). Promote one candidate. The test set does not enter here.

## Touch the held-out test set exactly ONCE
All iteration — tuning, thresholds, architecture, model selection — happens on **validation**. The test
set is scored **one time**, at the very end, on the single already-chosen model, to report the number you
publish. Every extra peek leaks it (see the never-leak-the-eval-set convention in `CLAUDE.md` and split
integrity in `datasets`). If you scored test, selection is over — don't go back and tune.

## Error analysis — the aggregate hides the failures
A single number says *whether* it's good, never *where* it fails. Always pair it with:
- **Worst cases:** rank predictions by loss / lowest confidence-on-correct / highest-confidence-wrong and
  eyeball the top offenders — mislabels, ambiguous samples, and systematic blind spots surface here.
- **Per-class:** the confusion matrix / per-class F1 (or per-class AP/IoU) exposes the one or two classes
  dragging the mean down.
- **Data slices:** break metrics out by meaningful subgroups (lighting, resolution, source/camera,
  object size, demographic) — a strong global score routinely hides a slice that's near-random.
- **Fairness slices are required, not optional, when predictions affect people:** per-group
  performance on the sensitive attributes the deployment context names. Gaps found are reported in
  the model card and limitations (`model-governance`, `reporting`) — not quietly averaged away —
  and slice findings still pass the multiple-comparisons discipline (`statistics`) before being
  treated as real.
- **Qualitative viz:** render predictions on inputs — overlay boxes/masks with GT, plot the confusion
  matrix and PR/reliability curves — and log the panels to MLflow. Hand this to the `eval-analyst` agent
  to turn into findings.

## Calibration
Accuracy answers "is it right"; **calibration** answers "are its probabilities trustworthy" — needed
whenever a downstream threshold or decision consumes the confidence. Plot a **reliability diagram** and
report **ECE**; if miscalibrated, fit temperature scaling **on validation** (never test) and re-check.

## Gotcha
Touch the test set once, at the very end — repeatedly tuning against it silently turns it into a training
set and your reported number becomes a lie. And a single aggregate score hides failures: always pair it
with per-class + slice error analysis, because a model can post a great mean while being useless on the
slice you actually ship to.
