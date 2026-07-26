#!/usr/bin/env bash
# check-scaffold.sh — the scaffold's self-consistency check. Run locally or from CI.
#
# A scaffold's product is internal consistency: the map (CLAUDE.md, README.md) must match the
# territory (.claude/). Both real bugs in this repo's history were drift of exactly that kind —
# a .gitignore that silently swallowed the datasets skill, and a README that missed /bootstrap
# and the pipelines skill. This script makes that class of bug fail loudly.
#
# Checks (this list is canonical — README.md and CONTRIBUTING.md point here rather than restate it,
# because four hand-maintained copies of it had already drifted apart):
#   1. DRIFT      — every real skill / command / agent on disk is named in CLAUDE.md AND README.md
#   1b. TIER DRIFT — the always-on set marked up in CLAUDE.md + README.md matches what
#                   settings.json implies (a skill absent from skillOverrides is always-on)
#   2. FRONTMATTER — every SKILL.md / agent has name: + description:; SKILL.md name matches its dir
#   2b. VALIDITY  — every frontmatter block parses as real YAML (the bug class that bit twice),
#                   descriptions fit the 1,536-char listing truncation cap, and one-time
#                   commands/templates carry disable-model-invocation: true
#   3. CONFIG     — settings.json parses; every hook it wires exists, is executable, and compiles;
#                   every skillOverride set "on" has a skill directory backing it
#   4. INSTALL    — install.sh into a temp dir lands every file, re-run adds nothing (idempotent),
#                   and the <PLACEHOLDER> count survives the trip
#   5. OWNERSHIP  — every file carrying a <PLACEHOLDER> is claimed by /intake or /bootstrap (named
#                   in their fill lists) — an unclaimed placeholder is a blank nobody will ever fill
#   6. REFERENCE  — docs/REFERENCE.md is generated; regenerate and diff so it can't lie
#   7. GOVERNANCE — every canon file has a row in the governance skill's Policy index (an
#                   unregistered domain is unreachable — nothing surfaces it)
#   8. FRAMEWORKS — every framework doc is in the lineage table, and every framework id cited in
#                   canon resolves to a doc that mentions it
#   9. CITATIONS  — every canon rule id cited in a skill/agent/command resolves to a defined rule;
#      + TEMPLATES  and the shipped k8s baseline passes the shipped conftest policies (skipped
#                   silently when conftest isn't installed)
#  10. CI         — every check-* script in .claude/scripts/ is actually invoked by CI (the README
#                   claimed "CI runs both" while check-hooks.py was invoked by nothing)
#  11. HOOK COVER — every hook has cases in check-hooks.py AND a fail-open case; coverage counted
#                   in tool paths, not in claims (two hooks had none while three files said all did)
#  12. MECHANISMS — every file a framework doc names in "How it lands here" exists; a control whose
#                   enforcing mechanism is missing is decoration (frameworks/README.md rule 3)
#  13. REF NOTES  — every memory/reference/ note is registered in CLAUDE.md (mirror of check 7 —
#                   an unregistered note is unreachable)
#  13b. PROCESS   — PROCESS.md's version header matches its own newest changelog entry (its Part V
#                   rule 4 asks for both, and it has shipped disagreeing twice)
#  14. INDEXES    — templates/, scripts/, memory/ and docs/ each name every file they hold in their
#                   own README (templates/ had documented 6 of 20; scripts/ named none of its three)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

fails=0
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
ok()   { printf 'ok    %s\n' "$1"; }

# ---- 1. DRIFT: disk -> docs -------------------------------------------------
# CLAUDE.md ships into every project; README.md does NOT (install.sh copies .claude/, CLAUDE.md and
# PROCESS.md only). So the README half runs in the scaffold repo only — recognizable by install.sh
# at the root, the same idiom check 6 uses. Without this the whole suite reported ~90 failures in a
# perfectly healthy installed project, which is why nobody could run it there.
in_scaffold_repo=false
[ -f install.sh ] && [ -f README.md ] && in_scaffold_repo=true
readme_drift() { # $1 = kind, $2 = name, $3 = grep needle
  $in_scaffold_repo || return 0
  grep -q "$3" README.md || fail "$1 '$2' exists on disk but is not in README.md"
}
for dir in .claude/skills/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_example" ] && continue
  grep -q "$name" CLAUDE.md  || fail "skill '$name' exists on disk but is not in CLAUDE.md"
  readme_drift skill "$name" "$name"
done
for f in .claude/commands/*.md; do
  name="$(basename "$f" .md)"
  [ "$name" = "_TEMPLATE" ] && continue
  grep -q "/$name" CLAUDE.md || fail "command '/$name' exists on disk but is not in CLAUDE.md"
  readme_drift command "/$name" "$name"
done
for f in .claude/agents/*.md; do
  name="$(basename "$f" .md)"
  [ "$name" = "_TEMPLATE" ] && continue
  grep -q "$name" CLAUDE.md  || fail "agent '$name' exists on disk but is not in CLAUDE.md"
  readme_drift agent "$name" "$name"
done
# Hooks and scripts were never drift-checked against the docs — only their settings.json wiring
# was (check 3). A hook could ship documented nowhere and CI stayed green. Matched on the STEM,
# because the docs name hooks both ways (`session-orient` in README's list, `session-orient.py`
# in CLAUDE.md's table) and both are legitimate.
drift_before=$fails
for f in .claude/hooks/*.sh .claude/hooks/*.py; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"; stem="${name%.*}"
  grep -q "$stem" CLAUDE.md || fail "hook '$name' exists on disk but is not in CLAUDE.md"
  readme_drift hook "$name" "$stem"
done
for f in .claude/scripts/*.sh .claude/scripts/*.py; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  grep -q "$name" CLAUDE.md || fail "script '$name' exists on disk but is not in CLAUDE.md"
done
if [ "$fails" -eq "$drift_before" ]; then
  ok "drift: skills/commands/agents/hooks/scripts on disk are all named in the docs"
fi

# ---- 1b. TIER DRIFT: settings.json -> docs -----------------------------------
# Check 1 proves a skill is NAMED in the docs. It does not prove it is named in the right TIER, and
# that gap shipped: v1.4.0 gated the security spine and the DS core, and the README went on
# advertising an "Always-on security & platform spine" while CI stayed green. A front door that
# misstates what you pay context for is worse than one that omits it.
# Source of truth: a skill is always-on iff it is NOT a key in settings.json's skillOverrides.
python3 - <<'PY'
import json, pathlib, re, sys

settings = json.loads(pathlib.Path(".claude/settings.json").read_text())
gated = set(settings.get("skillOverrides", {}))
on_disk = {p.parent.name for p in pathlib.Path(".claude/skills").glob("*/SKILL.md")} - {"_example"}
always_on = on_disk - gated

problems = []
# README.md is the scaffold repo's own and doesn't ship; CLAUDE.md does. Check whichever exist.
docs = [d for d in ("README.md", "CLAUDE.md") if pathlib.Path(d).is_file()]
for doc in docs:
    text = pathlib.Path(doc).read_text()
    # Explicit markers, not a prose regex. The first version of this check scanned from the phrase
    # "always-on" to the next line mentioning "gated" — which broke on a list that soft-wrapped onto
    # the "gated" sentence, and would have broken again on CLAUDE.md, whose always-on label literally
    # reads "the only tier that is never gated". A check that depends on line-wrapping is a check
    # someone deletes the second time it cries wolf. HTML comments render as nothing and say what
    # they are for.
    m = re.search(r"(?s)<!-- always-on:start -->(.*?)<!-- always-on:end -->", text)
    if not m:
        problems.append(f"{doc}: missing <!-- always-on:start/end --> markers around the always-on skill list")
        continue
    block = m.group(1)
    listed = set(re.findall(r"`([a-z][a-z0-9-]+)`", block)) & on_disk
    for missing in sorted(always_on - listed):
        problems.append(f"{doc}: '{missing}' is always-on (not in skillOverrides) but not listed in the always-on tier")
    for wrong in sorted(listed - always_on):
        problems.append(f"{doc}: '{wrong}' is listed as always-on but IS gated in skillOverrides")

if problems:
    print("\n".join("  " + p for p in problems), file=sys.stderr)
    sys.exit(1)
PY
tier_status=$?
if [ "$tier_status" -ne 0 ]; then
  fail "tier drift: the always-on skill tier in the docs disagrees with settings.json"
else
  ok "tiers: the always-on set in the docs matches settings.json skillOverrides"
fi

# ---- 2. FRONTMATTER ---------------------------------------------------------
for f in .claude/skills/*/SKILL.md; do
  dir_name="$(basename "$(dirname "$f")")"
  [ "$dir_name" = "_example" ] && continue
  head -1 "$f" | grep -q '^---$' || { fail "$f has no frontmatter"; continue; }
  fm_name="$(awk '/^name:/{print $2; exit}' "$f")"
  [ "$fm_name" = "$dir_name" ] || fail "$f frontmatter name '$fm_name' != dir '$dir_name'"
  grep -q '^description:' "$f" || fail "$f has no description: (skills surface by description)"
done
for f in .claude/agents/*.md; do
  [ "$(basename "$f")" = "_TEMPLATE.md" ] && continue
  grep -q '^name:' "$f"        || fail "$f has no name: frontmatter"
  grep -q '^description:' "$f" || fail "$f has no description: (agents dispatch by description)"
done
ok "frontmatter: every skill/agent has name + description; skill names match their dirs"

# ---- 2b. VALIDITY: YAML + budgets + delisting -------------------------------
# Invalid frontmatter shipped twice in this repo's history (see CHANGELOG 0.10.0) while check 2's
# grep-level look passed. This parses every block for real and enforces the description budget.
python3 - <<'PY'
import re, sys
from pathlib import Path
try:
    import yaml
except ImportError:
    yaml = None
bad = 0
CAP = 1536
MUST_DISABLE = {
    ".claude/commands/setup.md", ".claude/commands/intake.md", ".claude/commands/bootstrap.md",
    ".claude/commands/_TEMPLATE.md", ".claude/skills/_example/SKILL.md",
}
files = (list(Path(".claude/skills").glob("*/SKILL.md"))
         + list(Path(".claude/agents").glob("*.md"))
         + list(Path(".claude/commands").glob("*.md")))
for p in sorted(files):
    text = p.read_text()
    m = re.match(r"(?s)\A---\n(.*?)\n---\n", text)
    if not m:
        print(f"FAIL  {p}: no frontmatter block"); bad += 1; continue
    fm = m.group(1)
    data = {}
    if yaml is not None:
        try:
            data = yaml.safe_load(fm) or {}
        except Exception as e:
            print(f"FAIL  {p}: frontmatter is not valid YAML — {str(e).splitlines()[0]}"); bad += 1
            continue
    desc = data.get("description") or ""
    if isinstance(desc, str) and len(desc) > CAP:
        print(f"FAIL  {p}: description {len(desc)} chars exceeds the {CAP} truncation cap"); bad += 1
    if str(p) in MUST_DISABLE and "disable-model-invocation: true" not in fm:
        print(f"FAIL  {p}: one-time command/template must carry disable-model-invocation: true"); bad += 1
if yaml is None:
    print("note  pyyaml unavailable — YAML validity checked structurally only")
sys.exit(1 if bad else 0)
PY
if [ $? -eq 0 ]; then
  ok "validity: frontmatter YAML parses; descriptions within the 1,536 cap; one-time commands delisted"
else
  fail "validity: frontmatter/description/delisting checks failed (see above)"
fi

# ---- 3. CONFIG --------------------------------------------------------------
# Status is captured below (cfg_status), NOT with `|| fails=...` — `fail` already increments, so
# doing both double-counts.
python3 - <<'PY'
import glob, json, os, re, sys
root = os.getcwd()
try:
    cfg = json.load(open(".claude/settings.json"))
except Exception as e:
    sys.exit(f"FAIL  settings.json does not parse: {e}")

bad = 0
for event, entries in cfg.get("hooks", {}).items():
    for entry in entries:
        for hook in entry.get("hooks", []):
            path = hook["command"].replace("$CLAUDE_PROJECT_DIR", root)
            if not os.path.isfile(path):
                print(f"FAIL  hook wired for {event} does not exist: {path}"); bad += 1
            elif not os.access(path, os.X_OK):
                print(f"FAIL  hook is not executable: {path}"); bad += 1

# Both states, not just "on": a stale "off" key pointing at a deleted skill is a silent no-op.
for skill, state in cfg.get("skillOverrides", {}).items():
    if not os.path.isdir(f".claude/skills/{skill}"):
        print(f"FAIL  skillOverrides has '{skill}: {state}' but .claude/skills/{skill}/ does not exist"); bad += 1

# Agent skill preloads: they must resolve, and they must not name a skill this profile has OFF.
# A subagent has no Skill tool, so an off preload is content the agent can never recover.
overrides = cfg.get("skillOverrides", {})
for path in sorted(glob.glob(".claude/agents/*.md")):
    if os.path.basename(path) == "_TEMPLATE.md":
        continue
    m = re.search(r"(?m)^skills:\s*(.+)$", open(path).read())
    if not m:
        continue
    for name in [s.strip() for s in m.group(1).split(",") if s.strip()]:
        if not os.path.isdir(f".claude/skills/{name}"):
            print(f"FAIL  {path} preloads skill '{name}', which does not exist"); bad += 1
        elif overrides.get(name) == "off":
            print(f"FAIL  {path} preloads '{name}', which is \"off\" in skillOverrides"); bad += 1

# A shebang is a promise the file can be executed. install.sh chmods the target tree, so this
# drift is invisible in every installed project and only ever shows up here.
for path in sorted(glob.glob(".claude/hooks/*") + glob.glob(".claude/scripts/*")):
    if not os.path.isfile(path):
        continue
    with open(path, "rb") as fh:
        if fh.read(2) == b"#!" and not os.access(path, os.X_OK):
            print(f"FAIL  {path} starts with a shebang but is not executable"); bad += 1

sys.exit(bad)
PY
cfg_status=$?
before=$fails
for f in .claude/hooks/*.sh; do bash -n "$f" || fail "$f does not parse (bash -n)"; done
for f in .claude/hooks/*.py; do python3 -m py_compile "$f" || fail "$f does not compile"; done
if [ "$cfg_status" -eq 0 ] && [ "$fails" -eq "$before" ]; then
  ok "config: settings.json parses; hooks + preloads + shebangs are backed and compile"
else
  [ "$cfg_status" -ne 0 ] && fail "config: settings.json wiring check failed (see above)"
fi

# ---- 4. INSTALL -------------------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# The find filter here MUST mirror install.sh's. install.sh excludes this repo's memory INSTANCE
# content (dated session notes + the live roadmap/scaffold-journal) and re-seeds blank roadmap +
# scaffold-journal from templates/memory/. The roadmap/journal exclusion+reseed cancels 1:1 (still
# one of each in the target), so only the dated session notes actually change the count — exclude
# just those here to keep src and dst in agreement.
src_count="$(find .claude -type f ! -name '*.py[co]' ! -path '*/__pycache__/*' \
  ! -path '*/memory/sessions/[0-9]*' | wc -l)"
src_count=$((src_count + 3))  # + CLAUDE.md + PROCESS.md + the version stamp
src_ph="$(grep -rho --exclude-dir=__pycache__ '<PLACEHOLDER' .claude CLAUDE.md PROCESS.md | wc -l)"

# There is no install.sh in an installed project — this check is the scaffold repo's own.
if $in_scaffold_repo; then
  ./install.sh "$tmp" >/dev/null || fail "install.sh exited nonzero"
  dst_count="$(find "$tmp" -type f | wc -l)"
  dst_ph="$(grep -rho '<PLACEHOLDER' "$tmp" | wc -l)"
  [ "$dst_count" = "$src_count" ] || fail "install landed $dst_count files, expected $src_count"
  [ "$dst_ph" = "$src_ph" ]       || fail "placeholders changed in transit: $src_ph -> $dst_ph"

  rerun="$(./install.sh "$tmp" | grep -c '^  add:' || true)"
  [ "$rerun" = "0" ] || fail "install.sh re-run added $rerun files — it must be idempotent"
  ok "install: $dst_count files land, $dst_ph placeholders intact, re-run adds nothing"
fi

# ---- 5. PLACEHOLDER OWNERSHIP -------------------------------------------------
# A <PLACEHOLDER> is a promise that something fills it. The fillers are /intake §3, /bootstrap §6,
# and their human-decision lists — all live in the two command files. So: every file carrying a
# placeholder must be findable from those commands (by path, filename, or parent dir name).
unowned=0
while IFS= read -r f; do
  case "$f" in
    */_example/*|*_TEMPLATE*|*/check-scaffold.sh) continue ;;  # templates + this script's own grep strings
  esac
  rel="${f#./}"
  base="$(basename "$f" .md)"
  parent="$(basename "$(dirname "$f")")"
  # For skills the filename is always SKILL.md — a meaningless key that matches the commands' own
  # prose. The identifying name is the parent dir; use it in place of the base.
  [ "$base" = "SKILL" ] && base="$parent"
  if ! grep -qF -e "$rel" -e "$base" -e "$parent" \
       .claude/commands/intake.md .claude/commands/bootstrap.md; then
    fail "unowned placeholders: $rel has <PLACEHOLDER>s but neither /intake nor /bootstrap names it"
    unowned=$((unowned + 1))
  fi
done < <(grep -rl --exclude-dir=__pycache__ '<PLACEHOLDER' .claude CLAUDE.md README.md 2>/dev/null)
[ "$unowned" -eq 0 ] && ok "ownership: every placeholder-carrying file is claimed by /intake or /bootstrap"

# ---- 6. REFERENCE INDEX -----------------------------------------------------
# docs/REFERENCE.md is generated from frontmatter; a hand-edit or a frontmatter change without a
# regen makes it lie. Rebuild to a temp file and diff. docs/ is the scaffold repo's own (not
# shipped by install.sh), so in an installed project this check skips silently — the scaffold
# repo is recognizable by install.sh at its root.
if [ -f docs/REFERENCE.md ]; then
  # Capture the generator's own status: a crashed generator leaves no temp file, and reporting
  # that as "stale" points at the wrong cause.
  if ! python3 .claude/scripts/build-reference.py "$tmp/REFERENCE.md" >/dev/null 2>&1; then
    fail "build-reference.py failed to run — docs/REFERENCE.md could not be verified"
  elif ! diff -q docs/REFERENCE.md "$tmp/REFERENCE.md" >/dev/null 2>&1; then
    fail "docs/REFERENCE.md is stale — regenerate: python3 .claude/scripts/build-reference.py"
  else
    ok "reference: docs/REFERENCE.md matches the frontmatter (regenerated + diffed)"
  fi
elif [ -f install.sh ]; then
  fail "docs/REFERENCE.md missing — generate: python3 .claude/scripts/build-reference.py"
fi

# ---- 7. GOVERNANCE: canon is registered, and 8. FRAMEWORKS: citations resolve -----
# Two failure modes this catches, both silent otherwise:
#   - a canon file nobody can find, because the governance skill's index has no row for it. An
#     unregistered domain is unreachable: nothing surfaces governance for a change it should govern.
#   - a canon rule citing a framework control id that resolves to nothing. This fork lets canon cite
#     ids ([LLM01], [CIS 5.2]) with the framework text living in policy/frameworks/ — that only
#     works if the citation actually lands somewhere.
python3 - <<'PY' || fails=$((fails + 1))
import re, sys
from pathlib import Path

bad = 0
policy = Path(".claude/memory/policy")
frameworks = policy / "frameworks"
gov = Path(".claude/skills/governance/SKILL.md")

# 7. Every canon file has a row in the governance skill's Policy index.
if gov.is_file():
    gov_text = gov.read_text()
    # Reference files carry no rules and are described separately, not as index rows.
    reference = {"README.md", "compliance-crosswalk.md"}
    for f in sorted(policy.glob("*.md")):
        if f.name in reference or f.name.endswith("-decision-log.md"):
            continue
        if f.name not in gov_text:
            print(f"FAIL  canon {f.name} has no row in the governance skill's Policy index")
            bad += 1
    if not frameworks.is_dir():
        print("FAIL  .claude/memory/policy/frameworks/ is missing")
        bad += 1

# 8a. Every framework doc is listed in the frameworks README (its lineage table).
readme = frameworks / "README.md"
if readme.is_file():
    listed = readme.read_text()
    for f in sorted(frameworks.glob("*.md")):
        if f.name == "README.md":
            continue
        if f.name not in listed:
            print(f"FAIL  framework doc {f.name} is not in frameworks/README.md's lineage table")
            bad += 1
elif frameworks.is_dir():
    print("FAIL  frameworks/README.md is missing — the lineage table is the index")
    bad += 1

# 8b. Framework ids cited in canon resolve to a doc that mentions them.
if frameworks.is_dir():
    corpus = "\n".join(p.read_text() for p in frameworks.glob("*.md"))
    # Only ids with a stable, greppable shape. Prose citations ([SRE], [PSS]) are not checked.
    CITED = re.compile(r"\[(LLM\d{2}|ASI\d{2}|CIS [\d.x–\-]+|SLSA[^\]]*|CICD-SEC-\d+)\]")
    cis_doc = (frameworks / "cis-kubernetes.md")
    cis_text = cis_doc.read_text() if cis_doc.is_file() else ""
    for f in sorted(policy.glob("*.md")):
        for cite in {m.group(1) for m in CITED.finditer(f.read_text())}:
            if cite.startswith("CIS"):
                # `cite.split()[0]` reduced every CIS citation to the bare string "CIS", which is
                # present unconditionally — so `[CIS 99.99]` resolved and the check was vacuous for
                # the entire CIS family. Canon cites at SECTION granularity (`[CIS 5.2]`, `[CIS 5.x]`,
                # `[CIS 1–3]`), and the framework doc documents sections 1-5, so verify the section
                # numbers exist. Narrower than a per-control check and honestly so: it catches a
                # citation to a section that doesn't exist, not a wrong control within one.
                sections = {int(n) for n in re.findall(r"\d+", cite.split(None, 1)[1])[:1] or []}
                sections |= {int(n) for n in re.findall(r"[–-](\d+)", cite)}
                unknown = {s for s in sections if not re.search(rf"(?m)^\|\s*{s}\s*\||§{s}", cis_text)}
                if unknown or not sections:
                    print(f"FAIL  {f.name} cites [{cite}] but cis-kubernetes.md documents no such section")
                    bad += 1
            elif cite not in corpus:
                print(f"FAIL  {f.name} cites [{cite}] but no frameworks/ doc mentions it")
                bad += 1

sys.exit(1 if bad else 0)
PY
ok "governance: every canon file is registered; framework docs indexed; canon citations resolve"

# ---- 9. CITATIONS + SHIPPED TEMPLATES ---------------------------------------
# 9a. Canon rule ids cited in skills/agents/commands must resolve to a rule that exists.
#     Citations accumulate fast (a skill cites D7, AI9, R4, C6...) and a renamed or renumbered rule
#     breaks them silently — the same drift class as checks 1 and 8.
#
#     Scoped to prefixes canon actually DEFINES. `F1` in the evaluation skill is the F1 score, not a
#     citation, and a check that flags it is a check someone deletes. So: derive the prefix set from
#     canon, then a `P12` (real prefix, missing rule) fails and an `F1` (no such prefix) is ignored.
#
# 9b. The shipped k8s templates must pass the shipped conftest policies. templates/k8s/ is the
#     hardened exemplar and templates/policies/ is the enforcement; if the first fails the second,
#     every project generated from them starts broken. Skipped silently when conftest is absent.
python3 - <<'PY'
import re, sys
from pathlib import Path

policy = Path(".claude/memory/policy")
defined = set()
for f in policy.glob("*.md"):
    t = f.read_text()
    defined |= set(re.findall(r"(?m)^##\s+([A-Z]{1,2}\d{1,2})\s+—", t))   # data-governance style
    defined |= set(re.findall(r"\*\*([A-Z]{1,2}\d{1,2})\s+—", t))          # model-governance style

if not defined:
    print("FAIL  no canon rule ids found — did the canon heading style change?")
    sys.exit(1)

prefixes = {re.match(r"([A-Z]{1,2})", r).group(1) for r in defined}
CITE = re.compile(r"`([A-Z]{1,2})(\d{1,2})`")

bad = 0
for d in ("skills", "agents", "commands"):
    for f in sorted(Path(f".claude/{d}").rglob("*.md")):
        for prefix, num in set(CITE.findall(f.read_text())):
            if prefix not in prefixes:
                continue                      # not a canon citation at all (e.g. `F1`)
            if prefix + num not in defined:
                print(f"FAIL  {f}: cites `{prefix}{num}` but no such rule is defined in canon")
                bad += 1
sys.exit(1 if bad else 0)
PY
cite_status=$?
# Only claim ok when it actually passed — a verifier that lies about one line is a verifier
# people stop reading. Checks 1, 2b and 3 now do the same.
if [ "$cite_status" -eq 0 ]; then
  ok "citations: every canon rule id cited in a skill/agent/command resolves"
else
  fails=$((fails + 1))
fi

if command -v conftest >/dev/null 2>&1; then
  pol=".claude/templates/policies/conftest"
  if ! conftest verify -p "$pol" >/dev/null 2>&1; then
    fail "shipped policies fail their own self-tests (conftest verify) — they may be enforcing nothing"
  elif ! conftest test -p "$pol" \
        .claude/templates/k8s/base/deployment.yaml \
        .claude/templates/k8s/base/rbac-and-service.yaml \
        .claude/templates/k8s/base/namespace-and-network.yaml >/dev/null 2>&1; then
    fail "shipped k8s templates FAIL the shipped conftest policies — the exemplar violates the enforcement"
  else
    ok "templates: shipped k8s baseline passes the shipped policies, and the policies reject their fixtures"
  fi
else
  echo "note  conftest not installed — skipping the template/policy conformance check (9b)"
fi

# ---- 10. CI -----------------------------------------------------------------
# The README told readers "CI runs both" while check-hooks.py was invoked by nothing. A claim
# about what CI runs is checkable, so check it. Installed projects get their own ci.yml from
# templates/project-ci.yml, which correctly does NOT run these — hence the install.sh guard.
if [ -f install.sh ] && [ -f .github/workflows/ci.yml ]; then
  ci_before=$fails
  for f in .claude/scripts/check-*.sh .claude/scripts/check-*.py; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    grep -q "$name" .github/workflows/ci.yml \
      || fail "$name exists but .github/workflows/ci.yml never runs it — a check nothing runs is decoration"
  done
  [ "$fails" -eq "$ci_before" ] && ok "ci: every check-* script in .claude/scripts/ is actually invoked by CI"
fi

# ---- 11. HOOK COVERAGE ------------------------------------------------------
# "Every hook has block/allow/fail-open cases" is asserted in README.md, CLAUDE.md AND
# settings.json. Two hooks had no fail-open case anyway. Coverage counted in claims is not
# coverage; parse the suite and count it for real.
python3 - <<'PY'
import ast, glob, os, sys

src = ".claude/scripts/check-hooks.py"
if not os.path.isfile(src):
    sys.exit(0)
covered, failopen = set(), set()
for node in ast.walk(ast.parse(open(src).read())):
    if not (isinstance(node, ast.Call) and getattr(node.func, "id", "") == "run"):
        continue
    if not node.args or not isinstance(node.args[0], ast.Constant):
        continue
    hook = node.args[0].value
    covered.add(hook)
    label = node.args[3].value if len(node.args) > 3 and isinstance(node.args[3], ast.Constant) else ""
    if any(k in str(label).lower() for k in ("fail-open", "fail open", "loop guard")):
        failopen.add(hook)

bad = 0
for path in sorted(glob.glob(".claude/hooks/*.py") + glob.glob(".claude/hooks/*.sh")):
    name = os.path.basename(path)
    if name not in covered:
        print(f"FAIL  hook {name} has no cases in check-hooks.py"); bad += 1
    elif name not in failopen:
        print(f"FAIL  hook {name} has no fail-open (or loop-guard) case — the behaviour nobody tests"); bad += 1
sys.exit(bad)
PY
if [ $? -eq 0 ]; then
  ok "hook coverage: every hook has cases in check-hooks.py, including a fail-open one"
else
  fail "hook coverage: a hook is untested or has no fail-open case (see above)"
fi

# ---- 12. MECHANISMS ---------------------------------------------------------
# frameworks/README.md's own rule 3: "How it lands here" must name a REAL mechanism, because a
# framework control with no enforcing file is decoration. One row cited templates/postmortem.md,
# a file that never existed. Scoped to frameworks/ deliberately — the same sweep over all of
# memory/ produces structured false positives (decision logs are created on first use, etc.).
python3 - <<'PY'
import glob, os, re, sys

index = {}
for dirpath, dirnames, filenames in os.walk("."):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "node_modules")]
    for fn in filenames:
        index.setdefault(fn, []).append(os.path.join(dirpath, fn).lstrip("./"))

bad = 0
for path in sorted(glob.glob(".claude/memory/policy/frameworks/*.md")):
    if os.path.basename(path) == "README.md":
        continue
    text = open(path).read()
    m = re.search(r"(?ms)^##\s*How it lands here\b(.*?)(?=^## |\Z)", text)
    if not m:
        continue
    for tok in re.findall(r"`([\w./@-]+\.(?:md|ya?ml|json|rego|toml|sh|py))`", m.group(1)):
        base = os.path.basename(tok)
        if any(c.endswith(tok) for c in index.get(base, [])):
            continue
        print(f"FAIL  {path}: cites '{tok}' as an enforcing mechanism, but no such file exists"); bad += 1
sys.exit(bad)
PY
if [ $? -eq 0 ]; then
  ok "mechanisms: every file a framework doc names as its enforcement actually exists"
else
  fail "mechanisms: a framework doc cites an enforcing file that does not exist (see above)"
fi

# ---- 13. REFERENCE NOTES ----------------------------------------------------
# Mirror of check 7, for memory/reference/. An unregistered note is unreachable — nothing
# surfaces it. remote-gpu-workflow.md sat orphaned for five releases.
ref_before=$fails
for f in .claude/memory/reference/*.md; do
  name="$(basename "$f")"
  [ "$name" = "README.md" ] && continue
  grep -q "$name" CLAUDE.md \
    || fail "memory/reference/$name is not registered in CLAUDE.md — nothing will ever surface it"
done
[ "$fails" -eq "$ref_before" ] && ok "reference notes: every memory/reference/ note is registered in CLAUDE.md"

# ---- 13b. PROCESS VERSION ---------------------------------------------------
# PROCESS.md Part V rule 4 says "bump the version, one-line changelog entry". The document that
# states that rule has now shipped twice with a header version older than its own newest changelog
# entry (0.2.0 vs 0.3.0, then 1.0.0 vs the 1.4.0 §3.9 rewrite). Self-consistency within one file.
python3 - <<'PY'
import re, sys, os

if not os.path.isfile("PROCESS.md"):
    sys.exit(0)
text = open("PROCESS.md").read()
hdr = re.search(r"\*\*Version:\*\*\s*(\d+\.\d+\.\d+)", text)
log = re.search(r"(?ms)^### Changelog\s*```\s*\n\s*(\d+\.\d+\.\d+)\s*\(", text)
if not hdr or not log:
    print("FAIL  PROCESS.md: could not find its version header or its changelog block")
    sys.exit(1)
if hdr.group(1) != log.group(1):
    print(f"FAIL  PROCESS.md header says {hdr.group(1)} but its newest changelog entry is "
          f"{log.group(1)} — Part V rule 4 asks for both")
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  ok "process version: PROCESS.md's header matches its own newest changelog entry"
else
  fail "process version: PROCESS.md's header and changelog disagree (see above)"
fi

# ---- 14. INDEXES ------------------------------------------------------------
# Four directories carry their own README index, and three of them had drifted: templates/
# documented 6 of 20 files, memory/ omitted two stores, scripts/ named none of its three scripts.
# Same shape as check 8a (framework docs must be in the lineage table) — the index is the map, and
# a map missing two thirds of the territory is worse than none.
idx_before=$fails
idx() { # $1 = index file, $2... = files that must be named in it
  local index="$1"; shift
  [ -f "$index" ] || return 0
  for f in "$@"; do
    [ -f "$f" ] || continue
    grep -qF "$(basename "$f")" "$index" \
      || fail "$f is not named in $index — an unindexed file is one nobody finds"
  done
}
idx .claude/templates/README.md \
    .claude/templates/*.yaml .claude/templates/*.yml .claude/templates/*.json \
    .claude/templates/*.example .claude/templates/*.md \
    .claude/templates/k8s/base/* .claude/templates/k8s/overlays/prod/* \
    .claude/templates/policies/* .claude/templates/policies/conftest/*
idx .claude/scripts/README.md .claude/scripts/*.sh .claude/scripts/*.py
# memory/: the immediate children, which is what its Layout table covers.
for p in .claude/memory/*; do
  name="$(basename "$p")"
  [ "$name" = "README.md" ] && continue
  grep -qF "$name" .claude/memory/README.md \
    || fail ".claude/memory/$name is not in memory/README.md's Layout table"
done
# docs/ is the scaffold repo's own and isn't shipped — same guard idiom as check 6.
if [ -f install.sh ] && [ -f docs/README.md ]; then
  idx docs/README.md docs/*.md
fi
[ "$fails" -eq "$idx_before" ] && ok "indexes: templates/, scripts/, memory/ and docs/ each name every file they hold"

# ---- verdict ----------------------------------------------------------------
echo
if [ "$fails" -gt 0 ]; then
  echo "check-scaffold: $fails failure(s)"; exit 1
fi
echo "check-scaffold: all checks passed"
