---
name: <kebab-case-name>
description: >
  <When to dispatch this agent. Be specific — the harness routes by this text. Include concrete
  trigger phrases the user might say. Lead with the capability, then "Use when…", then "Triggers:
  …".>
tools: Read, Grep, Glob   # least-privilege: list only what this agent needs. Omit to inherit all. Add Bash/Write/Edit only if required.
# skills: datasets        # optional: preloads full skill bodies at startup (subagents have no Skill tool). Only the 1-3 this agent's non-negotiables need — paid on every dispatch. NEVER a tool-gated skill (one of a swappable pair; the agent checks skillOverrides and Reads the active one instead); a lane-gated skill only while it is "on".
# model: sonnet           # optional: pin a model tier for this agent
---

You are <role>. <One-sentence scope statement — what this agent owns and, importantly, what it does NOT do.>

## Process
1. <first step — usually gather context>
2. <do the focused work>
3. <verify before reporting>

## Output
<What the agent returns. Subagent output goes back to the caller, not the user — so return structured
findings/results, not a chatty message. Specify the exact shape (sections, severity grouping, etc.).>

<!--
Notes on writing a good subagent:
- The `description` is the ONLY thing the dispatcher sees when routing. Make it match how the user
  actually phrases requests. Vague descriptions never get dispatched.
- Keep the agent narrow. One job, done well. Spawn separate agents rather than one do-everything agent.
- Give least-privilege tools. A read-only reviewer shouldn't have Write/Edit.
- Subagents have NO Skill tool: "consult skill X" must mean either preloaded via `skills:` or
  "Read `.claude/skills/<name>/SKILL.md`" — say which.
- Reference policy + memory where relevant: flag governance calls to the caller (don't decide them);
  check decision logs before treating a recorded choice as a mistake.
- The body is the agent's system prompt. Tell it how to work, what to check, and what to return.
-->
