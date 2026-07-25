# Model governance — policy canon

The authored source of truth for how trained models are built, recorded, evaluated, and released in
this repo. This file is DATA (the canon); the `governance` skill is the access protocol over it
(locate → load → apply → record). It wins on any conflict. Sibling canon: `data-governance.md` governs
the datasets, splits, labels, and licensing these rules lean on — where the two meet (data version,
leakage), this file points there rather than restating it.

Scope: anything that produces or ships a **model** — a trained/fine-tuned network, a fitted classical
estimator, or a pipeline whose behavior depends on learned weights. Rules are named (`M1`, `M2`, …) so a
decision can cite the exact rule it turned on. Universal rules are concrete; `<PLACEHOLDER: …>` marks
the specifics each adopting org fills in.

## Reproducibility

**M1 — A model that can't be reproduced doesn't ship.** Every trained model records enough to rebuild
it from scratch: the resolved config, the code `git` SHA, the data version, the seed(s), and the
environment lockfile. Missing any one of these makes the artifact provisional — usable for exploration,
never for release. *Why: a result you can't regenerate is an anecdote, not an asset — and it can't be
debugged, audited, or improved.*

**M2 — Record the run inputs, don't reconstruct them.** At train time, capture into the run's manifest:
(a) the fully-resolved config (post-override, not the template), (b) `git rev-parse HEAD` plus a
dirty-tree flag, (c) the dataset version identifier (DVC hash / `<PLACEHOLDER: your data-version scheme>`),
(d) every RNG seed set, and (e) `uv.lock` (or its hash). *Why: inputs recovered after the fact are
guesses; inputs written at the moment of truth are evidence.*

**M3 — A dirty tree or unpinned env taints the run.** No release-track model is trained from
uncommitted code or an unlocked environment. If the working tree is dirty, the manifest must flag it and
the run is exploratory only. *Why: "it worked on my machine last Tuesday" is not reproducible; the SHA
must actually name the code that ran.*

**M4 — Seed and record determinism.** Set and log all seeds; enable deterministic kernels where the
framework supports it, and where you accept nondeterminism (e.g. for speed) say so explicitly in the run
manifest. *Why: silent nondeterminism turns an unreproducible result into a mystery instead of a
documented tradeoff.*

## Checkpoint provenance & naming

**M5 — A checkpoint traces back to the run that made it.** Every saved checkpoint carries (or resolves
by its name to) its run ID, code SHA, data version, and step/epoch. Given only the file, you can find
the run, the config, and the data. *Why: an orphan `best.pt` on disk is a liability — nobody can say
what it is, what it saw, or whether it's safe to use.*

**M6 — Checkpoint names are systematic, not ad-hoc.** Follow one naming scheme repo-wide:
`<PLACEHOLDER: e.g. {project}-{run_id}-{step}-{metric}.{ext}>`. Never overwrite a released checkpoint in
place; new weights get a new name. *Why: `model_final_v2_real.pt` is how provenance dies — names are the
cheapest index you have.*

**M7 — The artifact store is versioned, not a scratch folder.** Checkpoints, model cards, and eval
reports live under the tracked artifact store (`<PLACEHOLDER: DVC remote / registry / bucket>`), tied to
their run — not loose in a home directory. *Why: a model you can't locate later is a model you can't
ship, audit, or roll back to.*

## Evaluation before release

**M8 — Report held-out metrics before a model is used downstream.** No model is consumed by another
stage, demo, or product path until its held-out **test** metrics and known failure modes are recorded in
its model card. *Why: an unevaluated model is an unknown liability — downstream trust must be earned on
data the model never touched.*

**M9 — No eval-set leakage into model selection.** Hyperparameter search, early stopping, checkpoint
selection, and threshold tuning use the **validation** split only; the **test** split is touched once,
at the end, for the reported number. Splits are defined once in `data-governance.md` and respected here.
*Why: tuning against the test set inflates every metric you'll quote and silently overfits the decision —
see `data-governance.md` on leakage.*

**M10 — Name the failure modes, not just the averages.** Alongside headline metrics, record where the
model breaks: hard slices, out-of-distribution inputs, and the conditions under which it should not be
trusted (`<PLACEHOLDER: your domain's known-hard cases — lighting, occlusion, small objects, rare
classes>`). *Why: an aggregate score hides the exact places a CV model fails; downstream users need the
caveats, not just the mean.*

## Model cards

**M11 — Every released model ships a model card.** The card states: intended use (and out-of-scope
use), the training data and its version, eval metrics with the evaluation protocol, and limitations.
No card, no release. *Why: the card is the model's contract — it tells the next person what this thing is
for and where it isn't.*

**M12 — Model cards address CV-specific ethical considerations.** Where the task touches people or
consequential decisions, the card reports performance **disparities across demographics and conditions**
(`<PLACEHOLDER: the axes that matter for your use — skin tone, age, lighting, camera/sensor, geography>`),
states known biases, and flags surveillance/misuse potential. *Why: a vision model that works "on
average" can still fail systematically on a subgroup — shipping without measuring that is how harm
scales.*

## Pretrained weights & licensing

**M13 — Record the license and source of every pretrained weight.** Any pretrained backbone,
checkpoint, or foundation model you build on has its source URL, version, and license logged in the run
manifest and model card — and the license must permit the intended use (including commercial, if that's
the plan). *Why: an incompatible or unrecorded upstream license makes your model legally unshippable, no
matter how good it is.* Pretrained **data** licensing and provenance follow `data-governance.md`.

## Models you did not train

**M14 — A third-party model reached over an API is a dependency with a version, not a constant.**
Record the provider, the exact model identifier, and the version or snapshot date in the run manifest —
`gpt-style-model` is not a version. Pin to a dated snapshot where the provider offers one, because
silent model updates change behaviour, cost, and eval results underneath you. Provider terms are part of
the record: what may be sent (`security.md` `S7` — sending data to an inference API is publishing it),
what may be retained, and whether outputs may be used to train. *Why: an unpinned third-party model makes
every evaluation unreproducible and every regression undiagnosable — you cannot tell "our change broke
it" from "their model moved."*

**M15 — Prompts and tool definitions are versioned artifacts, and changing one is a model change.** A
system prompt, a prompt template, a tool schema, and a retrieval configuration each materially determine
behaviour. They are versioned in git, referenced by version in the run manifest, and a change to any of
them requires the same evaluation before release that a weight change does (M8–M10). Provenance follows
`ai-security.md` `AI8`. *Why: teams version weights meticulously and edit the system prompt in
production, which is how a "no-code-change" incident happens.*

**M16 — Agentic systems are evaluated as trajectories, not just outputs, before release.** For any
system that plans or calls tools, the pre-release evaluation covers task success, tool-call correctness,
and behaviour under adversarial input — a recorded red-team run (`llm-red-teaming`) is part of the
release evidence, not a follow-up. The methods live in `agent-evaluation`; the obligation lives here.
*Why: an agent can produce good-looking final answers via a trajectory that leaked data, called the wrong
tool, or succeeded by accident — and only the trajectory shows it. [SSDF 800-218A]*

## Recording a judgment call

Most of the above is prescriptive — follow it. When a call is genuinely irreducible (shipping a model
that misses a rule, redefining "released", accepting a known disparity for a documented reason), append
one entry to **`model-governance-decision-log.md`** beside this file:

- **What** — the decision, in one line.
- **Which rule** — the `M#` it bears on (or "new area").
- **Why** — the reasoning and the tradeoff accepted.

Append-only: log the call, don't rewrite the canon. If a pattern of calls shows the canon is wrong,
amend the rule here in a separate, deliberate edit.
