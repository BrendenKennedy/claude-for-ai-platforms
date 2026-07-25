---
name: iac-terraform
description: >
  Infrastructure as code with Terraform/OpenTofu — declaring cloud and cluster infrastructure so it
  is reviewable, reproducible, and reversible. Carries: remote state with locking and why local
  state is a landmine, module structure and versioning, workspaces vs directories per environment,
  the plan-review discipline that makes IaC a control rather than a formality (reading a plan for
  destroys and replacements), secrets that must never enter state, drift detection, and the policy
  scanning that catches public buckets and wide-open security groups before apply. Load when
  provisioning infrastructure, reviewing a plan, structuring modules, wiring state, or debugging
  drift. Triggers: terraform, opentofu, tofu, IaC, infrastructure as code, terraform plan, terraform
  apply, terraform state, remote state, state lock, module, provider, drift, tfvars, checkov, tfsec,
  provision a cluster, security group, IAM policy in terraform. Cluster workloads are `kubernetes`;
  delivery is `gitops`; the musts are `policy/platform-security.md` and `policy/identity-and-access.md`.
---

# iac-terraform — infrastructure you can review, reproduce, and undo

**Pinned:** terraform / opentofu, checkov, tfsec — unpinned · authored 2026-07 · run
`/skill-update iac-terraform` once installed. OpenTofu is a drop-in fork of Terraform; everything
below applies to both unless noted.

> On-demand: load this when infrastructure is being declared or changed. The non-negotiable rules are
> canon: `platform-security.md` (`P5`, `P8`, `P10`), `identity-and-access.md` (`I3`), and
> `security.md` (`S8` — the agent never widens its own permissions). Workloads *on* the cluster are
> `kubernetes`; app delivery is `gitops`; scanning tools are `supply-chain-security`.

## When this applies

Provisioning anything. Reviewing a plan. Structuring modules. Wiring state. Chasing drift.

## State — get this right first

State maps your config to real resources. It is the single most consequential thing to configure, and
the most common source of catastrophe.

```hcl
terraform {
  required_version = "~> 1.9"
  backend "s3" {
    bucket       = "example-tfstate"
    key          = "platform/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true          # state contains secrets — see below
    use_lockfile = true          # S3-native locking
  }
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }   # pin providers (C1)
  }
}
```

- **Remote, encrypted, versioned, locked.** Local state means one laptop is the source of truth for
  production, and two people applying at once corrupts it.
- **State contains secrets in plaintext.** Any generated password, key, or sensitive output is in
  there whatever `sensitive = true` does to the *display*. Treat the state bucket like a credential
  store: encrypted, access-controlled, versioned, never public.
- **Separate state per environment.** One state file for dev+prod means a dev mistake can destroy
  prod.
- **Never edit state by hand.** `terraform state mv/rm` for surgery, with a backup first.

## Structure

```
infra/
  modules/
    network/            reusable, versioned, no environment-specific values
    eks-cluster/
  environments/
    dev/   main.tf terraform.tfvars backend.tf
    prod/  main.tf terraform.tfvars backend.tf
```

**Directories per environment, not workspaces.** Workspaces share a backend config and a code path;
the differences between dev and prod end up as conditionals inside the code, which is exactly where
you don't want them. Directories make the difference visible in a diff.

Modules: pin by version (registry) or by commit SHA (git source). A module referenced by branch is an
unpinned dependency (`C1`).

## The plan review — where IaC becomes a control

`terraform plan` is the highest-value security review in the infrastructure workflow, and it is
routinely skimmed. Read it for:

| Look for | Because |
|---|---|
| **`destroy`** | Data loss. Any destroy of a database, bucket, or volume is a stop-and-think |
| **`replace`** (`-/+`) | Destroy-then-create — an outage, and often data loss. `create_before_destroy` where possible |
| Resource **count** | "Change 3" when you expected 1 means your config touches more than you thought |
| **IAM / RBAC changes** | `S8` — is anything being widened? The agent never widens its own permissions |
| **Security group / firewall** rules | `0.0.0.0/0` on anything is a finding (`guard-iac.py` blocks it) |
| **Public access** flags | Bucket ACLs, public IPs, publicly accessible databases |
| **Encryption** flags flipping off | Silent downgrade |

```bash
terraform plan -out=tfplan            # always to a file
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions[] | . == "delete")'
terraform apply tfplan                # apply the reviewed plan, not a fresh one
```

**Apply the plan file you reviewed.** `terraform apply` without a plan file re-plans, and what runs
is not what you read.

`terraform destroy` and `apply` are confirm-gated by `validate-bash.sh`.

## Policy scanning before apply

Same three-layer idea as `policy-as-code`: catch it at the edit (`guard-iac.py`), at CI, and — where
the cloud supports it — at the provider.

```bash
checkov -d infra/ --framework terraform
trivy config infra/
terraform show -json tfplan | conftest test -p policies/ -    # policy against the PLAN, not the source
```

Testing the **plan** rather than the source is stronger: it evaluates what will actually exist,
including values that come from variables and data sources.

## Secrets

- **Never** hardcode a credential in `.tf` or commit a `.tfvars` containing one (`guard-secrets.py`
  blocks the write).
- Read from a secret manager as a data source, or inject via `TF_VAR_*` from CI's federated identity.
- **Prefer not generating secrets in Terraform at all** — anything it creates lands in state. Where
  the cloud can generate and store a secret itself (e.g. a managed rotation), let it.
- CI authenticates by **OIDC federation** (`I3`, `C6`), never a stored access key.

## Drift

Real infrastructure diverges — someone clicks in the console, an operator mutates a resource.

```bash
terraform plan -detailed-exitcode      # 0 = no drift, 2 = drift, 1 = error
```

Run it on a schedule in CI and alert on exit code 2. Drift is either a change to adopt into code or a
change to revert — deciding is the point, and undetected drift means the next apply reverts something
someone needed, at a time nobody chose.

## Gotchas

- **`terraform apply` without reading the plan.** The single most expensive habit here.
- **Local state.** Worth repeating.
- **Unpinned providers.** A provider major bump can change resource behaviour and force replacements.
- **`prevent_destroy` missing on stateful resources.** Add `lifecycle { prevent_destroy = true }` to
  databases, state buckets, and anything holding data.
- **Terraform-managing Kubernetes workloads.** It can, and it's usually the wrong tool — reconciliation,
  rollout status, and drift are what `gitops` does well. Use Terraform for the cluster and cloud
  resources; use GitOps for what runs on it.
- **Refactoring modules without `moved` blocks**, which produces a destroy/create for resources that
  merely got renamed.
- **A wildcard IAM policy because the narrow one didn't work.** It's a decision-log entry with a
  review date, not a fix.
