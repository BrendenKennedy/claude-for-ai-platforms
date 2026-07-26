# Authoring a `.claude/` extension — skills, agents, commands, hooks

The how-to for adding to this repo's own config. Pulled on demand (it's rare work, so it doesn't sit
on the always-on skill surface). Discovered via the row in the CLAUDE.md map.

The four extension types and where each lives:

| Type | Path | Routes / fires by | Registered in |
|---|---|---|---|
| **Skill** | `.claude/skills/<name>/SKILL.md` | its `description` (auto-surfaced) | CLAUDE.md map; tool skills also in `settings.json` `skillOverrides` |
| **Agent** | `.claude/agents/<name>.md` | its `description` (dispatcher routes) | CLAUDE.md map |
| **Command** | `.claude/commands/<name>.md` → `/<name>` | user types the slash command | CLAUDE.md map |
| **Hook** | `.claude/hooks/<name>.{sh,py}` | a tool event + matcher | `settings.json` `hooks` **and** CLAUDE.md map |

Each type ships a scaffold — copy it, don't start blank: `skills/_example/`, `agents/_TEMPLATE.md`,
`commands/_TEMPLATE.md`. Hooks have no template; copy the closest existing one.

## Rules that apply to all four

- **The `description` is the entire routing surface.** For skills and agents it's the *only* text the
  matcher sees — not the body. Vague descriptions never fire. Pack it with the concrete words the user
  will actually type.
- **Descriptions have a hard budget — front-load or get truncated.** The skill listing truncates each
  entry at **1,536 chars (tail first)** and the whole listing shares a budget (~1% of the context
  window; overflow drops least-used skills' descriptions entirely). So: first sentence = domain + use
  case, then `Load when <tasks>`, then `Triggers:` ranked **sharpest first** — a trigger after
  char ~1,200 may not exist as far as routing is concerned. Target **≤1,000 chars**. Every always-on
  description is paid for in every session; earn it.
- **User-run-only? Take it off the context bill.** `disable-model-invocation: true` removes a
  skill/command's description from the session listing entirely — `/name` still works. Use it for
  one-time commands (`/setup`, `/intake`, `/bootstrap`) and template placeholders; never for anything
  the model itself must invoke (`/gate`, `/wrapup` stay listed).
- **kebab-case names.** For a skill, the directory name and the `name:` field must match
  (`skills/foo-bar/SKILL.md` → `name: foo-bar`).
- **Register it in the CLAUDE.md map.** The map is loaded every session and is how anything gets
  discovered. An unregistered extension is invisible until someone stumbles on the file. This step is
  not optional — it's the difference between "exists" and "gets used."
- **YAML frontmatter must parse on GitHub.** A folded scalar (`description: >`) needs its body indented
  under it; a bare `>` with a flush-left next line breaks GitHub's parser (we've been bitten — see
  commit "Fix YAML frontmatter GitHub can't parse"). When in doubt, keep frontmatter values simple.
- **Earn the surface.** Deep knowledge with real triggers → a skill. Recurring how-to with no natural
  trigger → a `reference/` note (like this file). One-off "what happened" → `sessions/`. Don't make a
  skill for something touched once a quarter; it costs description budget every session forever.

---

## Skills — `skills/<name>/SKILL.md`

On-demand expertise. Loaded only when the `description` matches, so it can be long and detailed.

**Description formula** (from `_example` — front-loaded, ≤1,000 chars, see the budget rule above):
> `<Domain/contract in one clause> — <what it carries: the 3–5 specifics an agent can't guess>. Load when <the tasks it covers>. Triggers: <phrases the user will actually type, sharpest first>. <Optional one-clause scope boundary — what belongs to a sibling skill>.`

**Three tiers — decide which before writing:**
- **Always-on** (chassis + workflow) — process skills and archetype-agnostic DS domain skills. Not
  listed in `skillOverrides`; always active. Add a row to the right CLAUDE.md list.
- **Tool-gated** — one tool per skill (a tracker, a config lib, …). Add a `skillOverrides` entry in
  `settings.json` (`"<name>": "on"|"off"`) and let `/intake` flip it. This is how MLflow⇄W&B or
  Hydra⇄OmegaConf swap without touching the always-on skills that reference them. Carries a
  `**Pinned:**` version line (see the tool-skill rule below).
- **Lane-gated** — a whole workflow lane flipped by project *archetype* (tabular, timeseries, LLM,
  sql, serving, …): same `skillOverrides` mechanism, but `/intake` flips it from the step-0
  definition doc rather than a stack question. Off = zero context cost — a CV user never pays for
  the tabular lane; gated descriptions may run longer than always-on ones.

**Body shape:** `When this applies` (mirrors the triggers) → `The facts` (commands, versions, contracts,
exact configs — the specifics an agent can't guess) → `How to do X` → `Gotchas`. Tables and code blocks
freely.

**Supporting files** can sit alongside `SKILL.md` (scripts, longer references); link with relative
paths and they're read on demand — keeps `SKILL.md` scannable.

**One skill = one domain.** If it sprawls, split it. A stale skill is worse than none — keep it current.

**Tool skills carry a version pin.** A `**Pinned:** <pkg>==<version> · verified <date>` line sits
directly under the H1 — the version the skill's facts were last verified against, which must track
the *locked dependency*, never lead it. `/skill-update` owns bumps (drift check → changelog research
→ empirical verify → edit → pin). Git history is the archive of older skill versions — no parallel
old copies in the tree.

---

## Agents — `agents/<name>.md`

A focused subagent the dispatcher hands work to. Read the scaffold at `agents/_TEMPLATE.md`.

**Frontmatter:**
```yaml
name: <kebab-case-name>
description: >
  <Lead with the capability, then "Use when…", then "Triggers: …">
tools: Read, Grep, Glob   # least-privilege — list only what it needs; omit to inherit all
# model: sonnet           # optional tier pin
```

**Conventions that bite:**
- **Description = capability → "Use when…" → "Triggers:".** Match how users actually phrase requests.
  It's the only thing the dispatcher routes on.
- **Subagents have no Skill tool — wire skills deliberately.** `skills:` in the frontmatter preloads
  full skill content at startup. Preload only the **1–3** skills the agent's non-negotiables depend
  on — it is paid on every dispatch. Two hard limits, both about *interchangeability*:
  - **Never preload a tool-gated skill** (`tracking-mlflow`⇄`tracking-wandb`,
    `config-hydra`⇄`config-omegaconf`, …). One of a swappable pair is the wrong one half the time —
    the agent checks `settings.json` `skillOverrides` and Reads the active one's `SKILL.md` instead.
  - **A lane-gated skill may be preloaded only while it is `"on"`** in `skillOverrides`, and only by
    an agent that exists for that lane (`sre-analyst` → `reliability-sre, observability`;
    `threat-modeler` → `threat-modeling`). A lane skill has no sibling: it is on, or the agent
    depending on it should not be dispatched — say so in the agent's body. `check-scaffold.sh`
    enforces this.

  Any "consult skill X" line in an agent body must resolve to one of those two mechanics, or it's a
  dead reference.
- **Policy + memory wiring.** Agents flag governance calls to the caller, never decide them; before
  treating an odd-but-deliberate choice as a defect, they check the decision logs
  (`memory/policy/*-decision-log.md`, `memory/process/decision-log.md`). Planning-shaped agents also
  read `memory/process/project-definition.md` + `scope-ledger.md` (build inside the contract) and
  grep `memory/sessions/` before re-deciding something settled.
- **Least-privilege tools.** A read-only reviewer/analyst gets `Read, Grep, Glob` (+ `Bash` if it must
  run things) and **no** `Write`/`Edit`. Add write tools only for agents that build code
  (`ml-engineer`, `data-engineer`). See `code-reviewer` / `software-architect` (read-only) vs the
  builders for the pattern.
- **Narrow scope.** One job. The body's opening line states what it owns *and what it does NOT do*.
- **Body = system prompt.** Give it `Process` (gather → do → verify) and `Output`. Output goes back to
  the **calling agent, not the user** — return structured findings (sections, severity grouping), not a
  chatty message.

Register a row in the CLAUDE.md agents table.

---

## Commands — `commands/<name>.md`

A repeatable slash workflow. Filename is the command: `commands/deploy.md` → `/deploy`. Scaffold at
`commands/_TEMPLATE.md`.

**Frontmatter:**
```yaml
description: <one line, verb-first — shown in the slash-command list>
# argument-hint: <arg>        # optional usage hint
# allowed-tools: Bash, Read   # optional tool restriction for this command's run
```

**Body is the prompt** that runs, written as direct instructions to Claude. Substitutions:
- `$ARGUMENTS` — everything after the command; `$1`, `$2`, … positional.
- `` !`git diff` `` — runs bash and inlines the output (needs `allowed-tools: Bash`).
- `@path/to/file` — inlines that file's contents.

Keep commands task-shaped and deterministic. Existing ones (`/review`, `/wrapup`, `/intake`,
`/bootstrap`) are the reference. Register a row in the CLAUDE.md commands table.

---

## Hooks — `hooks/<name>.{sh,py}`

Code that fires automatically around tool calls. **Two-part job: write the script, then wire it in
`settings.json`.** For the `settings.json` wiring itself, defer to the **`update-config`** skill — it
owns that file; this section covers only the hook conventions this repo enforces.

**Contract:**
- Reads the tool payload as **JSON on stdin** — e.g. `payload["tool_input"]["file_path"]` (Edit/Write),
  or the raw shell string (Bash). Parse it, decide, exit.
- **Exit codes:** `0` = allow / pass. `2` = **block** — a `PreToolUse` denies the call; a `Stop` hook
  refuses to end the session; the message on **stderr** is surfaced to the agent. Other non-zero =
  error (treated as non-blocking depending on event).
- **Events + matcher** (as wired in `settings.json`): `PreToolUse`/`PostToolUse` take a **tool-name**
  matcher (`"Bash"`, `"Edit|Write"`); `SessionStart` takes a **source** matcher — not a tool name —
  (`"startup|clear"`, so a mid-work `resume`/`compact` doesn't re-fire); `Stop` takes none. See the
  `hooks` block for the exact shape.

**The two hard conventions here — both learned the hard way:**
1. **Fail-open on anything you can't handle.** Unparseable stdin, missing tool, timeout → `exit 0`
   silently. *"A guard that bricks the session is worse than a missed write / a hook that bricks
   sessions teaches people to delete it."* Every hook in this repo says this. Only fail **closed**
   (exit 2) on a genuine policy violation you're certain of.
2. **`Stop` hooks need a loop guard.** When a prior block already re-engaged the agent, the payload has
   `stop_hook_active: true` — check it and `exit 0`, or you ping-pong forever. See
   `run-leakage-tests.sh`.

**Reference implementations:**

| Want to… | Copy | Event · exit |
|---|---|---|
| block a dangerous/secret-leaking **edit** | `guard-secrets.py`, `guard-pyproject.py`, `guard-notebook-outputs.py` | PreToolUse Edit\|Write · exit 2 to block |
| block a **misconfigured manifest** (k8s, IaC) | `guard-k8s-manifests.py`, `guard-iac.py` | PreToolUse Edit\|Write · exit 2 to block |
| **confirm-gate** a change rather than block it | `guard-agent-config.py` | PreToolUse Edit\|Write · `permissionDecision: "ask"` |
| block a dangerous **shell** command | `validate-bash.sh` | PreToolUse Bash · block/ask/allow tiers |
| **format/lint** after an edit (never block) | `validate-python.py`, `validate-manifests.py` | PostToolUse Edit\|Write · always exit 0 |
| **annotate** content the agent just read | `scan-untrusted-content.py` | PostToolUse WebFetch\|Read · `additionalContext`, never blocks |
| run a **gate** before the session ends | `run-leakage-tests.sh`, `run-security-tests.sh` | Stop · exit 2 to block |
| **orient** the session at startup | `session-orient.py` | SessionStart startup\|clear · `additionalContext`, never blocks |

**Security-flavored hooks** (guards against secrets, destructive ops, egress) implement the security
canon — consult `governance` → `.claude/memory/policy/security.md` for what they must enforce, and keep
the guard and the policy in sync.

**Wiring:** add the hook under the right event in `settings.json` `hooks`, using
`$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.<ext>` as the command. Then register a row in the CLAUDE.md
hooks table. (`update-config` handles the settings.json edit correctly, including the matcher shape.)

---

## Policy canon — `memory/policy/<domain>.md`

Not an "extension" in the four-type sense (nothing routes on it), but it's authored work with rules
that bite, so it belongs here.

- **Canon is DATA; the `governance` skill is the PROTOCOL.** Policy text lives in exactly one canon
  file and is never copied into a skill, an agent body, or `CLAUDE.md` — those point at it.
- **Number your rules.** `data-governance.md` uses `## D1 — <title>` H2s with a closing `*Why: …*`;
  `model-governance.md` uses bold-inline `**M1 — …**` grouped under thematic H2s; `security.md` uses
  `S#`. Pick the sibling style closest to your domain and match it exactly. Numbering is what lets a
  decision log, a hook message, or a review finding cite one rule rather than gesture at a file.
- **Every rule carries a `why`.** A rule without one gets argued with; a rule with one gets followed.
- **Register it twice** — a row in the `governance` skill's Policy index *and* its sharp trigger
  words folded into that skill's `description`. Miss the second and the domain is unreachable:
  nothing surfaces `governance` for a change it should govern. `check-scaffold.sh` check 7 catches
  the missing row; nothing but review catches the missing triggers.
- **Don't pre-create the decision log.** It's created on the first judgment call, and its absence is
  meaningful — it means no exception has ever been granted.

### Framework docs — `memory/policy/frameworks/<framework>.md`

This scaffold sources its rules from published security frameworks, so canon may cite framework
control IDs (`[LLM01]`, `[ASI06]`, `[CIS 5.2.5]`). That is a deliberate change from the earlier
convention of zero external citations, recorded in `memory/process/decision-log.md`. The rule that
keeps it from becoming citation soup:

**Canon cites IDs; `frameworks/` holds the text.** No URLs, no framework prose, no version numbers in
a canon file — those live in the framework doc the ID resolves to. Format, lineage table, and
authoring rules: `memory/policy/frameworks/README.md`. Two things that fail CI: a framework doc
missing from the lineage table, and a canon citation whose ID resolves to nothing (check 8).

**Every framework doc carries `**Identity:**` and `**Verified:**` lines.** Security frameworks move
faster than tools do — an unversioned framework doc reads as current and silently isn't. Facts that
can't be confirmed against the publisher are written `unverified`, never guessed.

---

## Checklist before you're done

- [ ] File in the right place, kebab-case name (skill dir == `name:`).
- [ ] Frontmatter parses on GitHub; `description` packed with real trigger words.
- [ ] Least-privilege tools (agents/commands).
- [ ] Tool skill? → `skillOverrides` entry. Hook? → `settings.json` `hooks` entry (via `update-config`).
- [ ] **Row added to the CLAUDE.md map** — the discovery step. Without it, nothing routes.
- [ ] Cross-links added (`[[...]]` / relative paths) to related skills/policy.
