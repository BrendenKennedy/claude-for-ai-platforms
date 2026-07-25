#!/usr/bin/env bash
# PreToolUse(Bash) guard — THREE tiers, first match wins:
#
#   BLOCK (exit 2)        never OK: root/home wipes, .env reads, piping a download into a shell.
#   ASK   (JSON + exit 0) legit but irreversible: destructive ops get a confirmation dialog that
#                         fires in EVERY permission mode — including acceptEdits and
#                         bypassPermissions (per the hooks docs' permissionDecision table). This is
#                         the tier that survives "yolo mode".
#   ALLOW (exit 0)        everything else defers to the normal permission flow.
#
# Fail-open: if the command can't be parsed, it is allowed (a guard, not a gate). Pattern-matching
# is best-effort by design — the threat model lives in .claude/memory/policy/security.md.
set -uo pipefail

input="$(cat)"

# Extract the bash command from the hook payload (tool_input.command).
cmd="$(printf '%s' "$input" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' \
  2>/dev/null || true)"

[ -z "$cmd" ] && exit 0

# Force a confirmation dialog. stdout must be ONLY this JSON; reasons stay quote-free.
ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# ── BLOCK tier ───────────────────────────────────────────────────────────────

# B1) Recursive force-deletes aimed at a root / home path.
if printf '%s' "$cmd" | grep -Eq 'rm[[:space:]]+-[a-zA-Z]*(rf|fr)[a-zA-Z]*[[:space:]]+(/|~/?|/\*|\$HOME/?|/home/[^[:space:];]+)([[:space:]]|;|$)'; then
  echo "BLOCKED: refusing a recursive force-delete of a root/home path. Narrow the target path." >&2
  exit 2
fi

# B2) Shell reads of .env files (the Read-tool deny in settings.json doesn't cover the shell path).
#     `.env.example` ships empty values and stays readable — strip its mentions first.
stripped="${cmd//.env.example/}"
if printf '%s' "$stripped" | grep -Eq '(^|[;&|`([:space:]])(cat|less|more|head|tail|bat|strings|xxd|od|grep|egrep|fgrep|awk|cut|paste|sort|uniq|source)[[:space:]][^;|&]*\.env([^A-Za-z0-9_-]|$)'; then
  echo "BLOCKED: refusing a shell read of a .env file — secrets stay out of the transcript. Read .env.example for the expected keys, or ask the user for the value you need." >&2
  exit 2
fi

# B3) Piping a download straight into an interpreter — untrusted code execution
#     (security canon: no `curl | sh`; dependencies enter through `uv add`).
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])(curl|wget)[[:space:]][^;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|k)?sh([[:space:]]|$)|(^|[;&|`([:space:]])(curl|wget)[[:space:]][^;&]*\|[[:space:]]*python'; then
  echo "BLOCKED: refusing to pipe a download into an interpreter. Fetch to a file, review it, then run it — or add the dependency through uv (see security.md, supply chain)." >&2
  exit 2
fi

# B4) Shell reads of cluster/cloud credential material — same rule as .env (security.md S3): a
#     secret echoed into the transcript has leaked. `kubectl get secret -o yaml` prints it in full.
# Order-independent: the original required `-o` to appear AFTER the word `secret`, so
# `kubectl get -o yaml secret db` — ordinary, and equally revealing — walked straight through.
# `--template` was missing from the format list for the same reason. Two greps ANDed instead of one
# positional pattern: does this touch a Secret, and does it ask for a full-content output format?
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])kubectl[[:space:]][^;|&]*(get|describe)[^;|&]*secret' \
   && printf '%s' "$cmd" | grep -Eq '(-o|--output)[[:space:]]*=?[[:space:]]*(yaml|json|jsonpath|go-template|custom-columns)|--template'; then
  echo "BLOCKED: refusing to print Secret contents into the transcript (security.md S3 - a secret echoed into a stored transcript has leaked). Use 'kubectl get secret <name>' for metadata only, or read the value from the secret manager out of band." >&2
  exit 2
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])(cat|less|more|head|tail|bat|strings|xxd|od|grep|egrep|awk|source)[[:space:]][^;|&]*(kubeconfig|\.kube/config|\.aws/credentials|\.docker/config\.json|id_rsa|id_ed25519|\.pem([^A-Za-z0-9]|$)|\.p12([^A-Za-z0-9]|$))'; then
  echo "BLOCKED: refusing a shell read of credential material (kubeconfig, cloud credentials, private key). Secrets stay out of the transcript - security.md S3." >&2
  exit 2
fi

# ── ASK tier — irreversible-if-wrong operations get a dialog in every permission mode ────────────

# A1) Any recursive rm (root/home already blocked above; this catches project paths, incl. inside
#     compound commands the deny-list prefix rules can't see).
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])rm[[:space:]]([^;|&]*[[:space:]])?-[a-zA-Z]*[rR]'; then
  ask "Recursive delete - confirm the target directory is right (and not data/, models/, or anything DVC-tracked)."
fi

# A2) Deleting / truncating protected ML assets even non-recursively: datasets, checkpoints,
#     the tracking DB, the lockfile, DVC state.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])(rm|shred|truncate|unlink)[[:space:]][^;|&]*(mlflow\.db|\.pt([[:space:]]|$|["'"'"'])|uv\.lock|\.dvc(/|[[:space:]]|$)|(^|[[:space:]"'"'"'])data/|models/)'; then
  ask "This deletes a tracked ML asset (dataset, checkpoint, tracking DB, or lockfile). Confirm it is disposable."
fi

# A3) find -delete / -exec rm — recursive deletion by another name.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])find[[:space:]][^;|&]*(-delete|-exec[[:space:]]+rm)'; then
  ask "find with -delete/-exec rm - confirm the match pattern before it walks the tree."
fi

# A4) Git operations that discard work or rewrite history.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+clean[[:space:]][^;|&]*-[a-zA-Z]*f'; then
  ask "git clean -f deletes untracked files permanently - confirm nothing un-committed is needed."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+reset[[:space:]][^;|&]*--hard'; then
  ask "git reset --hard discards uncommitted changes - confirm the working tree is disposable."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+checkout[[:space:]]+(--[[:space:]]|\.([[:space:]]|$))'; then
  ask "git checkout with a pathspec discards uncommitted changes to those files - confirm."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+restore[[:space:]]' \
   && ! printf '%s' "$cmd" | grep -Eq -- '--staged'; then
  ask "git restore overwrites working-tree files with the committed version - confirm."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+push[[:space:]][^;|&]*(--force|-f([[:space:]]|$))'; then
  ask "Force-push rewrites remote history - confirm this is wanted (landing is normally an explicit user ask)."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+branch[[:space:]][^;|&]*-D([[:space:]]|$)'; then
  ask "git branch -D force-deletes an unmerged branch - confirm its work is landed or disposable."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])git[[:space:]]+(filter-branch|filter-repo)|reflog[[:space:]]+expire'; then
  ask "History rewrite - confirm; this changes hashes and invalidates clones."
fi

# A5) DVC operations that drop data from the cache/remote.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])dvc[[:space:]]+(gc|destroy|remove)([[:space:]]|$)'; then
  ask "This DVC command discards tracked data or DVC state - confirm the pointers/commits that need those bytes are safe."
fi

# A6) Destructive AWS operations (infra-aws skill): bucket/cluster/instance removal, and any IAM
#     mutation — the claude-for-ai-platform role is deliberately least-privilege; widening it is a
#     human decision.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])aws[[:space:]]+(s3[[:space:]]+rb|s3api[[:space:]]+delete-bucket|s3[[:space:]]+rm[[:space:]][^;|&]*--recursive|redshift[[:space:]]+delete-|ec2[[:space:]]+terminate-instances|sagemaker[[:space:]]+delete-)'; then
  ask "Destructive AWS operation (bucket/cluster/instance deletion) - confirm the resource, and that its data is versioned or disposable."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])aws[[:space:]]+iam[[:space:]]+(create|delete|put|attach|detach|update|add|remove|tag|untag)'; then
  ask "IAM mutation - the agent role is deliberately least-privilege; confirm this change with the human who owns the account."
fi

# A7) Docker operations that delete state: pruning, volume removal, and compose down -v — a named
#     volume may hold the tracking DB or Postgres.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+(rm|prune)|builder[[:space:]]+prune)' \
   || printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])docker([[:space:]]+|-)compose[[:space:]]+down[[:space:]][^;|&]*(-v([[:space:]]|$)|--volumes)'; then
  ask "This removes Docker volumes/state (a compose volume may hold the tracking DB) - confirm it is disposable."
fi

# A8) Kubernetes operations that remove workloads or disrupt nodes. `kubectl apply` is NOT gated —
#     declarative convergence is the normal path (and gitops makes it a git operation anyway);
#     deletion and node disruption are the irreversible ones.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])kubectl[[:space:]]+(delete|drain|cordon|uncordon|taint)([[:space:]]|$)'; then
  ask "Destructive cluster operation - confirm the namespace and context first (kubectl config current-context). Deleting a namespace takes everything in it, and draining a node evicts live workloads."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])kubectl[[:space:]]+(exec|port-forward|proxy)([[:space:]]|$)'; then
  ask "Interactive access into a running workload - confirm the target and that this is not production. An exec session bypasses the audit trail your application logs provide."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])helm[[:space:]]+(uninstall|delete|rollback)([[:space:]]|$)'; then
  ask "Helm uninstall/rollback removes or reverts a release - confirm the release name and namespace."
fi

# A9) Terraform/OpenTofu state-changing operations. `plan` and `validate` are read-only and allowed.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])(terraform|tofu)[[:space:]]+(destroy|apply)([[:space:]]|$)'; then
  ask "Terraform will change real infrastructure - confirm you have READ the plan (destroys, replacements, IAM widening, 0.0.0.0/0). Apply the reviewed plan file, not a fresh plan."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])(terraform|tofu)[[:space:]]+state[[:space:]]+(rm|mv|push|replace-provider)([[:space:]]|$)'; then
  ask "Direct state surgery - confirm you have a state backup. A corrupted state file orphans real resources."
fi

# A10) GitOps + secret-store deletions.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])(argocd[[:space:]]+app[[:space:]]+delete|flux[[:space:]]+(delete|uninstall))([[:space:]]|$)'; then
  ask "Removing a GitOps application stops reconciliation and may prune its resources - confirm."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])vault[[:space:]]+(delete|destroy|kv[[:space:]]+(delete|destroy|metadata[[:space:]]+delete))'; then
  ask "Deleting from the secret store - confirm nothing still consumes this secret, and that it is rotated rather than merely removed (security.md S4)."
fi

# A11) Cluster RBAC / IAM widening from the shell — same rule as A6, extended to Kubernetes.
#      security.md S8: the agent never widens its own permissions.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`([:space:]])kubectl[[:space:]]+(create|apply)[[:space:]][^;|&]*(clusterrolebinding|rolebinding|clusterrole)'; then
  ask "This grants Kubernetes permissions - the agent never widens its own permissions (security.md S8). Confirm with the human who owns the cluster."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Project-specific rules go here. Patterns: BLOCK = echo reason to stderr, exit 2;
# ASK = call ask "reason". Delete this block if you have no extra rules.
#
# Example — forbid system-package ops on a protected host named in the command:
#   if printf '%s' "$cmd" | grep -Eq '(^|[^a-zA-Z])PROTECTED_HOST([^a-zA-Z]|$)' \
#      && printf '%s' "$cmd" | grep -Eq '(^|[^a-zA-Z])(apt|apt-get|dpkg|snap)([^a-zA-Z]|$)'; then
#     echo "BLOCKED: system-package operations on PROTECTED_HOST are forbidden." >&2
#     exit 2
#   fi
# ─────────────────────────────────────────────────────────────────────────────

exit 0
