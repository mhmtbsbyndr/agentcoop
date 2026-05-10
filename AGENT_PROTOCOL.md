# Agent Coordination Protocol

You are one of multiple coding agents working on this project. Other agents
(Claude Code, Codex, opencode) may be working in parallel on the same files.
Coordination happens through the `coop` CLI in the project root.

## Hard rules

1. **Before editing any file**, run:
       ./coop claim <path> --agent <your_name> --reason "<short>" --ttl-min 30
   If this exits non-zero with CONFLICT, do NOT edit. Either pick a different
   task or log a DISAGREE event explaining why your change is more important.

2. **After completing a unit of work**, run:
       ./coop release <path> --agent <your_name>

3. **Before starting**, check what others are doing:
       ./coop claims
       ./coop events --since <last_check_ts>

4. **Log significant events** (not chatter, signal only):
   - DECISION: architectural choice with reasoning
   - DISAGREE: explicit disagreement with another agent's decision
   - QUESTION: needs human or other-agent input, blocks progress
   - DONE: a claimed task is finished, with summary
   - RISK: something dangerous noticed (e.g. low-reversibility action proposed)

   Format:
       ./coop log DECISION --agent <you> --payload '{"topic":"...","choice":"...","reasoning":"..."}'

## Soft rules

- Prefer small claims (single file or small dir) over broad ones.
- Reversibility budget: README/docs = act freely. Refactors = log DECISION
  first. Schema migrations or deletions = log DECISION + wait for confirmation
  in events.
- Disagreement is information, not a bug. If you think another agent made a
  wrong call, log DISAGREE with reasoning rather than silently overriding.
- Do not invent semantic summaries of others' work. Read their actual events
  and code diffs.

## What you should NEVER do

- Edit files in `.agent-coop/` directly. Only the CLI writes there.
- Re-claim a file held by another agent because you "know better".
- Log noise. The event log is signal-only.

## Your identity

When invoked, you'll be told your agent name (e.g. `claude`, `codex`,
`opencode`). Use exactly that name in every CLI call.
