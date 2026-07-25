#!/usr/bin/env python3
"""PostToolUse(Edit|Write) hook: format and validate manifests after an edit. Never blocks.

The formatter tier, mirroring `validate-python.py`: cheap, automatic, and it always exits 0. Anything
that should *stop* a write lives in `guard-k8s-manifests.py` / `guard-iac.py` (PreToolUse, exit 2).

  .tf / .tfvars     -> `terraform fmt` (or `tofu fmt`)
  .yaml / .yml      -> `kubeconform` schema validation, if the file is a Kubernetes resource

Every tool is optional. If it isn't installed, this hook does nothing — a validation hook that
requires a toolchain nobody has is a hook people delete. Findings are written to stderr as advice;
the write has already happened either way.

Fail-open on everything: unparseable stdin, missing tool, timeout -> exit 0 silently.
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

TIMEOUT = 20


def run(cmd: list[str], **kw) -> tuple[int, str]:
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT, **kw)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except Exception:
        return 0, ""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    path = (payload.get("tool_input") or {}).get("file_path", "")
    if not path:
        return 0
    p = Path(path)
    if not p.is_file():
        return 0

    # --- Terraform: format in place -------------------------------------------------------
    if p.suffix in (".tf", ".tfvars"):
        for exe in ("terraform", "tofu"):
            if shutil.which(exe):
                run([exe, "fmt", str(p)])
                break
        return 0

    # --- Kubernetes YAML: schema validation ------------------------------------------------
    if p.suffix in (".yaml", ".yml"):
        try:
            text = p.read_text(errors="replace")
        except Exception:
            return 0
        if "apiVersion:" not in text or "kind:" not in text:
            return 0  # not a Kubernetes resource
        if not shutil.which("kubeconform"):
            return 0
        code, out = run(
            [
                "kubeconform",
                "-strict",
                "-ignore-missing-schemas",  # CRDs we don't have schemas for are not failures
                "-summary",
                str(p),
            ]
        )
        if code != 0 and out.strip():
            sys.stderr.write(
                f"[validate-manifests] kubeconform reported issues in {path} "
                "(advisory — the write succeeded):\n"
                + "\n".join(out.strip().splitlines()[:12])
                + "\n"
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
