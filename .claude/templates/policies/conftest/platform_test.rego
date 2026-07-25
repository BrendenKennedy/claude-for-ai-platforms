# Policy self-tests. `conftest verify -p policies/` runs these.
#
# The point: every rule needs a fixture that MUST be rejected and one that MUST pass. Without the
# first, a broken rule silently approves everything and the policy suite becomes decoration — which
# is exactly the state most policy repos are in. run-security-tests.sh runs this before a session
# can end.
package main

import rego.v1

good_deployment := {
	"kind": "Deployment",
	"metadata": {"name": "ok"},
	"spec": {"template": {"spec": {
		"serviceAccountName": "app",
		"securityContext": {"runAsNonRoot": true},
		"containers": [{
			"name": "app",
			"image": "registry.example.com/app@sha256:abc123",
			"securityContext": {"allowPrivilegeEscalation": false},
			"resources": {
				"requests": {"cpu": "100m", "memory": "128Mi"},
				"limits": {"cpu": "500m", "memory": "512Mi"},
			},
		}],
	}}},
}

test_good_deployment_passes if {
	count(deny) == 0 with input as good_deployment
}

test_missing_memory_limit_is_denied if {
	bad := json.remove(good_deployment, ["spec/template/spec/containers/0/resources/limits/memory"])
	count(deny) > 0 with input as bad
}

test_mutable_tag_is_denied if {
	bad := json.patch(good_deployment, [{
		"op": "replace",
		"path": "/spec/template/spec/containers/0/image",
		"value": "registry.example.com/app:latest",
	}])
	count(deny) > 0 with input as bad
}

test_root_pod_is_denied if {
	bad := json.patch(good_deployment, [{
		"op": "replace",
		"path": "/spec/template/spec/securityContext/runAsNonRoot",
		"value": false,
	}])
	count(deny) > 0 with input as bad
}

test_host_network_is_denied if {
	bad := json.patch(good_deployment, [{
		"op": "add",
		"path": "/spec/template/spec/hostNetwork",
		"value": true,
	}])
	count(deny) > 0 with input as bad
}

test_default_service_account_is_denied if {
	bad := json.patch(good_deployment, [{
		"op": "replace",
		"path": "/spec/template/spec/serviceAccountName",
		"value": "default",
	}])
	count(deny) > 0 with input as bad
}

test_wildcard_rbac_is_denied if {
	bad := {
		"kind": "ClusterRole",
		"metadata": {"name": "too-much"},
		"rules": [{"apiGroups": ["*"], "resources": ["*"], "verbs": ["*"]}],
	}
	count(deny) > 0 with input as bad
}

test_literal_secret_is_denied if {
	bad := {"kind": "Secret", "metadata": {"name": "s"}, "stringData": {"password": "hunter2"}}
	count(deny) > 0 with input as bad
}
