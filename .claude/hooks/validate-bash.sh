#!/usr/bin/env bash
# PreToolUse(Bash) guard — block never-OK shell commands, ask on irreversible ones, allow the rest.
#
# THREE tiers, first match wins:
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

# B0) System package management on an NVIDIA appliance box (DGX Spark / GB10 Grace-Blackwell /
#     Jetson). These ship a vendor-managed OS image where the kernel, the CUDA stack, and the boot
#     chain are held together by pinned distro packages. `apt update` re-points the indexes and
#     `apt upgrade` then walks the driver/CUDA/kernel packages off the vendor's tested set — which
#     is how these boxes get bricked, and recovery is a full re-image, not a rollback.
#
#     Host-gated: this fires ONLY on a detected appliance box, so it is inert on an ordinary Linux
#     dev machine or CI runner. Detection fails OPEN — if we cannot tell what the host is, we do not
#     block. It is deliberately NOT cached: the first version wrote the verdict to a /tmp marker, and
#     that marker was (a) writable by the very agent being guarded, so `echo no > …` was a one-line
#     off-switch, and (b) never invalidated, so one transient miss (driver not loaded, nvidia-smi not
#     yet on PATH) disabled the guard permanently and silently. Detection costs ~21ms; a cache that
#     can fail unsafe is not worth 21ms.
#
#     The way to install things on these boxes: static/prebuilt binaries into ~/.local/bin, uv for
#     Python, containers for anything that wants a distro. See env-uv and security.md S10.
#     CLAUDE_APPLIANCE_HOST=yes|no overrides detection — `yes` opts in a box we don't recognise,
#     `no` opts out. Any other value is ignored and detection runs, so a typo can't silently disable
#     the guard. It is also what makes this testable on an x86 CI runner.
is_appliance_host() {
  case "${CLAUDE_APPLIANCE_HOST:-}" in
    yes|1|true) return 0 ;;
    no|0|false) return 1 ;;
  esac
  # GB10 / GB2xx Grace-Blackwell, or an NVIDIA-branded Spark/Jetson board. `timeout` because a
  # wedged driver — this hardware class's characteristic failure — makes nvidia-smi hang, and a
  # guard that stalls every command is a guard people rip out.
  if command -v nvidia-smi >/dev/null 2>&1 &&
     timeout 2 nvidia-smi -L 2>/dev/null | grep -Eqi 'GB[0-9]{2,3}|DGX[[:space:]]*Spark'; then
    return 0
  fi
  [ -f /etc/nv_tegra_release ] && return 0
  grep -Eqi 'dgx[[:space:]]*spark|AI TOP ATOM' /sys/devices/virtual/dmi/id/product_name \
       /proc/device-tree/model 2>/dev/null
}

# Cheap pre-filter, then a real tokenizing decision. The first version was a single regex anchoring
# the subcommand immediately after apt/apt-get — so `apt-get -y install foo` walked straight through
# while `apt-get install -y foo` blocked, and `sudo apt-get -qq update && sudo apt-get -y
# dist-upgrade` (verbatim the sequence S10 exists to prevent) was allowed. A regex cannot do this:
# it has to know where a command *starts* to tell `apt install` from `git commit -m "apt install"`.
if printf '%s' "$cmd" | grep -Eqi 'apt|dpkg|aptitude' && is_appliance_host; then
  CLAUDE_BASH_CMD="$cmd" python3 - <<'PY'
import os, re, shlex, sys

cmd = os.environ.get("CLAUDE_BASH_CMD", "")


def strip_heredocs(text):
    """A heredoc body is DATA — a commit message, a file being written, a doc about this very
    rule — not commands. Keep it only when it is fed to a shell, which does execute it.
    Without this, `git commit -F - <<'EOF' … apt-get -y install … EOF` blocks, and writing about
    the policy becomes impossible. (It blocked this repo's own release commit.)"""
    lines, out, i = text.split("\n"), [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = re.search(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line)
        if m:
            head = line.strip().split()[0] if line.strip() else ""
            executes = os.path.basename(head.strip("(){};&|")) in SHELLS
            delim, j = m.group(2), i + 1
            while j < len(lines) and lines[j].strip() != delim:
                if executes:
                    out.append(lines[j])
                j += 1
            i = j
        i += 1
    return "\n".join(out)

# Mutating package managers that take no subcommand — the whole invocation is the hazard.
ALWAYS = {"add-apt-repository", "do-release-upgrade", "unattended-upgrade",
          "unattended-upgrades", "dpkg-reconfigure"}
# apt / apt-get / aptitude subcommands that only READ. Everything else is default-deny, because
# the miss list (reinstall, build-dep, edit-sources) is longer than the safe list.
APT_RO = {"list", "show", "showsrc", "showpkg", "search", "policy", "depends", "rdepends",
          "madison", "moo", "help", "--help", "--version", "-v"}
# dpkg query flags. Same reasoning inverted: dpkg's mutating surface is large and long-formed.
DPKG_RO = {"-l", "-L", "-s", "-S", "-p", "-c", "-I", "--list", "--listfiles", "--status",
           "--search", "--print-avail", "--contents", "--info", "--help", "--version"}
# A container is the remedy S10 recommends — the blast radius is an image, not the host. Blocking
# it is the false positive most likely to get the whole rule disabled.
CONTAINER = {"docker", "podman", "nerdctl", "ctr", "apptainer", "singularity"}
# Wrappers that pass through to the real command.
WRAPPERS = {"sudo", "doas", "env", "nohup", "time", "command", "nice", "ionice", "setsid",
            "stdbuf", "xargs", "builtin", "exec"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
# Remote execution: judged, not exempted. The target may well be another appliance, and this guard
# has no way to know. Deliberately stricter than the container carve-out — a container's blast
# radius is an image, another host's is another host.
REMOTE = {"ssh", "rsh"}
# Grouping tokens shlex leaves behind: `( apt update )`, `{ apt update; }`.
GROUPING = {"(", ")", "{", "}"}


def segments(text):
    """Split into command segments, and pull out $( ) and `` bodies as segments of their own."""
    out, depth, buf = [], 0, ""
    i = 0
    while i < len(text):
        two = text[i:i + 2]
        if two == "$(":
            depth += 1; i += 2; out.append(""); continue
        if text[i] == ")" and depth:
            depth -= 1; i += 1; continue
        if depth == 0 and (two in ("&&", "||") or text[i] in ";|\n&"):
            out.append(buf); buf = ""
            i += 2 if two in ("&&", "||") else 1
            continue
        buf += text[i]; i += 1
    out.append(buf)
    # Command substitutions were flattened above; re-extract them so their contents are judged too.
    for m in re.finditer(r"\$\(([^()]*)\)|`([^`]*)`", text):
        out.append(m.group(1) or m.group(2) or "")
    return [s for s in out if s.strip()]


def verdict(seg, depth=0):
    """True if this segment mutates system packages."""
    if depth > 3:
        return False
    try:
        toks = shlex.split(seg)
    except ValueError:
        toks = seg.split()
    while toks:
        head = os.path.basename(toks[0])
        if toks[0] in GROUPING:
            toks = toks[1:]; continue
        if "=" in toks[0] and not toks[0].startswith("-"):   # VAR=value prefix
            toks = toks[1:]; continue
        if head in CONTAINER:
            return False                                     # allowed: runs inside an image
        if head in REMOTE:
            toks = toks[1:]
            while toks and toks[0].startswith("-"):          # ssh -p 22 …
                toks = toks[2:] if toks[0] in ("-p", "-i", "-l", "-o") else toks[1:]
            return any(verdict(s, depth + 1) for s in segments(" ".join(toks[1:])))
        if head == "kubectl" or head == "oc":
            if "exec" in toks:
                tail = toks[toks.index("exec") + 1:]
                if "--" in tail:
                    tail = tail[tail.index("--") + 1:]
                return any(verdict(s, depth + 1) for s in segments(" ".join(tail)))
            return False
        if head in SHELLS:
            # bash -c "<body>" — judge the body, not the wrapper.
            for j, t in enumerate(toks[1:], 1):
                if t == "-c" and j + 1 < len(toks):
                    return any(verdict(s, depth + 1) for s in segments(toks[j + 1]))
            return False
        if head in WRAPPERS:
            toks = toks[1:]
            while toks and toks[0].startswith("-"):          # sudo -E, xargs -n1, …
                toks = toks[1:]
            continue
        break
    if not toks:
        return False
    head = os.path.basename(toks[0])
    if head in ALWAYS:
        return True
    rest = toks[1:]
    if head in ("apt", "apt-get", "aptitude"):
        for t in rest:                                       # first non-flag token = subcommand
            if not t.startswith("-"):
                return t not in APT_RO
        return False                                         # bare `apt`, or flags only
    if head == "dpkg":
        return not any(t in DPKG_RO for t in rest)
    return False                                             # apt-cache, apt-mark query, git, echo…


try:
    sys.exit(2 if any(verdict(s) for s in segments(strip_heredocs(cmd))) else 0)
except Exception:
    sys.exit(0)                                              # fail OPEN, always
PY
  if [ $? -eq 2 ]; then
    echo "BLOCKED: this is an NVIDIA appliance box (DGX Spark / GB10 / Jetson) and apt/dpkg mutations are not safe on it. The OS image is vendor-managed: apt update re-points the indexes and the next upgrade walks the driver, CUDA and kernel packages off the tested set. Recovery is a re-image, not a rollback. Instead: a static or prebuilt binary into ~/.local/bin, uv for anything Python (uv tool install / uv add), or a container for anything that really wants a distro - running apt INSIDE a container image is fine and is allowed. Read-only apt is fine (apt list, apt show, apt-cache, dpkg -l). See security.md S10 and the env-uv skill. If you are certain this specific package is safe and vendor-sanctioned, the user must run it themselves - outside this session." >&2
    exit 2
  fi
fi

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
#     mutation — the claude-for-ai-platforms role is deliberately least-privilege; widening it is a
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
