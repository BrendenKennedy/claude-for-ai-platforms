# Tutorial — the Model path

Continues from [`TUTORIAL.md`](TUTORIAL.md), which covers install and `/setup`. You should have a
`conf/` tree, `train.py` and `eval.py` that run on a tiny fixture, and a passed P1 gate.

One thing worth checking before you go on: `/bootstrap` didn't just write those files, it **ran**
them — a forward pass and one training step on a two-sample fixture. Code that has never executed is
a guess about what will happen, and the whole point of proving the skeleton is that every later
"it should work" starts from something that did.

## 1. Watch a hook refuse you

Two guards fire on an empty project, so you can see the pattern before you've built anything.

Add a dependency by hand — open `pyproject.toml` and type a line into `[project.dependencies]`:

```
[guard-pyproject] Blocked: this Edit touches a dependency entry.
```

Deps go through `uv add`, which resolves and writes `uv.lock` in the same motion. A hand-edited
`pyproject.toml` and a stale lockfile is how "works on my machine" is manufactured, and the guard
exists because the failure surfaces weeks later on someone else's box.

Now save a notebook with its outputs intact:

```
[guard-notebook-outputs] Blocked: this .ipynb write carries cell outputs / execution counts.
Notebooks commit clean here (see the notebooks skill) — strip outputs first
(nbstripout, or clear outputs), then write.
```

Both messages follow the same shape as every guard here: name the **rule**, name the **fix**, and
point at the skill that carries the reasoning. A guard that only says "no" gets deleted rather than
argued with.

There's a third guard you won't see yet — `run-leakage-tests.sh` runs at **session end**, and any
test matching `leakage` that fails blocks the stop. It fails open when there are no such tests, no
`tests/`, or no `uv`, which means it does nothing until you've written the test that makes it bite.
That's §3.

## 2. Build the thing

Work conversationally; the skills load themselves. The place the canon earns its keep first is the
split — ask for one and `datasets` will insist it happens **once, with a fixed seed**, and that it's
a *group* or *temporal* split whenever samples share a source:

```python
splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED)
train_idx, test_idx = next(splitter.split(X, y, groups=patient_id))
```

Not a random row split over rows that share a patient, a session, or a device. If the same subject
appears on both sides, your test score is measuring memorisation and you will not find out until
production. It's the same distinction the platform path draws about tenant filtering: a control
versus a hope.

**Before you fund the modeling spend**, `eda` will push a cheap go/no-go: the predictive-signal
screen, run on **train only** — univariate AUC or mutual information per candidate feature, then a
quick cross-validated linear or shallow GBM read. A slate where the best single feature barely
clears chance is a loud warning. This check exists because a project run against this very scaffold
confirmed a near-random ceiling *late*, after P4 and P5, when a screen at P3 would have caught it.
That's recorded in the scaffold journal rather than quietly fixed.

Quick questions need no ceremony: *"what's the class balance here?"* is served directly — gates
govern project work, not curiosity.

## 3. Break it on purpose

Write the leakage test the Stop hook is waiting for. Ask for one and you'll get the cheap, decisive
version: assert the split index sets are disjoint, and that no group id appears on both sides.

```python
def test_no_group_leakage_between_splits():
    assert set(train_groups).isdisjoint(set(test_groups))
```

Now break the split on purpose — switch it to a plain random split — and try to end the session. The
Stop hook blocks with the failing tail. A leaked split never rides out quietly, and that is the
entire design intent: the check runs when you'd otherwise be walking away.

The other thing worth breaking early is the **baseline**. `PROCESS.md` won't let P5 close without
one, and the honest reason is that a model beating nothing is not a result. Fit the dumbest thing
that could work — majority class, last observed value, a single feature — and record it. Half the
value of the gate is the number of times the "real" model doesn't beat it.

## 4. The daily rhythm

- **`/review`** before committing — correctness plus the ML lens: device/dtype mismatches, tensor
  shapes, leakage, non-determinism, checkpoint/resume, unlogged config.
- **`/gate`** at phase boundaries — **expect your first BLOCKED verdict early**, usually on "baseline
  beaten" or "leakage checked." That's the system working: the debt is named, you keep working the
  phase, and nothing slides forward silently.
- **`/wrapup`** when you stop — the session note that lets tomorrow answer *"why is the split seeded
  at 1337?"*
- Every run goes through the tracker (`tracking-mlflow` by default), so *"where did that result go?"*
  has an answer. `model-governance.md` `M2` is blunt about why: record the run inputs at train time,
  don't reconstruct them later.

## 5. Prove it to someone else

`/report` assembles a deliverable from the repo's own records — every number cites a run id and a
config, every figure is regenerable from a script, and anything it can't back becomes
`[TODO: evidence]` rather than a plausible guess.

Two disciplines it will hold you to. **Uncertainty on every reported number** (`statistics`): three
seeds and a mean ± sd is the cheapest honest interval, and a difference smaller than seed noise is
not a result. And **`M11` — every released model ships a model card**: intended use, out-of-scope
use, training data, metrics with their slices, and the failure modes. `M10` asks for where it's
wrong, not just the averages, because the averages are the part that doesn't help anyone decide
whether to trust it.

## 6. Keep it current

- **`/skill-update`** after you upgrade a tool — syncs that skill's facts to the version you run.
  Every tool skill carries a `**Pinned:**` line for exactly this.
- **`/upgrade`** after a new scaffold release.
- After shipping, run the **retro** (PROCESS.md Part V) and the **`/scaffold-retro`**: edit the
  process itself with what the gates caught and missed. The process improving per project is the
  point of the whole system.

> **Going further than a model.** If the thing you built eventually needs to run somewhere — an
> endpoint, a cluster, a schedule — the platform half is already installed and gated off. Re-run
> `/intake` to flip the lanes on, and [`tutorial-platform.md`](tutorial-platform.md) picks up there.

## Where to go deeper

[REFERENCE.md](REFERENCE.md) — every skill/command/agent/hook, one line each ·
[PROCESS.md](../PROCESS.md) — the framework, its lineage, and the §3.9 security track ·
[`policy/`](../.claude/memory/policy/) — the canon, and the 20 framework documents behind it ·
[CONTRIBUTING.md](../CONTRIBUTING.md) — extending the scaffold, and the stability contract.
