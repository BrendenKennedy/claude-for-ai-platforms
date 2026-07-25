#!/usr/bin/env bash
# Stop hook: the security regression tier runs before the session ends.
#
# Sibling of run-leakage-tests.sh, same reasoning at a different altitude: the checks that are cheap
# and decisive but that nobody runs unless something forces them. Three tiers, each skipped silently
# when its inputs or tooling are absent:
#
#   1. Manifest/IaC policy   — conftest against policies/ (the same policies CI and admission run)
#   2. Policy self-tests     — conftest verify: does each policy actually REJECT its bad fixture?
#   3. Safety regression     — pytest -k "security or injection or redteam": every red-team finding
#                              that was ever fixed stays fixed (llm-red-teaming -> agent-evaluation)
#
# A failure blocks the stop (exit 2) with the failing tail, so the regression is surfaced while the
# context that caused it is still loaded.
#
# Fail-open everywhere else: no policies/, no tests, no tooling, or a timeout -> exit 0 silently.
# A verification hook that bricks sessions teaches people to delete it.
set -uo pipefail

payload="$(cat 2>/dev/null || true)"

# Loop guard: a previous block already re-engaged the agent. Blocking again ping-pongs forever.
case "$payload" in
  *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;;
esac

dir="${CLAUDE_PROJECT_DIR:-.}"
cd "$dir" 2>/dev/null || exit 0

fail() {
  { echo "[run-security-tests] $1"; echo "$2" | tail -15; } >&2
  exit 2
}

# --- 1 + 2. Policy tests -----------------------------------------------------------------
if [ -d "policies" ] && command -v conftest >/dev/null 2>&1; then
  # Do the policies themselves still work? A policy with no failing fixture may be passing
  # everything silently — the most common failure in a policy repo.
  out="$(timeout 60 conftest verify -p policies/ 2>&1)"; status=$?
  [ "$status" -ne 0 ] && [ "$status" -ne 124 ] && [ "$status" -ne 127 ] \
    && fail "Policy self-tests FAILED — the policies may not be enforcing anything:" "$out"

  # Do the rendered manifests satisfy them?
  if [ -d "deploy" ] && command -v kubectl >/dev/null 2>&1; then
    for overlay in deploy/overlays/*/; do
      [ -d "$overlay" ] || continue
      rendered="$(timeout 60 kubectl kustomize "$overlay" 2>/dev/null)" || continue
      [ -z "$rendered" ] && continue
      out="$(printf '%s' "$rendered" | timeout 60 conftest test -p policies/ - 2>&1)"; status=$?
      [ "$status" -ne 0 ] && [ "$status" -ne 124 ] && [ "$status" -ne 127 ] \
        && fail "Manifest policy check FAILED for ${overlay} (platform-security canon):" "$out"
    done
  fi
fi

# --- 3. Safety / injection regression suite -----------------------------------------------
if [ -d "tests" ] || [ -d "evals" ]; then
  if command -v uv >/dev/null 2>&1; then
    if grep -rlqE "injection|redteam|red_team" tests evals 2>/dev/null; then
      out="$(timeout 180 uv run pytest -q -k "injection or redteam or red_team" \
              --no-header tests evals 2>&1)"; status=$?
      # 124 timeout, 127 missing tooling, 5 no tests collected — absence, not a regression.
      if [ "$status" -ne 0 ] && [ "$status" -ne 124 ] && [ "$status" -ne 127 ] && [ "$status" -ne 5 ]; then
        fail "Safety/injection regression suite FAILED — a previously-fixed finding is back:" "$out"
      fi
    fi
  fi
fi

exit 0
