---
name: monitoring
description: >
  Production model monitoring — PROCESS.md P7 made concrete: a deployed model degrades by
  default; this makes it visible and actionable. Carries: what to log at inference (sampled
  inputs + predictions + model/data versions, schema-versioned), input drift detection (PSI /
  KS per feature; embedding-distance drift for images), concept drift and the
  delayed-ground-truth loop (proxy metrics until labels arrive), live performance on the P1
  metric with slices, reference windows + alert thresholds, retraining triggers
  (schedule / drift / upstream event), and shadow-eval before a registry alias moves. Load when
  deploying a model, wiring drift detection, or asking "is the model stale". Triggers: model
  monitoring, drift, data drift, concept drift, PSI, KS test, production model, model decay,
  stale model, retrain trigger, shadow deployment, ground truth delay, feedback loop, prediction
  logging. **Model** decay only — systems telemetry (traces, metrics, logs, OpenTelemetry) is
  `observability`, SLOs and alerting policy are `reliability-sre`, and agent/LLM quality in
  production is `agent-evaluation`.
---

# monitoring — making model decay visible

> On-demand: load this at deployment time (P7). Everything upstream still owns its part: the
> P1 metric is *what* you monitor, `evaluation` is *how* you score it, the registry
> (`tracking-mlflow`) is how a replacement ships, and retrain/promote decisions are governed
> (`model-governance` + the decision log). This skill owns the loop that notices decay.
> Tool-agnostic: the concepts map onto evidently/whylogs/custom jobs equally.
>
> **Scope boundary — this is model monitoring, not systems observability.** Emitting traces,
> metrics, and logs is `observability`; SLIs, SLOs, error budgets, and alerting policy are
> `reliability-sre`; scoring an agent's output quality in production is `agent-evaluation`. The
> two meet at one point: a quality SLI (`reliability-sre` `R1`) is fed by the loop this skill
> describes.

## First: log enough to monitor at all
At inference time, durably log (sampled if volume demands): input features (or image
embeddings), the prediction + score, model version (registry alias/version), data/schema
version, and timestamp — **schema-versioned**, because the monitoring jobs are consumers of
this log and silent schema drift kills them first. No logging → every question below is
unanswerable. (What may be logged is governed — PII rules in `data-governance`/`security`.)

## The three questions, in escalating difficulty
1. **Input drift — are inputs still like training data?** Needs no labels. Per-feature PSI or
   KS statistic against a **reference window** (the training set or a healthy production
   week). Rough PSI reading: <0.1 stable · 0.1–0.25 watch · >0.25 investigate. For images:
   distance between embedding distributions (a frozen feature extractor over samples), plus
   cheap proxies that catch camera/pipeline breakage — brightness, blur, resolution mix.
2. **Score drift — is the model behaving differently?** Prediction/score distribution vs the
   reference window; a classifier whose positive rate doubles is telling you something no
   input stat caught.
3. **Performance — is it still right?** Needs ground truth, which usually arrives **late**
   (returns, QC results, user corrections). Build the join deliberately: predictions matched
   to eventual labels → the P1 metric, computed on a rolling window, **sliced** like the eval
   harness slices (segment, site, class) — aggregates hide exactly the slice that broke.
   Until labels arrive, 1+2 are the early-warning system, not a substitute.

## Thresholds, triggers, and the response
- Set alert thresholds from the reference window's natural variation (its own week-to-week
  PSI), not from vibes — otherwise the pager teaches everyone to ignore it.
- **Retraining triggers, written down (the P7 gate demands this):** schedule-based (every N
  weeks), drift-based (sustained PSI/performance breach), or upstream-event (new camera, new
  product line, patch — the concept-drift events you can *see coming*). Test the trigger path
  once before trusting it.
- **A retrained model does not go straight to production.** Shadow it (score live traffic,
  compare, don't act) or canary it; promotion is the registry alias move, gated on the same
  eval evidence as any release, recorded in the decision log.
- Name an owner and an alerting path. An unowned dashboard is decoration.

## Gotchas
- **Feedback loops:** when the model's output influences its future inputs (flagged items get
  inspected, so confirmed-defect labels skew toward what the model already flags), naive
  retraining amplifies the bias — sample some ground truth *independent* of the model's
  decisions.
- **Seasonality reads as drift** — compare against the same season's reference or a rolling
  year, or every December pages you.
- **The silent failure mode is upstream, not the model:** a renamed field, a changed unit, a
  camera swap. Schema checks + input-range assertions on the inference path catch in minutes
  what drift stats take weeks to surface.
