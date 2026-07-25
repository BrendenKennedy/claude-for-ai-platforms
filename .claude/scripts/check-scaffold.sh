#!/usr/bin/env bash
# check-scaffold.sh — the scaffold's self-consistency check. Run locally or from CI.
#
# A scaffold's product is internal consistency: the map (CLAUDE.md, README.md) must match the
# territory (.claude/). Both real bugs in this repo's history were drift of exactly that kind —
# a .gitignore that silently swallowed the datasets skill, and a README that missed /bootstrap
# and the pipelines skill. This script makes that class of bug fail loudly.
#
# Checks:
#   1. DRIFT      — every real skill / command / agent on disk is named in CLAUDE.md AND README.md
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
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

fails=0
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
ok()   { printf 'ok    %s\n' "$1"; }

# ---- 1. DRIFT: disk -> docs -------------------------------------------------
for dir in .claude/skills/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_example" ] && continue
  grep -q "$name" CLAUDE.md  || fail "skill '$name' exists on disk but is not in CLAUDE.md"
  grep -q "$name" README.md  || fail "skill '$name' exists on disk but is not in README.md"
done
for f in .claude/commands/*.md; do
  name="$(basename "$f" .md)"
  [ "$name" = "_TEMPLATE" ] && continue
  grep -q "/$name" CLAUDE.md || fail "command '/$name' exists on disk but is not in CLAUDE.md"
  grep -q "$name" README.md  || fail "command '/$name' exists on disk but is not in README.md"
done
for f in .claude/agents/*.md; do
  name="$(basename "$f" .md)"
  [ "$name" = "_TEMPLATE" ] && continue
  grep -q "$name" CLAUDE.md  || fail "agent '$name' exists on disk but is not in CLAUDE.md"
  grep -q "$name" README.md  || fail "agent '$name' exists on disk but is not in README.md"
done
ok "drift: skills/commands/agents on disk are all named in CLAUDE.md + README.md"

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
python3 - <<'PY' || fails=$((fails + 1))
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
ok "validity: frontmatter YAML parses; descriptions within the 1,536 cap; one-time commands delisted"

# ---- 3. CONFIG --------------------------------------------------------------
python3 - <<'PY' || fails=$((fails + 1))
import json, os, sys
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

for skill, state in cfg.get("skillOverrides", {}).items():
    if state == "on" and not os.path.isdir(f".claude/skills/{skill}"):
        print(f"FAIL  skillOverrides has '{skill}: on' but .claude/skills/{skill}/ does not exist"); bad += 1

sys.exit(bad)
PY
for f in .claude/hooks/*.sh; do bash -n "$f" || fail "$f does not parse (bash -n)"; done
for f in .claude/hooks/*.py; do python3 -m py_compile "$f" || fail "$f does not compile"; done
ok "config: settings.json parses; wired hooks exist, are executable, and compile; overrides are backed"

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

./install.sh "$tmp" >/dev/null || fail "install.sh exited nonzero"
dst_count="$(find "$tmp" -type f | wc -l)"
dst_ph="$(grep -rho '<PLACEHOLDER' "$tmp" | wc -l)"
[ "$dst_count" = "$src_count" ] || fail "install landed $dst_count files, expected $src_count"
[ "$dst_ph" = "$src_ph" ]       || fail "placeholders changed in transit: $src_ph -> $dst_ph"

rerun="$(./install.sh "$tmp" | grep -c '^  add:' || true)"
[ "$rerun" = "0" ] || fail "install.sh re-run added $rerun files — it must be idempotent"
ok "install: $dst_count files land, $dst_ph placeholders intact, re-run adds nothing"

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
  python3 .claude/scripts/build-reference.py "$tmp/REFERENCE.md" >/dev/null 2>&1
  if ! diff -q docs/REFERENCE.md "$tmp/REFERENCE.md" >/dev/null 2>&1; then
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
    CITED = re.compile(r"\[(LLM\d{2}|ASI\d{2}|CIS [\d.]+|SLSA[^\]]*|CICD-SEC-\d+)\]")
    for f in sorted(policy.glob("*.md")):
        for cite in {m.group(1) for m in CITED.finditer(f.read_text())}:
            key = cite.split()[0] if cite.startswith("CIS") else cite
            if key not in corpus:
                print(f"FAIL  {f.name} cites [{cite}] but no frameworks/ doc mentions it")
                bad += 1

sys.exit(1 if bad else 0)
PY
ok "governance: every canon file is registered; framework docs indexed; canon citations resolve"

# ---- verdict ----------------------------------------------------------------
echo
if [ "$fails" -gt 0 ]; then
  echo "check-scaffold: $fails failure(s)"; exit 1
fi
echo "check-scaffold: all checks passed"
