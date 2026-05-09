# agent-coop (V1)

Minimal coordination layer for multiple coding agents (Claude Code, Codex,
opencode, ...) working on the same project folder.

## Design principle

Two pieces of ground truth:
- `events.jsonl` — append-only log of everything that happened
- `claims.json` — current file ownership with TTL (rebuildable from events)

Everything in `derived_state/` is regeneratable view material. Delete it
anytime; it will be rebuilt.

## Setup

1. Copy `coop`, `coop-observe`, and `.agent-coop/` into your project root.
2. Make both executable: `chmod +x coop coop-observe`
3. Give each agent the contents of `AGENT_PROTOCOL.md` as part of its
   system prompt or project instructions.
4. Tell each agent its name. For Claude Code, put the protocol in
   `CLAUDE.md`. For Codex, in `AGENTS.md` (or equivalent). For opencode,
   in its project config.
5. Configure git so each agent commits under a distinguishable identity
   (run `./coop-observe attribution-check` to verify).

## Running

The agents do their normal work, but use `./coop` calls instead of editing
shared coordination files. Run them in parallel terminals; the claim system
prevents collisions.

`coop-observe snapshot` runs periodically (cron, or after each agent call)
to record what actually happened. Read `coop-observe report` at end of week.

## What this is NOT

- Not a multi-agent orchestrator. The agents still need to be invoked by you
  or by an external script.
- Not a semantic merge engine. Conflicts in actual code still resolve via git.
- Not a memory system. Long-term memory is whatever stays in the event log.
- Not opinionated about what makes a "good" event. The agents will misuse it
  at first. That's data.
- Not enforced. `coop` is advisory. Whether agents follow the protocol is
  itself one of the things V1 measures.

## Empirical questions V1 should answer

Run this on a real project for a week. Observe:

1. **Do agents actually use `coop` as instructed?**
   Check via `coop-observe report`: ratio of file-changes with matching
   claim vs. without. If <80%, the protocol is being ignored.

2. **Do real conflicts emerge?**
   Check: how often does CLAIM exit non-zero? If never, claims are theater.
   If constantly, file granularity is wrong.

3. **Is multi-agent output better than single-agent?**
   Check: pick 5 tasks. Do half with one agent, half with the coop setup.
   Compare PR quality, time, cost. Honestly. This is the load-bearing
   question — if the answer is "no", everything else is wasted complexity.

4. **What information goes missing?**
   Check: at end of week, can you reconstruct *why* each non-trivial change
   was made from the event log alone? If not, agents are under-logging
   DECISIONs.

5. **What disagreements are real vs. stochastic?**
   Check: when DISAGREE events fire, re-run the same task with the same
   agent. If the disagreement disappears, it was sampling noise, not
   epistemic conflict.

6. **What rules break first?**
   Check: which protocol rule has the highest violation rate? That's the
   one that's either wrong or under-motivated.

## What V1 deliberately omits

- No vector memory. (Embeddings ≠ relevance, and we don't have data yet.)
- No architect agent. (Single point of hallucination risk.)
- No semantic diff layer. (Without ground-truth anchoring, this hallucinates
  shared reality.)
- No reversibility scoring. (Heuristic only in protocol; mechanize once we
  see real damage patterns.)
- No conflict resolution beyond "one claim wins, the other logs DISAGREE."
- No enforcement (git hooks, FS proxy). Adding enforcement before measuring
  voluntary compliance answers a different research question.

These may be added in V2 — but only if V1 usage *demands* them, not because
they sound clever.

## Kill criteria (write these on Day 1, before the data comes in)

V1 is discarded or fundamentally rethought if, after one week:
- Single-agent + good context outperforms multi-agent on real tasks
- The human spends more time coordinating than the agents save
- The event log cannot reconstruct why non-trivial changes were made

These are not pass/fail thresholds with crisp numbers, because crisp numbers
invented before data are theater. They are honest questions to answer with
field notes.

## File layout

    your-project/
    ├── coop                          # the intervention CLI
    ├── coop-observe                  # the passive observation CLI
    ├── AGENT_PROTOCOL.md             # given to each agent
    ├── OBSERVE_README.md             # how to use coop-observe
    ├── .agent-coop/
    │   ├── events.jsonl              # append-only, ground truth
    │   ├── claims.json               # current claims, derived from events
    │   ├── observations.jsonl        # coop-observe's own append-only log
    │   └── derived_state/            # ephemeral views, regeneratable
    └── ...your actual code...
