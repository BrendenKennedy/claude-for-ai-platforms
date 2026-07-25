#!/usr/bin/env python3
"""PreToolUse(Edit|Write) hook: block Kubernetes manifests that violate the platform-security canon.

Enforces `.claude/memory/policy/platform-security.md` at the earliest possible point — as the manifest
is written, rather than at admission during a rollout. This is the first of the three layers that skill
and canon describe (edit -> CI -> admission); **only admission is a security boundary**, and this hook
is a guardrail in exactly the sense of `security.md` S1: it stops the common accident cheaply and
loudly, and a determined bypass defeats it.

Scope: files ending .yaml/.yml whose content parses as a Kubernetes resource (has both `apiVersion:`
and `kind:`). Everything else is ignored — CI configs, Compose files, and arbitrary YAML are not this
hook's business.

Recorded exceptions: canon permits them with a decision-log entry. A resource carrying a comment of
the form `# platform-security-exception: P1 <reason>` is allowed through for the named rule, because a
guard with no exception path gets deleted rather than argued with.

Fail-open on anything unparseable: a guard that bricks the session is worse than a missed write.
"""

import json
import re
import sys
from pathlib import Path

K8S_WORKLOADS = (
    "Deployment",
    "StatefulSet",
    "DaemonSet",
    "Job",
    "CronJob",
    "Pod",
    "ReplicaSet",
)

# YAML keys appear both block-style (line-anchored) and inline in a flow mapping
# (`securityContext: {runAsNonRoot: false}`). Anchoring only to ^ silently misses the inline form,
# which is a form people actually write — so every key check allows `{` or `,` as a prefix too.
KEY = r"(?:^|[\s{,])"

# (rule, label, pattern, remediation)
CHECKS = [
    (
        "P1",
        "privileged container",
        re.compile(KEY + r"privileged:\s*true\b", re.M),
        "Remove it. Pod Security `restricted` forbids privileged containers.",
    ),
    (
        "P2",
        "host network namespace",
        re.compile(KEY + r"hostNetwork:\s*true\b", re.M),
        "Use a Service. hostNetwork collapses the pod network boundary.",
    ),
    (
        "P2",
        "host PID namespace",
        re.compile(KEY + r"hostPID:\s*true\b", re.M),
        "Remove it — this exposes every process on the node.",
    ),
    (
        "P2",
        "host IPC namespace",
        re.compile(KEY + r"hostIPC:\s*true\b", re.M),
        "Remove it.",
    ),
    (
        "P2",
        "hostPath volume",
        re.compile(KEY + r"hostPath:\s*(?:$|\{)", re.M),
        "Use emptyDir, a PVC, or a projected volume. hostPath is node-filesystem access.",
    ),
    (
        "P1",
        "allowPrivilegeEscalation: true",
        re.compile(KEY + r"allowPrivilegeEscalation:\s*true\b", re.M),
        "Set it to false.",
    ),
    (
        "P1",
        "runAsNonRoot: false",
        re.compile(KEY + r"runAsNonRoot:\s*false\b", re.M),
        "Set runAsNonRoot: true and give the container a non-zero runAsUser.",
    ),
    (
        "P1",
        "runAsUser: 0 (root)",
        re.compile(KEY + r"runAsUser:\s*0\b", re.M),
        "Run as a non-zero uid.",
    ),
    (
        "P4",
        "mutable image tag `:latest`",
        # Quoting an image is ordinary YAML, and `image: "nginx:latest"` evaded the original
        # terminator class. Allow an optional closing quote, and catch an untagged image too.
        # NOTE: full P4 (digest-pinned) is deliberately NOT enforced here. That belongs to the CI
        # and admission layers — `templates/policies/conftest/platform.rego` requires `@sha256:`
        # and Kyverno enforces it at admission. This layer catches the unambiguous accident;
        # blocking every tag-pinned dev overlay at edit time is friction without a security gain,
        # and a guard that fights ordinary work gets deleted (security.md S1).
        re.compile(
            KEY + r"""image:\s*["']?[^\s,}"']+:latest["']?(?:\s|,|\}|$)""", re.M
        ),
        "Pin by digest: image: registry/name@sha256:...",
    ),
    (
        "P4",
        "untagged image (resolves to :latest)",
        re.compile(KEY + r"""image:\s*["']?[^\s,}"':@]+["']?\s*$""", re.M),
        "An untagged image resolves to :latest. Pin by digest: registry/name@sha256:...",
    ),
]

# `verbs: ["*"]` / `resources: ['*']` inline, or a `- "*"` list item inside an RBAC rule
RBAC_INLINE = re.compile(
    r"^\s*(verbs|resources|apiGroups):\s*\[[^\]]*[\"']?\*[\"']?[^\]]*\]", re.M
)
RBAC_ITEM = re.compile(r"^\s*-\s*[\"']?\*[\"']?\s*$", re.M)

SECRET_LITERAL = re.compile(
    r"^\s*(data|stringData):\s*\n(?:\s*#.*\n)*\s+\S+:\s*\S+", re.M
)
EXCEPTION = re.compile(r"#\s*platform-security-exception:\s*([A-Z]+\d+)")


def kinds(text: str) -> set[str]:
    # Quoted values are legal YAML: `kind: "Secret"` must not skip the Secret checks.
    return set(re.findall(r"""(?m)^\s*kind:\s*["']?([A-Za-z]+)""", text))


def resolved_text(tool_input: dict) -> tuple[str, bool]:
    """Return (text_to_scan, is_whole_file).

    A Write carries the whole file in `content`. An **Edit carries only a hunk** —
    `old_string`/`new_string` — which is how a manifest is normally changed, and scanning the hunk
    alone means the `apiVersion:`/`kind:` gate never matches and every check silently skips. That
    made this guard blind to the common case.

    So for an Edit: read the file and apply the replacement, giving the checks the post-edit manifest
    they need. If the file can't be read, fall back to the hunk and say so — the caller then runs
    only the pattern checks, because a whole-file *absence* check (P3) cannot be judged from a hunk.
    """
    content = tool_input.get("content")
    if content:
        return content, True

    new = tool_input.get("new_string") or ""
    if not new:
        return "", False

    old = tool_input.get("old_string") or ""
    try:
        current = Path(tool_input.get("file_path", "")).read_text(errors="replace")
    except Exception:
        return new, False
    if old and old in current:
        return current.replace(old, new, 1), True
    # Insert-only edit, or a stale anchor: append so the new content is at least seen in context.
    return current + "\n" + new, True


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool_input = payload.get("tool_input", {})
    path = tool_input.get("file_path", "")
    if not path.endswith((".yaml", ".yml")):
        return 0

    try:
        text, whole_file = resolved_text(tool_input)
    except Exception:
        return 0
    if not text:
        return 0

    # A reconstructed file carries the anchors; a bare hunk won't. Scan a hunk anyway when the path
    # looks like a manifest — the individual patterns (privileged, hostPath, wildcard RBAC) are
    # specific enough that a false positive on unrelated YAML is unlikely, and missing an Edit is
    # worse than an occasional over-catch that the exception marker can clear.
    looks_like_manifest = "apiVersion:" in text and "kind:" in text
    if not looks_like_manifest and whole_file:
        return 0  # a real file that isn't a Kubernetes resource

    excused = set(EXCEPTION.findall(text))
    found: list[tuple[str, str, str]] = []
    present = kinds(text)

    for rule, label, pattern, fix in CHECKS:
        if rule in excused:
            continue
        if pattern.search(text):
            found.append((rule, label, fix))

    if "P6" not in excused and present & {"Role", "ClusterRole"}:
        if RBAC_INLINE.search(text) or RBAC_ITEM.search(text):
            found.append(
                (
                    "P6",
                    "wildcard RBAC rule (`*`)",
                    "Enumerate the exact apiGroups, resources, and verbs this needs.",
                )
            )

    if "P7" not in excused and "Secret" in present and SECRET_LITERAL.search(text):
        found.append(
            (
                "P7",
                "literal value in a Secret manifest",
                "Reference an external secret (ExternalSecret / CSI driver). "
                "A secret in git must be rotated, not deleted.",
            )
        )

    # Workloads must declare limits. This is an ABSENCE check, so it needs the whole file — a hunk
    # legitimately won't contain `limits:` and flagging it would block ordinary edits.
    # `limits:` is matched anywhere, not line-anchored, because flow style
    # (`resources: {limits: {cpu: "1"}}`) is valid YAML and the anchored form blocked compliant
    # manifests — a guard that rejects correct input is a guard people delete.
    if (
        whole_file
        and "P3" not in excused
        and present & set(K8S_WORKLOADS)
        and re.search(r"(?m)^\s*containers:", text)
    ):
        if not re.search(r"[\s{,]limits:", text):
            found.append(
                (
                    "P3",
                    "no resource limits on any container",
                    "Add resources.requests and resources.limits (cpu + memory) per container.",
                )
            )

    if not found:
        return 0

    lines = [
        f"[guard-k8s-manifests] Blocked {path} — platform-security canon violation"
        f"{'s' if len(found) > 1 else ''}:",
        "",
    ]
    for rule, label, fix in found:
        lines.append(f"  {rule}  {label}")
        lines.append(f"      fix: {fix}")
    lines += [
        "",
        "  Canon: .claude/memory/policy/platform-security.md  (see also `kubernetes` skill,",
        "         and .claude/templates/k8s/ for a baseline that already satisfies these).",
        "  If this is a deliberate, recorded exception, add a decision-log entry and mark the",
        "  resource with:  # platform-security-exception: <RULE> <reason>",
        "",
    ]
    sys.stderr.write("\n".join(lines))
    return 2


if __name__ == "__main__":
    sys.exit(main())
