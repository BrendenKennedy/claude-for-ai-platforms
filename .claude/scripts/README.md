# scripts — helper scripts for hooks & commands

Shell/Python helpers invoked by hooks (`../hooks/`), slash commands (`../commands/`), or run by
hand. Keeping them here (not in `hooks/`) separates *wiring* (a hook entry in `settings.json`) from
*logic* (the script it calls), so a command and a hook can share one script.

Conventions:
- Make scripts executable (`chmod +x`) and give them a `#!/usr/bin/env …` shebang.
- Reference them from `settings.json` / commands via `$CLAUDE_PROJECT_DIR/.claude/scripts/<name>`.
- Keep them fail-safe: a session-start or pre-tool script that errors shouldn't brick the session.

## What's here

| Script | Does | Run it when |
|---|---|---|
| `check-scaffold.sh` | The scaffold's self-consistency suite — the map (`CLAUDE.md`, `README.md`, `settings.json`) must match the territory (`.claude/`). Its header comment is the canonical list of checks. | Before any PR; CI runs it |
| `check-hooks.py` | Exercises every guard hook against crafted payloads: it blocks what it must, allows what it must, and **fails open** on malformed input. | After touching a hook; CI runs it |
| `build-reference.py` | Generates `docs/REFERENCE.md` from frontmatter. **Works in an installed project too** — `build-reference.py docs/REFERENCE.md` gives you an index of *your* active surface, honouring your `skillOverrides`. | After adding a skill/command/agent/hook |
