---
name: infra-aws
description: >
  AWS for DS infrastructure — S3 + Redshift via the AWS CLI and boto3, acting through a
  least-privilege `claude-for-datascience` IAM role (starter policy:
  `.claude/templates/aws-iam-policy.json`). Carries: the role model (project-prefixed resource
  ARNs, read-heavy defaults, explicit denies on bucket/cluster deletion and all IAM mutation),
  credential hygiene (named profiles / SSO — keys never in the repo or transcript), S3 data
  plumbing (buckets as DVC remotes, `aws s3 sync`, versioning + lifecycle for raw immutability),
  Redshift access (UNLOAD/COPY through S3, the Data API; query discipline stays in `sql`), cost
  awareness (know what a command spends before running it), and the first-time setup walkthrough
  (CLI install without sudo, SSO-vs-keys auth done on the human's side, creating the identity +
  attaching the policy, verifying the boundary). Load when provisioning or touching AWS — or
  when `aws` isn't installed yet. Triggers: AWS, S3, bucket, boto3, aws cli, IAM, role,
  Redshift, UNLOAD, COPY, s3 sync, presigned URL, cloud storage, DVC remote s3, aws profile,
  SSO, install aws cli, aws configure, aws not found, set up the role, connect to AWS.
---

# infra-aws — AWS through a role that can't hurt you much

**Pinned:** awscli, boto3 — unpinned · authored 2026-07-18 · run `/skill-update infra-aws` once
the deps are installed (`uv add boto3`; the CLI installs system-side)

> On-demand: load this when the project's infrastructure is AWS. The **boundary is the IAM
> policy, not this skill's judgment** — same philosophy as the repo's security model (hooks are
> guardrails; permissions are the boundary), extended to the cloud. Scope v1: **S3 + Redshift**.
> SageMaker/EC2 are deliberately out until demand shows. Credential *policy* lives in the
> security canon (`governance` → `security.md` `S8`); warehouse query discipline is `sql`.
>
> **Neighbours:** provisioning AWS resources declaratively is `iac-terraform` (do not click in the
> console — a resource created by hand is drift by definition). Workload access to AWS APIs should
> use **IRSA / EKS Pod Identity**, not stored keys — that's `authn-authz` `I3`, and it is the
> preferred answer whenever a pod needs S3 or Redshift. EKS cluster configuration and workloads are
> `kubernetes`; secret storage in Secrets Manager/SSM is `secrets-management`; CI reaching AWS uses
> **OIDC federation, never a stored access key** (`supply-chain.md` `C6`).

## The role model — set up once, by the human
Claude acts through a dedicated **`claude-for-datascience`** IAM identity whose policy is the
blast radius. Starter policy: `.claude/templates/aws-iam-policy.json` — copy it, replace
`PROJECT-PREFIX` (S3 bucket prefix), `ACCOUNT-ID`, `REGION`, `CLUSTER-NAME`, `DB-NAME`, and `DB-USER`, review it
yourself, then attach it. Its shape, which the human should verify survives their edits:
- **Project-prefixed ARNs only** — `arn:aws:s3:::PROJECT-PREFIX-*`; the role cannot see other
  buckets' contents.
- **Explicit `Deny` on the catastrophic tier** — `s3:DeleteBucket`, `redshift:DeleteCluster`,
  and **all `iam:*`** (the role must never be able to widen itself). Deny beats any Allow,
  including ones added later by mistake.
- Turn **CloudTrail on** for the account and enable **S3 versioning** on project buckets —
  auditability and undo are part of least privilege.
- Prefer an assumable **role** (SSO / `aws configure sso`) over long-lived user keys; either
  way the credentials live in `~/.aws/` or the environment — **never** in the repo, `.env`
  included (`.env` holds app config; AWS credentials have their own store).

Sanity check before any work: `aws sts get-caller-identity` — confirm you are the scoped role,
not someone's admin profile.

**Every bucket/cluster provisioned gets a row in the resource matrix**
(`.claude/memory/process/resources.md`) + its env keys in `.env.example`, same commit — the
matrix is how the rest of the stack knows where everything is accessed and where each
credential lives (by reference).

## First-time setup — the walkthrough (agent and human each have a part)
Run this top to bottom when AWS work starts on a fresh box. Steps are split deliberately:
the agent does the mechanical parts; the human does everything that touches admin power or a
secret.

**1. CLI present?** `command -v aws || aws --version`. If missing, two install paths:
- **Agent-runnable, no sudo:** download the official v2 bundle and install user-local —
  `curl -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"`,
  `unzip`, then `./aws/install -i ~/.local/aws-cli -b ~/.local/bin` (ensure `~/.local/bin` is
  on PATH). Never pipe the download into a shell (the bash hook blocks it anyway); the
  system-wide install needs sudo, which this agent deliberately cannot run — that variant is
  the human's, via the `!` prefix in their prompt.
- `uv add boto3` for the Python side (per `env-uv`; it shares the CLI's credential chain).

**2. Authenticate — on the human's side, always.** Access keys and SSO logins must never pass
through the chat (a pasted secret lives in the transcript forever — security canon). Ask the
user to run, in their own terminal or via the `!` prefix:
- **Preferred:** `aws configure sso` (short-lived credentials; needs the org's SSO start URL),
  then `aws sso login --profile <profile>` when sessions expire.
- **Fallback:** `aws configure --profile claude-ds` with an access key **they** created for the
  scoped identity (console → IAM → the user → security credentials). The agent's job is to say
  *which identity* the key must belong to — never to receive the key.
Set the project to the profile via config/env (`AWS_PROFILE=claude-ds` in `.env` is fine —
it's a *name*, not a secret).

**3. Create the identity + attach the policy — human, with their admin profile.** The agent
prepares; the human executes (the agent's own role has `iam:*` denied, and the hook asks on
any `aws iam` mutation — both by design). Prepare for them: the filled-in policy JSON (from
the template, placeholders replaced), and this sequence —
```bash
aws iam create-policy --policy-name claude-for-datascience \
    --policy-document file://aws-iam-policy.filled.json
aws iam create-user --user-name claude-for-datascience        # or create-role + trust policy for SSO/assume
aws iam attach-user-policy --user-name claude-for-datascience \
    --policy-arn arn:aws:iam::ACCOUNT-ID:policy/claude-for-datascience
```
Console clicking works identically (IAM → Policies → Create from JSON → attach). Either way,
**the human reads the policy before attaching** — the review is the point, not a formality.

**4. Verify the boundary, both directions.** As the new profile:
`aws sts get-caller-identity` (the scoped identity, not admin) ·
`aws s3 ls s3://PROJECT-PREFIX-data` (allowed path works) · and one **expected failure**, e.g.
`aws iam list-users` — it must be denied. A boundary you never saw refuse anything is a
boundary you haven't tested.

## S3 — the project's durable data layer
- **Bucket convention:** `PROJECT-PREFIX-data` (raw + processed, versioned, lifecycle to IA/
  Glacier for old raw), `PROJECT-PREFIX-artifacts` (checkpoints, exports — the DVC remote).
- **DVC remote:** `dvc remote add -d storage s3://PROJECT-PREFIX-artifacts/dvc` — then the
  existing `data-dvc` flow (push/pull, pin-to-commit) works unchanged; boto3/awscli creds are
  picked up automatically.
- **Moving data:** `aws s3 sync` (idempotent, resumable) over `cp` for trees; `--dryrun` first
  when the direction is `local → bucket` onto existing keys. Presigned URLs
  (`aws s3 presign`, expiry short) to hand a file to someone — never make a bucket public.
- **Raw immutability in the cloud:** versioning on + a lifecycle rule, and the deny on
  `DeleteBucket`; recursive `aws s3 rm` is confirm-gated by the bash hook.

## Redshift — the warehouse door (the queries themselves are `sql`)
- **Access:** the Data API (`aws redshift-data execute-statement` / boto3
  `redshift-data`) — no long-lived connections or passwords in code; auth rides the IAM role.
- **Bulk in/out goes through S3, always:** `UNLOAD ('SELECT ...') TO 's3://PROJECT-PREFIX-...'`
  for extracts (then the snapshot-what-training-eats rule from `sql` applies to the landed
  files), `COPY` from S3 for loads. Row-by-row inserts and `SELECT *` over the wire are the
  anti-pattern at warehouse scale.
- Training extracts landed from UNLOAD get versioned (`data-dvc`) and recorded in the dataset
  manifest with the query file + extract time.

## Cost awareness (cost bugs are silent like leakage bugs)
Know the pricing dimension before running: S3 = storage + requests + **egress** (a `sync` down
of a TB is a bill), Redshift = cluster-hours (or RPU-hours serverless) — don't leave clusters
running for a weekly query; lifecycle rules are the cheapest habit. Anything projected to cost
real money is a decision for the user, stated in dollars, before the command — and new
recurring costs get a decision-log line.

## Gotchas
- **Region mismatch** is the classic silent failure — bucket and cluster region pinned in
  config (`${oc.env:AWS_REGION}` via the config system), not defaulted per-shell.
- The hook confirm-gates `aws s3 rb`, recursive `s3 rm`, `redshift delete-*`, and any
  `aws iam` mutation — if the dialog surprises you, stop and re-read what you were about to do.
- boto3 pagination: list operations truncate at 1,000 — use paginators, or counts lie.
