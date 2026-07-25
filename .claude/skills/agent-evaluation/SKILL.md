---
name: agent-evaluation
description: >
  Evaluating LLM and agentic systems — measuring whether an agent actually works, not whether its
  answers look plausible. Carries: building the eval set before the system, trajectory evaluation
  (tool-call correctness, step efficiency, recovery) vs final-answer-only scoring, task success
  criteria that survive contact with reality, LLM-as-judge discipline (validate the judge against
  humans, position/verbosity/self-preference bias, rubrics over vibes), RAG-specific metrics,
  safety and red-team results as a first-class suite, CI regression gates, and online eval. Load
  when building an eval harness for an agent, choosing a metric, wiring a regression gate, or
  deciding whether a prompt/model change is safe to ship. Triggers: eval, evaluate the agent, agent
  evaluation, LLM eval, LLM as judge, judge model, benchmark, task success, trajectory, tool call
  accuracy, hallucination rate, groundedness, RAG evaluation, regression test for prompts, did the
  model get better, offline eval, online eval, A/B an agent. Classic ML metrics are `evaluation`;
  significance is `statistics`; attack generation is `llm-red-teaming`.
---

# agent-evaluation — measuring agents, not vibes

> On-demand: load this when the question is whether an agentic or LLM system works. Classic ML
> metrics (precision/recall/mAP/calibration) stay in `evaluation`; whether a difference is real is
> `statistics`; generating adversarial inputs is `llm-red-teaming`; the release obligation is canon
> (`model-governance.md` `M16`). The split discipline in `datasets` applies here in full — an eval
> set you tuned against is a training set.

## When this applies

Building an eval harness. Choosing what to measure. Deciding whether a prompt, model, or tool change
ships. Wiring a CI gate. Explaining why an agent fails.

## The rule that decides everything else

**Build the eval set before you build the system.** Not after, not "once it works." An eval set
written afterwards is written to the behaviour you already have, and it will confirm it. Written
first, it is a specification — and the act of writing it forces the question of what success actually
means, which is usually where the disagreement was hiding.

Start with 20–50 hand-written cases covering the real distribution and the known-hard cases. Small
and honest beats large and synthetic. Grow it from production failures: **every bug becomes a case**.

## Final answer vs trajectory — and why final-answer-only lies

An agent can produce a correct answer via a trajectory that called the wrong tool, leaked data across
a tenant boundary, took 14 steps to do 2, or succeeded by luck. Final-answer scoring is blind to all
of it. `model-governance.md` `M16` requires trajectory evaluation before release for exactly this
reason.

| Level | Measures | Use when |
|---|---|---|
| **Final answer** | Task success, quality of the output | Always — necessary, never sufficient |
| **Trajectory** | Tool selection, argument correctness, step count, redundant calls, recovery after an error | Any system that calls tools |
| **Step-wise** | Was *this* decision right given *this* state | Debugging a specific failure mode |

Trajectory metrics worth having: **tool-selection accuracy** (right tool for the step),
**argument correctness** (right parameters — this catches most real bugs), **step efficiency**
(actual vs minimum steps), **recovery rate** (does it get back on track after a tool error?), and
**termination correctness** (does it stop, and stop for the right reason?).

## Task success criteria

The hard part of agent eval isn't computing a metric, it's defining success. In descending order of
preference:

1. **Programmatic check** — did the record get created with the right fields? Did the returned JSON
   validate? Cheap, deterministic, unambiguous. **Design tasks to be checkable this way.**
2. **Reference comparison** — exact match, or containment of required facts.
3. **Rubric-based judge** — for open-ended output, with an explicit rubric (below).
4. **Human review** — the ground truth everything else is calibrated against, and too slow to be the
   loop.

A task whose success can only be assessed by a human reading it is a task you'll evaluate three times
and then stop.

## LLM-as-judge — useful, and easy to fool yourself with

Judges scale, and they are measurement instruments that need validating like any other.

**Validate the judge before trusting it.** Have humans label 50–100 outputs, run the judge on the
same set, and measure agreement (Cohen's κ, or correlation for scalar scores). Below ~0.6 the judge
is measuring something else. **Report this number whenever you report judge scores** — an unvalidated
judge score is an unmarked estimate.

Known biases, all measurable:

| Bias | Effect | Mitigation |
|---|---|---|
| **Position** | Prefers the first (or last) option in a pairwise comparison | Randomise order; run both orders and check consistency |
| **Verbosity** | Prefers longer answers regardless of quality | Rubric scores length explicitly, or control for it |
| **Self-preference** | Prefers output from its own model family | Judge with a different model than the one generating |
| **Leniency drift** | Scores creep up over time | Anchor with fixed calibration examples in every run |

Practice that works: **specific rubric with named criteria and a scale**, not "rate 1–10"; ask for
reasoning *before* the score; use pairwise comparison rather than absolute scoring where you can
(more reliable); pin the judge model and version (`M14`) — a judge that silently updates invalidates
every historical comparison.

## RAG-specific metrics

Decompose, because "the answer was wrong" has three different causes with three different fixes:

- **Retrieval quality** — recall@k, precision@k, MRR. *Were the right documents fetched?* If not,
  nothing downstream can be right.
- **Groundedness / faithfulness** — is every claim supported by the retrieved context? This is the
  hallucination metric that matters.
- **Answer relevance** — does it address the question asked?
- **Context sufficiency** — did retrieval return enough to answer at all? Distinguishes "the model
  failed" from "the corpus doesn't contain it."

## Safety and adversarial evals are a suite, not a checkbox

`M16`: a recorded red-team run is release evidence. Maintained as a **regression suite** alongside
the capability evals, so a fix stays fixed:

- Prompt-injection resistance (direct and indirect — the indirect cases matter more)
- Tool-misuse attempts: can it be talked into a destructive call?
- Data-boundary tests: cross-tenant retrieval, PII in output
- Refusal correctness — both over- and under-refusal
- Jailbreak corpus regression

Attack generation lives in `llm-red-teaming`; this skill covers scoring them and gating on them.

## CI regression gates

```
eval:
  - capability suite   -> task success ≥ baseline − tolerance
  - trajectory suite   -> tool-call accuracy ≥ threshold
  - safety suite       -> zero regressions, hard fail
  - cost/latency       -> p95 and cost/request within budget
```

Gate on **the safety suite absolutely** (any regression fails) and on capability **relative to a
recorded baseline with a tolerance**, because LLM outputs are non-deterministic and a hard threshold
flaps. Pin `temperature=0` where the API supports it, fix seeds where available, and **run n≥3 and
report mean ± sd** — a single run cannot distinguish a regression from sampling noise (`statistics`).

## Online evaluation

Offline evals drift from reality. In production: sample real traffic for judge scoring, track the
quality SLI (`reliability-sre` `R1`), collect implicit signals (retries, abandonment, thumbs-down,
escalation to a human), and feed every production failure back into the offline set. A/B a prompt or
model change with a pre-registered metric and horizon (`statistics`) — peeking at an LLM A/B until it
looks good is the most common way a "win" is manufactured.

## Gotchas

- **Testing on the examples you built from.** Same leakage rule as `datasets`: an eval set you
  iterated against is a training set. Hold out a set you touch once.
- **A single aggregate number.** 87% task success hides that it fails every multi-step case. Slice
  by task type, difficulty, and tenant.
- **Judge validated once, then trusted forever.** Re-validate when the judge model changes — which
  happens without you if it isn't pinned.
- **Benchmark scores as evidence about your system.** Public benchmarks are contaminated and measure
  a different distribution. Your eval set is the evidence.
- **Ignoring cost and latency in the eval.** A change that improves quality 2% and triples cost is a
  decision, not an improvement — report all three together.
- **No inter-run variance.** Report mean ± sd across seeds; a 1-point "gain" inside the noise band
  is not a gain.
