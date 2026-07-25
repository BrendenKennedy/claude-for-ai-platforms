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

# Open-to-the-world, in every spelling Terraform accepts: the legacy `cidr_blocks` list, the
# modern `aws_vpc_security_group_ingress_rule` scalars (`cidr_ipv4`/`cidr_ipv6`), and IPv6's `::/0`
# — which is just as open as 0.0.0.0/0 and was invisible before.
OPEN_CIDR = re.compile(
    r"(cidr_blocks|ipv6_cidr_blocks|cidr_ipv4|cidr_ipv6)\s*=\s*"
    r"(\[[^\]]*)?[\"'](0\.0\.0\.0/0|::/0)[\"']",
    re.S,
)
FROM_PORT = re.compile(r"from_port\s*=\s*(\d+)")
TO_PORT = re.compile(r"to_port\s*=\s*(\d+)")
# Both the inline `ingress {}` block and the standalone resource the AWS provider now recommends.
INGRESS_BLOCK = re.compile(
    r"(?:ingress\s*\{[^}]*\}"
    r"|resource\s+\"aws_vpc_security_group_ingress_rule\"[^{]*\{(?:[^{}]|\{[^{}]*\})*\})",
    re.S,
)

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
        "D9",
        "storage encryption disabled",
        re.compile(
            r"(encrypted|storage_encrypted|encryption_enabled|encryption_at_rest_enabled)\s*=\s*false"
        ),
        "Encrypt at rest (D9). This is a one-word change now and a migration later — "
        "and it covers backups, snapshots, and replicas too.",
    ),
    # --- P11: data stores are never internet-reachable -------------------------------------
    # One rule, three clouds, three spellings. AWS `publicly_accessible`, GCP Cloud SQL
    # `ipv4_enabled` (public IP), Azure `public_network_access_enabled`.
    (
        "P11",
        "publicly accessible managed database (AWS)",
        re.compile(r"publicly_accessible\s*=\s*true"),
        "Private subnet, reached through the VPC. Unauthenticated internet-exposed data stores "
        "are found by internet-wide scanning within hours.",
    ),
    (
        "P11",
        "public IP on a managed database (GCP Cloud SQL)",
        re.compile(r"ipv4_enabled\s*=\s*true"),
        "Use private IP + the Cloud SQL Auth Proxy or a private service connection. "
        "Enforce it org-wide with the sql.restrictPublicIp org policy so it cannot come back.",
    ),
    (
        "P11",
        "public network access enabled (Azure)",
        re.compile(r"public_network_access_enabled\s*=\s*true"),
        "Use a private endpoint and disable public network access. Deny it by Azure Policy so it "
        "cannot be re-enabled by accident.",
    ),
    (
        "P11",
        "default or weak database credential",
        re.compile(
            r"(administrator_login_password|master_password|password)\s*=\s*"
            r"[\"'](postgres|admin|root|password|changeme|neo4j|guest|test)[\"']",
            re.I,
        ),
        "The shipped default credential must be gone before the store accepts a connection. "
        "Use IAM/Entra database authentication, or a generated secret from the secret manager.",
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
    """Only `from_port` was examined before, so a RANGE hid the problem: `from_port = 0,
    to_port = 65535` open to the world passed cleanly while the narrow port-22 rule was blocked —
    the most permissive rule was the one that got through. Test the whole range, and treat a very
    wide range open to the internet as a finding in its own right."""
    for block in INGRESS_BLOCK.findall(text):
        if isinstance(block, tuple):  # findall with groups
            block = next((b for b in block if b), "")
        if not block or not OPEN_CIDR.search(block):
            continue
        froms = [int(p) for p in FROM_PORT.findall(block)]
        tos = [int(p) for p in TO_PORT.findall(block)]
        if not froms:
            return "unspecified"
        lo = min(froms)
        hi = max(tos) if tos else lo
        if hi < lo:
            lo, hi = hi, lo
        hits = sorted({p for p in SENSITIVE_PORTS if lo <= p <= hi})
        if hits:
            rng = f"{lo}-{hi}" if hi != lo else str(lo)
            return f"{', '.join(map(str, hits))} (rule covers {rng})"
        if hi - lo >= 1024:
            return f"a {hi - lo + 1}-port range ({lo}-{hi})"
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
