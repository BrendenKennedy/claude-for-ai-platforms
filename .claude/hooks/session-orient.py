#!/usr/bin/env python3
"""SessionStart hook: inject "where are we" orientation so a session never starts blind.

CLAUDE.md is the only file loaded every session; the live project state
(`.claude/memory/process/phase-state.md`, the latest session note, the roadmap) is NOT. Without
this, orientation depends on the `process`/`memory` skills happening to surface by description
match — probabilistic, which is exactly what the phase-gate design refuses for everything else
("enforced by structure, not discipline"). This hook makes it mechanical: on a fresh start it reads
the state files and hands the main session a compact briefing (current phase, open gate debt, what
the last session left, what's next) plus the standing kickoff questions.

Wired for the `startup|clear` sources only (see settings.json) — a mid-work `resume`/`compact` still
has the context, so re-injecting there would be noise.

No active project → silent. If `phase-state.md` says the project hasn't started (pre-`/intake`),
this emits nothing: quick one-off use of the scaffold stays ceremony-free, per PROCESS.md's
"ad-hoc asks don't gate" rule.

Fail-open on anything unparseable: a briefing hook that bricks startup teaches people to delete it.
"""

import json
import re
import sys
from pathlib import Path

MAX_SESSION_LINES = (
    12  # keep the injected briefing compact — this rides in context all session
)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


def section(text: str, heading: str) -> str:
    """Return the body under a `## heading` up to the next `## ` (or EOF)."""
    m = re.search(
        rf"^##\s+{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    return m.group(1).strip() if m else ""


def bullets(block: str, limit: int) -> list[str]:
    lines = [
        ln.rstrip() for ln in block.splitlines() if ln.strip().startswith(("-", "*"))
    ]
    return lines[:limit]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = {}

    root = Path(payload.get("cwd") or ".")
    # CLAUDE_PROJECT_DIR is the reliable anchor; fall back to cwd.
    import os

    root = Path(os.environ.get("CLAUDE_PROJECT_DIR", str(root)))
    proc = root / ".claude" / "memory" / "process"
    phase_file = proc / "phase-state.md"
    phase_text = read(phase_file)
    if not phase_text:
        return 0  # no process state → nothing to orient against

    # Current phase line.
    m = re.search(r"^\*\*Current phase:\*\*\s*(.+?)\s*$", phase_text, re.MULTILINE)
    phase = m.group(1).strip() if m else ""
    # No active project (pre-/intake) → stay silent so ad-hoc use isn't taxed.
    if not phase or "not started" in phase.lower():
        return 0

    parts: list[str] = []
    parts.append(f"**Current phase:** {phase}")

    # Open gate debt (only if there is any — "_None._" means clear).
    debt = section(phase_text, "Gate debt")
    if debt and debt.strip("_ ").lower() not in ("none.", "none"):
        parts.append("**Open gate debt:**\n" + debt)

    # Latest session note.
    sess_dir = root / ".claude" / "memory" / "sessions"
    notes = sorted(
        p
        for p in sess_dir.glob("20*.md")
        if p.name.lower() not in ("readme.md", "_template.md")
    )
    if notes:
        latest = notes[-1]
        txt = read(latest)
        focus = ""
        fm = re.search(r"\*\*Focus:\*\*\s*(.+?)\s*$", txt, re.MULTILINE)
        if fm:
            focus = fm.group(1).strip()
        state = section(txt, "State")
        followups = section(txt, "Follow-ups")
        lines = [f"**Last session** ({latest.stem}): {focus}".rstrip(":")]
        if state:
            lines.append("_State:_ " + " ".join(state.split())[:400])
        if followups:
            fu = bullets(followups, 3)
            if fu:
                lines.append("_Open follow-ups:_")
                lines.extend(fu)
        parts.append("\n".join(lines[:MAX_SESSION_LINES]))

    # Security & reliability posture. A threat model that nobody re-reads decays into fiction, and
    # an accepted risk past its review date has become permanent by default — both are invisible
    # unless something surfaces them, which is the same argument that justifies this hook at all.
    posture: list[str] = []

    tm = read(proc / "threat-model.md")
    if tm:
        vm = re.search(
            r"^\*\*(?:Version|Last reviewed|Updated):\*\*\s*(.+?)\s*$", tm, re.MULTILINE
        )
        stamp = vm.group(1).strip() if vm else "undated"
        gaps = bullets(section(tm, "Gaps"), 3)
        line = f"_Threat model:_ {stamp}"
        if "undated" in stamp:
            line += "  ← no date; treat as unverified"
        posture.append(line)
        if gaps:
            posture.append("_Open threat gaps:_")
            posture.extend(gaps)

    slo = read(proc / "slo-register.md")
    if slo:
        breached = [
            ln.rstrip()
            for ln in slo.splitlines()
            if re.search(r"(?i)\b(breach|exhausted|at risk|burning)\b", ln)
            and ln.strip().startswith("|")
        ]
        if breached:
            posture.append("_Error budget attention:_")
            posture.extend(breached[:3])

    # Expired exceptions: a decision log entry whose review date has passed.
    try:
        import datetime

        today = datetime.date.today().isoformat()
        expired = []
        for log in sorted(
            (root / ".claude" / "memory" / "policy").glob("*-decision-log.md")
        ):
            for ln in read(log).splitlines():
                dm = re.search(
                    r"review(?:ed)?(?:\s+by|:)?\s*(\d{4}-\d{2}-\d{2})", ln, re.I
                )
                if dm and dm.group(1) < today:
                    expired.append(f"- {log.stem}: {' '.join(ln.split())[:160]}")
        if expired:
            posture.append("_Policy exceptions past their review date:_")
            posture.extend(expired[:3])
    except Exception:
        pass

    if posture:
        parts.append("**Security & reliability**\n" + "\n".join(posture))

    # Roadmap: what's in progress + what's next.
    roadmap = read(root / ".claude" / "memory" / "roadmap.md")
    if roadmap:
        now = bullets(section(roadmap, "Now / in progress"), 3)
        nxt = bullets(section(roadmap, "Next"), 4)
        if now or nxt:
            rl = ["**Roadmap**"]
            if now:
                rl.append("_In progress:_")
                rl.extend(now)
            if nxt:
                rl.append("_Next:_")
                rl.extend(nxt)
            parts.append("\n".join(rl))

    briefing = (
        "## Session orientation (auto-injected from project state)\n\n"
        + "\n\n".join(parts)
        + "\n\n---\n"
        "**Before starting, confirm with the user:** (1) what are we doing this session? "
        "(2) is it project work or a one-off ad-hoc ask? (3) if project work — does it fit the "
        "current phase, and does it need a scope-ledger promotion (parking-lot → v1) or a branch? "
        "If the user's first message already answers these, skip the questions and proceed. "
        "If this is a quick one-off, ignore the phase framing — ad-hoc asks don't gate."
    )

    out = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": briefing,
        }
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
