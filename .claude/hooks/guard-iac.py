#!/usr/bin/env python3
"""PreToolUse(Edit|Write) hook: block infrastructure-as-code that opens something it shouldn't.

Enforces the platform-security and identity-and-access canon at the point a Terraform/OpenTofu file
is written — before `plan`, and long before `apply`. Catches the small set of misconfigurations that
are almost never intentional and almost always expensive: public network exposure, public object
storage, wildcard IAM, unencrypted storage, and hardcoded credentials.

Scope: `.tf` and `.tfvars` files. `.tfvars` is checked for credential-shaped values only.

This is a guardrail, not a policy engine — `checkov`/`trivy config`/`conftest` in CI (see the
`secure-cicd` and `policy-as-code` skills) do the thorough pass against the rendered *plan*, which is
strictly stronger because it evaluates what will actually exist.

Recorded exceptions: a resource carrying `# iac-exception: <RULE> <reason>` is allowed through for
that rule; canon permits exceptions with a decision-log entry.

Fail-open on anything unparseable: a guard that bricks the session is worse than a missed write.
"""

import json
import re
import sys

# Ports where an open-to-the-world ingress rule is essentially never intended.
SENSITIVE_PORTS = {22, 23, 445, 1433, 1521, 3306, 3389, 5432, 5439, 6379, 9200, 27017}

OPEN_CIDR = re.compile(r"cidr_blocks\s*=\s*\[[^\]]*[\"']0\.0\.0\.0/0[\"']", re.S)
FROM_PORT = re.compile(r"from_port\s*=\s*(\d+)")
INGRESS_BLOCK = re.compile(r"ingress\s*\{[^}]*\}", re.S)

CHECKS = [
    (
        "P5",
        "publicly-readable object storage",
        re.compile(r"acl\s*=\s*[\"'](public-read|public-read-write)[\"']"),
        "Buckets are never public (security.md S8). Use a presigned URL, scoped and short-lived.",
    ),
    (
        "P5",
        "public access block disabled",
        re.compile(
            r"(block_public_acls|block_public_policy|ignore_public_acls|restrict_public_buckets)\s*=\s*false"
        ),
        "Leave all four public-access-block settings true.",
    ),
    (
        "I4",
        'wildcard IAM statement (Action = "*")',
        re.compile(r"[\"']Action[\"']\s*:\s*\[?\s*[\"']\*[\"']"),
        "Enumerate the exact actions. A wildcard policy is not least privilege.",
    ),
    (
        "I4",
        "wildcard IAM resource with wildcard action",
        re.compile(r"actions\s*=\s*\[\s*[\"']\*[\"']\s*\]", re.I),
        "Enumerate the actions this role genuinely needs.",
    ),
    (
        "P8",
        "storage encryption disabled",
        re.compile(r"(encrypted|storage_encrypted|encryption_enabled)\s*=\s*false"),
        "Encrypt at rest. This is a one-word change now and a migration later.",
    ),
    (
        "P8",
        "publicly accessible database",
        re.compile(r"publicly_accessible\s*=\s*true"),
        "Put it in a private subnet and reach it through the VPC.",
    ),
    (
        "R3",
        "skip_final_snapshot on a stateful resource",
        re.compile(r"skip_final_snapshot\s*=\s*true"),
        "Irreversible data loss on destroy. Set false, or add lifecycle { prevent_destroy = true }.",
    ),
]

CREDENTIALS = [
    ("S2", "hardcoded AWS access key", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    (
        "S2",
        "hardcoded secret in a variable",
        re.compile(
            r"^\s*(password|secret_key|access_key|api_key|token)\s*=\s*[\"'][^\"'${\s][^\"']{7,}[\"']",
            re.M | re.I,
        ),
    ),
    ("S2", "private key block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
]

EXCEPTION = re.compile(r"#\s*iac-exception:\s*([A-Z]+\d+)")


def open_to_world_on_sensitive_port(text: str) -> str | None:
    for block in INGRESS_BLOCK.findall(text):
        if not OPEN_CIDR.search(block):
            continue
        ports = [int(p) for p in FROM_PORT.findall(block)]
        hits = [p for p in ports if p in SENSITIVE_PORTS]
        if hits:
            return ", ".join(str(p) for p in sorted(set(hits)))
        if not ports:
            return "unspecified"
    return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool_input = payload.get("tool_input", {})
    path = tool_input.get("file_path", "")
    if not path.endswith((".tf", ".tfvars")):
        return 0

    text = (tool_input.get("content") or "") + (tool_input.get("new_string") or "")
    if not text:
        return 0

    excused = set(EXCEPTION.findall(text))
    found: list[tuple[str, str, str]] = []

    for rule, label, pattern in CREDENTIALS:
        if rule not in excused and pattern.search(text):
            found.append(
                (
                    rule,
                    label,
                    "Read it from a secret manager or TF_VAR_* injected by federated CI. "
                    "Anything Terraform creates also lands in state in plaintext.",
                )
            )

    if path.endswith(".tf"):
        for rule, label, pattern, fix in CHECKS:
            if rule not in excused and pattern.search(text):
                found.append((rule, label, fix))

        if "P5" not in excused:
            ports = open_to_world_on_sensitive_port(text)
            if ports:
                found.append(
                    (
                        "P5",
                        f"ingress from 0.0.0.0/0 on sensitive port(s): {ports}",
                        "Restrict the CIDR, or front it with a load balancer / bastion / VPN.",
                    )
                )

    if not found:
        return 0

    lines = [
        f"[guard-iac] Blocked {path} — infrastructure policy violation"
        f"{'s' if len(found) > 1 else ''}:",
        "",
    ]
    for rule, label, fix in found:
        lines.append(f"  {rule}  {label}")
        lines.append(f"      fix: {fix}")
    lines += [
        "",
        "  Canon: .claude/memory/policy/platform-security.md, identity-and-access.md, security.md",
        "         (see also the `iac-terraform` skill).",
        "  Deliberate and recorded? Add a decision-log entry and mark it:",
        "         # iac-exception: <RULE> <reason>",
        "",
    ]
    sys.stderr.write("\n".join(lines))
    return 2


if __name__ == "__main__":
    sys.exit(main())
