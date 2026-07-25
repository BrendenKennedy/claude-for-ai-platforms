#!/usr/bin/env python3
"""PreToolUse(Edit|Write) hook: guard the agent's own tool surface — MCP servers and permissions.

Two tiers, matching the canon:

  BLOCK (exit 2) — an MCP server reference that cannot be pinned (`npx -y pkg` with no version,
  `@latest`, a floating container tag). `supply-chain.md` C8: servers are referenced by pinned
  version or digest, because a server can change the *tool descriptions* the model reads without
  changing anything a scanner looks at.

  ASK (permissionDecision) — adding or changing an MCP server, or widening `permissions.allow`.
  Both are legitimate and both are human decisions: an MCP server injects text straight into the
  model's instruction context, and `security.md` S8 says the agent never widens its own permissions.
  The ask fires in every permission mode, including bypassPermissions.

Scope: `.mcp.json`, `settings.json` / `settings.local.json` under `.claude/`, and agent definition
files under `.claude/agents/`.

Fail-open on anything unparseable: a guard that bricks the session is worse than a missed write.
"""

import json
import re
import sys
from pathlib import Path

UNPINNED = [
    (
        "npx without a version",
        re.compile(r"\"npx\"[^\]]*?\"(?:-y|--yes)\"\s*,\s*\"(@?[\w./-]+)\"(?!@)", re.S),
    ),
    ("@latest reference", re.compile(r"[\w./@-]+@latest")),
    (
        "mutable container tag",
        re.compile(r"\"(?:docker|podman)\"[^\]]*?\"([\w./-]+:latest)\"", re.S),
    ),
]


def ask(reason: str) -> int:
    """Emit an ask decision. stdout must contain ONLY this JSON."""
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )
    return 0


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool_input = payload.get("tool_input", {})
    path = tool_input.get("file_path", "")
    if not path:
        return 0
    name = Path(path).name
    parent = Path(path).parent.name

    is_mcp = name == ".mcp.json"
    is_settings = name in ("settings.json", "settings.local.json")
    is_agent = parent == "agents" and name.endswith(".md")
    if not (is_mcp or is_settings or is_agent):
        return 0

    text = (tool_input.get("content") or "") + (tool_input.get("new_string") or "")
    if not text:
        return 0

    # --- BLOCK tier: unpinnable server references -----------------------------------------
    if is_mcp or is_settings:
        for label, pattern in UNPINNED:
            m = pattern.search(text)
            if m:
                sys.stderr.write(
                    f"[guard-agent-config] Blocked {path} — {label}: "
                    f"{m.group(0)[:80]!r}\n\n"
                    "  An MCP server supplies tool descriptions that go straight into the model's\n"
                    "  instruction context. An unpinned server can change what its tools claim to do\n"
                    "  without changing its version — that is the rug-pull, and pinning is what makes\n"
                    "  the change reviewable.\n\n"
                    '  Pin it:  "@vendor/server@1.4.2"  or a digest-pinned container image.\n'
                    "  Canon: .claude/memory/policy/supply-chain.md C8  (see the `mcp-security` skill).\n"
                )
                return 2

    # --- ASK tier: human decisions ---------------------------------------------------------
    if is_mcp and "mcpServers" in text:
        return ask(
            "This adds or changes an MCP server. Its tool descriptions are read by the model as "
            "instructions, and it may hold credentials — supply-chain.md C8 makes adding one a "
            "human decision. Review the tool definitions (not just the README) before approving."
        )

    if is_settings and re.search(r"\"(allow|bypassPermissions|defaultMode)\"", text):
        return ask(
            "This changes the agent's own permission surface in "
            f"{name}. security.md S8: the agent never widens its own permissions — the deny list "
            "and allow list are human-owned. Confirm the change is what you intended."
        )

    if is_agent and re.search(r"^tools:.*\b(Write|Edit|Bash)\b", text, re.M):
        return ask(
            f"This grants write or shell tools to the subagent in {name}. ai-security.md AI2 "
            "(least agency): confirm this agent needs them, and that the grant is recorded in "
            ".claude/memory/process/agent-authority.md."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
