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
        re.compile(KEY + r"image:\s*[^\s,}]+:latest(?:\s|,|\}|$)", re.M),
        "Pin by digest: image: registry/name@sha256:...",
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
    return set(re.findall(r"^\s*kind:\s*([A-Za-z]+)", text, re.M))


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool_input = payload.get("tool_input", {})
    path = tool_input.get("file_path", "")
    if not path.endswith((".yaml", ".yml")):
        return 0

    text = (tool_input.get("content") or "") + (tool_input.get("new_string") or "")
    if not text or "apiVersion:" not in text or "kind:" not in text:
        return 0  # not a Kubernetes resource

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

    # Workloads must declare limits. Heuristic, deliberately loose: only fires when the manifest
    # clearly defines containers and mentions no limits at all.
    if (
        "P3" not in excused
        and present & set(K8S_WORKLOADS)
        and re.search(r"^\s*containers:", text, re.M)
    ):
        if not re.search(r"^\s*limits:", text, re.M):
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
