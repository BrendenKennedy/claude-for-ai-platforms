---
name: testing
description: >
  How verification works in THIS repo — the cheapest-to-costliest confidence ladder and the exact
  commands that work today. Carries: the real test runner + invocation, the offline-safe rule (unit
  tests need no env/service/network/GPU — stub the boundary), the ML confidence checks (tiny-data
  smoke: a forward pass + one train step on a 2-sample fixture; determinism; split-leakage; metric
  sanity), the live/GPU-smoke pattern (skips cleanly when its dependency is down, self-cleans),
  readiness checks, and environment preconditions. Load BEFORE running or writing a test, verifying
  a change, or claiming something works. Triggers: run tests, verify, does this work, test this
  change, pytest, uv run pytest, smoke test, offline test, readiness check, integration test, CI,
  forward-pass smoke, shape mismatch, determinism test, leakage test, overfit one batch, does the
  model train, cuda available.
---

# Testing & verification — how this repo actually checks a change

> On-demand: load this before running or writing a test, or before saying a change works. It carries
> the commands that work **today** — don't assume a runner or command that isn't wired up yet.

> The runner and conventions below are the scaffold's defaults (uv + pytest, `tests/`); they hold
> unless your project deliberately diverges. The `<PLACEHOLDER — /bootstrap fills this>` slots are
> project-specific — **`/bootstrap` back-fills them** when it generates the code they refer to.

## When this applies
Running the suite, adding a test, verifying a change end-to-end, or wiring CI later.

## Critical fact (the thing that surprises people)
**Run everything through `uv run`.** A bare `pytest` or `python` uses whatever interpreter happens to
be on PATH, not the locked env — tests then pass or fail against the wrong dependency set (see
`env-uv`). `uv run pytest`, never `pytest`.

## The verification ladder (cheapest → costliest)

1. **Compiles / imports + format (offline, no side effects).**
   `<PLACEHOLDER — /bootstrap fills this: uv run python -c "import <pkg>">` ·
   `uvx ruff format . && uvx ruff check .`
   (the `validate-python` hook already runs ruff on files as they're edited.)
2. **Unit tests (offline — no env, service, network, or GPU).**
   `uv run pytest` — the whole suite; one test: `uv run pytest tests/test_x.py::test_y -x`.
3. **Tiny-data smoke (offline, CPU-fallback — the ML unit of confidence).** A forward pass + one
   optimizer step on a **2-sample fixture** — catches shape / device / dtype bugs in seconds without
   touching real data or a GPU. See *ML confidence checks* below.
   `<PLACEHOLDER — /bootstrap fills this: uv run pytest tests/test_smoke.py>`
4. **Integration smokes (need a real GPU, or a service up).** Live round-trips that **skip cleanly if
   the dependency is unreachable** and delete anything they create. GPU readiness probe:
   `uv run python -c "import torch; print(torch.cuda.is_available())"` — a GPU test guards on that and
   skips, never fails, when False.
5. **Run it for real.** One epoch on the synthetic dataset:
   `uv run python train.py epochs=1` (fit-not-trained AD projects: `uv run python fit.py`) — then
   confirm the tracker run and the checkpoint on disk exist. Exit code 0 is not evidence.

## Platform & security checks (offline, fast, and they gate the session)

Same ladder position as the ML checks below — cheap, offline, and they catch the expensive class.
The `run-security-tests.sh` Stop hook runs this tier before a session can end, alongside the leakage
tests.

| Check | What it asserts | Runs |
|---|---|---|
| **Manifest conformance** | Every generated manifest satisfies `platform-security.md` — PSS `restricted`, resource limits, digest-pinned images, no wildcard RBAC | `kubectl kustomize deploy/overlays/<env> \| conftest test -p policies/ -` |
| **Policy unit tests** | Each policy **rejects** a known-bad fixture and **passes** a known-good one. A policy with no failing fixture may be silently passing everything | `conftest verify -p policies/` |
| **IaC plan policy** | The Terraform *plan* (not the source) has no public exposure, wildcard IAM, or unencrypted storage | `terraform show -json tfplan \| conftest test -p policies/ -` |
| **Injection regression** | Every red-team finding that was ever fixed stays fixed. **Hard fail on any regression** | the safety suite in `evals/` (`llm-red-teaming` → `agent-evaluation`) |
| **Authorization tests** | A low-privilege principal cannot reach another tenant's objects. Test cross-tenant explicitly — testing only as an admin finds nothing | app test suite (`authn-authz` `I4`) |
| **Hook behaviour** | Each guard hook blocks its bad payload, allows its good one, and **fails open on malformed stdin** | pipe fixture JSON to `.claude/hooks/<name>` and assert the exit code |

The last row is the one people skip: a guard hook that crashes on unexpected input either blocks
everything or nothing, and both are discovered at the worst time. Every hook gets three cases —
blocks, allows, fails open.

## ML confidence checks (the cheap ones that catch the expensive bugs)
These are fast, offline, and CPU-only — they belong in the unit tier and buy far more confidence per
second than a full training run. They live in `tests/test_smoke.py` and `tests/test_leakage.py`.

- **Tiny-data smoke.** Build the model and a **2-sample** fixture (random tensors of the real shape, or
  two tiny real records), run one forward pass and one `loss.backward()` + `optimizer.step()`. Assert the
  output shape/dtype, that the loss is finite, and that at least one parameter's `.grad` is non-None. This
  catches shape mismatches, device/dtype errors, and broken graphs in seconds. Keep it on **CPU** — never
  require a GPU.
- **Overfit one batch** (same fixture). Loop the tiny-data step ~50–100 iterations on **one** batch and
  assert the loss drops to near-zero. If a model can't memorize a single batch, the training path is
  wired wrong — cheaper to catch here than after a real run.
- **Determinism.** Seed everything via
  `<PLACEHOLDER — /bootstrap fills this: <pkg>.seed.seed_everything>`, run the forward/one-step twice,
  and assert **identical** output/loss. A drift means an unseeded RNG or nondeterministic op —
  reproducibility is an always-on convention here, so this is a real test, not a nicety.
- **Split-leakage assertion.** Assert the train / val / test **index sets are pairwise disjoint** (and,
  where identity matters, that no group/patient/scene straddles splits). This ties to the `datasets`
  skill, which owns how splits are defined; the test enforces that they stay separate.
- **Metric sanity.** Feed a **known input** to the metric and assert the **known output** (e.g. a perfect
  prediction ⇒ metric at its ceiling, a fixed confusion case ⇒ the hand-computed value). Guards against a
  metric that silently returns a plausible-but-wrong number.

## Preconditions
- `<PLACEHOLDER — /bootstrap fills this: the .env keys the entry points need, e.g. DATA_ROOT, and the
  tracker URI — read them from .env.example>`.
- Unit tests need **none of that** — they must pass on a fresh clone with only `uv sync` run.
- Live checks gate on availability: if the dependency isn't up, smokes/readiness **skip** — they don't fail.

## Conventions
- Tests live in `tests/`, named `test_*.py` (what `/bootstrap` emits and pytest discovers by default).
- **Offline-safe is non-negotiable for unit tests.** Drive external boundaries through a stub — pytest's
  `monkeypatch` for env/attributes, tiny CPU tensors standing in for real batches — so no unit test hits
  the network, a dataset on disk, or a required GPU. Put anything live in a smoke that skips cleanly.
- **GPU/CUDA tests skip cleanly.** A test that genuinely needs the device guards on
  `torch.cuda.is_available()` and **skips (exit 0), never fails**, when it's False — the same
  skip-when-the-dependency-is-down pattern the live smokes use, so the suite stays green on a CPU box.
- Assert the **contract AND every rejection mode** (bad input, missing field, wrong type), and
  **round-trips** where they apply.
- Test-time knobs: override a module constant / inject a fake, and **restore it in a `finally`**.

## Adding CI later
Start from the shipped template `.claude/templates/project-ci.yml` (setup-uv → `uv sync --frozen` →
ruff → `uv run pytest`) — it runs exactly the offline tier, so everything above stays true unchanged;
GPU smokes stay local because they skip cleanly where there's no device.

## Gotcha
Do not run a command as if it works when it doesn't yet. This skill is how you **run** the checks; the
authoring rules for tests (where they live, the mock pattern) are a code convention — keep those in the
policy canon (`.claude/memory/policy/`, via the `governance` skill), not restated here.
