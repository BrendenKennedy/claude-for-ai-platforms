#!/usr/bin/env bash
# install.sh — drop the claude-for-ai-platforms skeleton into a target project.
#
# Usage:
#   ./install.sh [TARGET_DIR]        # default TARGET_DIR is the current directory
#
# Copies .claude/, CLAUDE.md, and PROCESS.md into TARGET. NEVER overwrites an existing file —
# already-present files are reported and skipped, so it's safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
# The README and docs/ deliberately don't ship into target projects; point at them instead.
REPO_URL="https://github.com/BrendenKennedy/claude-for-ai-platforms"

if [ ! -d "$TARGET" ]; then
  echo "error: target dir '$TARGET' does not exist" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

if [ "$TARGET" = "$SCRIPT_DIR" ]; then
  echo "error: refusing to install the scaffold into itself" >&2
  exit 1
fi

echo "Scaffolding Claude config into: $TARGET"
echo

copied=0
skipped=0

# Source set: every file under .claude/, plus the root CLAUDE.md and PROCESS.md
# (the phase-gate framework the process skill + /gate run against — it lives at
# the project root per its own 'How to use it' preamble so retros version it with the project).
while IFS= read -r src; do
  rel="${src#"$SCRIPT_DIR"/}"
  dest="$TARGET/$rel"
  if [ -e "$dest" ]; then
    printf '  skip (exists): %s\n' "$rel"
    skipped=$((skipped + 1))
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  printf '  add:           %s\n' "$rel"
  copied=$((copied + 1))
done < <(
  # Exclude bytecode: a dirty working tree (e.g. a compiled hook) must not ship .pyc into targets.
  # Also exclude THIS repo's own memory INSTANCE content — dated session notes, and the live
  # roadmap/scaffold-journal (full of this repo's dev history). A fresh project must start with
  # empty stores, not the scaffold-maker's backlog. The blank roadmap/journal are seeded from
  # templates/memory/ just below; the sessions/ dir still ships its README + _template.
  find "$SCRIPT_DIR/.claude" -type f ! -name '*.py[co]' ! -path '*/__pycache__/*' \
    ! -path '*/.claude/memory/sessions/[0-9]*' \
    ! -path '*/.claude/memory/roadmap.md' \
    ! -path '*/.claude/memory/scaffold-journal.md'
  echo "$SCRIPT_DIR/CLAUDE.md"
  echo "$SCRIPT_DIR/PROCESS.md"
)

# Seed the empty stores that were excluded above from their templates (never overwrite an existing
# one — same idempotency rule as the copy loop). This is what a fresh project fills in as it runs.
for seed in roadmap scaffold-journal; do
  seed_dest="$TARGET/.claude/memory/$seed.md"
  if [ -e "$seed_dest" ]; then
    printf '  skip (exists): %s\n' ".claude/memory/$seed.md"
    skipped=$((skipped + 1))
  else
    mkdir -p "$(dirname "$seed_dest")"
    cp "$SCRIPT_DIR/.claude/templates/memory/$seed.md" "$seed_dest"
    printf '  add:           %s\n' ".claude/memory/$seed.md"
    copied=$((copied + 1))
  fi
done

# Make hooks/scripts executable in the target (they're invoked directly).
find "$TARGET/.claude/hooks" "$TARGET/.claude/scripts" -type f \
  \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} + 2>/dev/null || true

# Stamp the scaffold version into the target. Unlike the files above, this IS overwritten on
# re-run — it records which scaffold version last touched this project, which is what makes a
# future "what's changed upstream?" diff possible at all.
version="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo unknown)"
sha="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
printf '%s (%s)\n' "$version" "$sha" > "$TARGET/.claude/scaffold-version"
echo
echo "Stamped .claude/scaffold-version: $version ($sha)"

echo
echo "Done: $copied added, $skipped skipped (already present)."
echo "Next: in Claude Code, run /setup — the whole sequence in one guided session"
echo "(git preflight → /intake → /bootstrap → /threat-model → /gate P1 → land + /wrapup, with a"
echo "checkpoint commit per stage). Or piecewise:"
echo "  1. /intake — the project-definition interview ('what are we building?'), the"
echo "     security-posture interview (data sensitivity, tenancy, exposure, agent autonomy), then"
echo "     your stack → skillOverrides + the stack placeholders. This is the one that shapes"
echo "     everything downstream: it picks which family and lane you're in."
echo "  2. /bootstrap — builds the skeleton the skills describe and proves it runs: deploy/ +"
echo "     policies/ + observability/ + evals/ for a platform lane, or the conf/ tree +"
echo "     train.py/eval.py for a model lane. Until then the skills document a project you"
echo "     don't have."
echo "  3. /threat-model — before the P1 gate, not after. A threat model produced now can still"
echo "     change the design cheaply; one produced at delivery is documentation."
echo "  4. Fill any remaining <PLACEHOLDER>s the setup commands list (architecture doc, policy domains,"
echo "     data-remote URL) — those need your decisions, not an agent's guess."
echo "  5. Edit .claude/settings.json permissions for this project's tools."
echo "  6. Rename .claude/skills/_example and the *_TEMPLATE.md files as you build real ones."
echo
echo "What landed here: .claude/ (skills, agents, commands, hooks, memory), CLAUDE.md (the index,"
echo "loaded every session — start there), and PROCESS.md (the phase gates /gate runs against)."
echo "The README, the tutorials, and docs/ stay upstream: $REPO_URL"
echo
echo "Verify any time — both scripts ship and both work in an installed project:"
echo "  bash .claude/scripts/check-scaffold.sh      # the scaffold's self-consistency checks"
echo "  python3 .claude/scripts/check-hooks.py      # every guard: blocks, allows, fails open"
echo "  python3 .claude/scripts/build-reference.py docs/REFERENCE.md"
echo "     ^ generates a component index from THIS project's skillOverrides — your active surface,"
echo "       not the scaffold's defaults."
