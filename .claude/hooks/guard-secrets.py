#!/usr/bin/env python3
"""PreToolUse(Edit|Write) hook: block writes that embed a credential — secrets never enter tracked files.

Enforces the security canon (`.claude/memory/policy/security.md`): secrets live in `.env` (gitignored)
and are reached through the config layer, never written into code, config, notebooks, or docs. The
patterns below are high-signal token formats — provider-prefixed keys and private-key headers — chosen
to make false positives rare; this is a guard against the common leak, not a secret scanner (gitleaks
in `.pre-commit-config.yaml` covers the human-commit path).

Scope: every Edit/Write EXCEPT `.env` itself — that file is gitignored by convention and is exactly
where a real key belongs. `.env.example` IS scanned: it must ship empty values.

Platform surfaces are in scope too: a Kubernetes Secret manifest, a kubeconfig, a Terraform file, or
a CI workflow carrying a live credential is the same leak with a different extension. Literal values
in a `kind: Secret` manifest are additionally caught by `guard-k8s-manifests.py` (P7).

Fail-open on anything unparseable: a guard that bricks the session is worse than a missed write.
"""

import json
import re
import sys
from pathlib import Path

SECRET_PATTERNS = [
    ("AWS access key", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    (
        "GitHub token",
        re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})"),
    ),
    ("Anthropic API key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}")),
    (
        "OpenAI API key",
        re.compile(r"\bsk-(proj-)?[A-Za-z0-9_-]{20,}T3BlbkFJ[A-Za-z0-9_-]{20,}"),
    ),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}")),
    ("Stripe live key", re.compile(r"\b[sr]k_live_[A-Za-z0-9]{20,}\b")),
    ("HuggingFace token", re.compile(r"\bhf_[A-Za-z0-9]{34,}\b")),
    ("private key block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    # Platform-era additions. A signed JWT, embedded kubeconfig credential material, or a cloud
    # service-account key is a live credential exactly as much as a provider API key is.
    (
        "signed JWT / bearer token",
        re.compile(
            r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
        ),
    ),
    (
        "kubeconfig credential material",
        re.compile(
            r"^\s*(client-key-data|client-certificate-data|token):\s*\S{20,}", re.M
        ),
    ),
    (
        "GCP service-account key",
        re.compile(
            r"\"type\"\s*:\s*\"service_account\"[\s\S]{0,400}\"private_key\"\s*:"
        ),
    ),
    ("Azure client secret", re.compile(r"\b[A-Za-z0-9~._-]{3}8Q~[A-Za-z0-9~._-]{31,}")),
]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if Path(file_path).name == ".env":
        return 0  # gitignored by convention — the one legitimate home for a real key

    written = (tool_input.get("content") or "") + (tool_input.get("new_string") or "")
    if not written:
        return 0

    for label, pattern in SECRET_PATTERNS:
        if pattern.search(written):
            sys.stderr.write(
                f"[guard-secrets] Blocked: this write contains what looks like a {label}. "
                "Secrets belong in .env (gitignored) and flow through the config layer "
                "(see .claude/memory/policy/security.md). If it already leaked into git "
                "history, rotate the credential — deleting the line is not enough.\n"
            )
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
