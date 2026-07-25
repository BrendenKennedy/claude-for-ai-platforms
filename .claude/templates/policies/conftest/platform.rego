# conftest/OPA policies — the SAME rules as the Kyverno set, run in CI before the manifest merges.
# Failing here is a PR comment; failing at admission is a failed rollout at deploy time.
#
# Run:     kubectl kustomize deploy/overlays/prod | conftest test -p policies/ -
# Verify:  conftest verify -p policies/        <- runs the _test.rego fixtures below
#
# A policy with no test asserting it REJECTS a bad input may be silently passing everything.
# That is the most common failure in a policy repo, and `conftest verify` is what catches it.
package main

import rego.v1

workloads := {"Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob", "Pod", "ReplicaSet"}

pod_spec(obj) := obj.spec.template.spec if obj.kind in workloads
pod_spec(obj) := obj.spec if obj.kind == "Pod"

containers(obj) := array.concat(
	object.get(pod_spec(obj), "containers", []),
	object.get(pod_spec(obj), "initContainers", []),
)

# --- P3: resource limits ------------------------------------------------------------------
deny contains msg if {
	input.kind in workloads
	c := containers(input)[_]
	not c.resources.limits.memory
	msg := sprintf("%s/%s: container %q has no memory limit (platform-security.md P3)", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	input.kind in workloads
	c := containers(input)[_]
	not c.resources.limits.cpu
	msg := sprintf("%s/%s: container %q has no cpu limit (platform-security.md P3)", [input.kind, input.metadata.name, c.name])
}

# --- P4: digest-pinned images -------------------------------------------------------------
deny contains msg if {
	input.kind in workloads
	c := containers(input)[_]
	not contains(c.image, "@sha256:")
	msg := sprintf("%s/%s: container %q image %q is not digest-pinned (platform-security.md P4)", [input.kind, input.metadata.name, c.name, c.image])
}

# --- P1: pod security ----------------------------------------------------------------------
deny contains msg if {
	input.kind in workloads
	not pod_spec(input).securityContext.runAsNonRoot
	msg := sprintf("%s/%s: pod does not set runAsNonRoot: true (platform-security.md P1)", [input.kind, input.metadata.name])
}

deny contains msg if {
	input.kind in workloads
	c := containers(input)[_]
	c.securityContext.allowPrivilegeEscalation != false
	msg := sprintf("%s/%s: container %q must set allowPrivilegeEscalation: false (platform-security.md P1)", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	input.kind in workloads
	c := containers(input)[_]
	c.securityContext.privileged == true
	msg := sprintf("%s/%s: container %q is privileged (platform-security.md P1)", [input.kind, input.metadata.name, c.name])
}

# --- P2: host namespaces --------------------------------------------------------------------
deny contains msg if {
	input.kind in workloads
	some field in ["hostNetwork", "hostPID", "hostIPC"]
	pod_spec(input)[field] == true
	msg := sprintf("%s/%s: %s is set (platform-security.md P2)", [input.kind, input.metadata.name, field])
}

deny contains msg if {
	input.kind in workloads
	v := object.get(pod_spec(input), "volumes", [])[_]
	v.hostPath
	msg := sprintf("%s/%s: volume %q is a hostPath (platform-security.md P2)", [input.kind, input.metadata.name, v.name])
}

# --- P6: wildcard RBAC ------------------------------------------------------------------------
deny contains msg if {
	input.kind in {"Role", "ClusterRole"}
	r := input.rules[_]
	some field in ["verbs", "resources", "apiGroups"]
	"*" in object.get(r, field, [])
	msg := sprintf("%s/%s: wildcard in rule.%s (platform-security.md P6)", [input.kind, input.metadata.name, field])
}

# --- P6: default service account ---------------------------------------------------------------
deny contains msg if {
	input.kind in workloads
	sa := object.get(pod_spec(input), "serviceAccountName", "default")
	sa == "default"
	msg := sprintf("%s/%s: bound to the `default` ServiceAccount (platform-security.md P6)", [input.kind, input.metadata.name])
}

# --- P7: literal secrets -------------------------------------------------------------------------
deny contains msg if {
	input.kind == "Secret"
	count(object.get(input, "stringData", {})) > 0
	msg := sprintf("Secret/%s: literal stringData in a manifest (platform-security.md P7) — reference an external secret", [input.metadata.name])
}
