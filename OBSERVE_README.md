# coop-observe (passive instrumentation for V1)

This tool watches V1 without changing it. Three commands:

    coop-observe snapshot              # capture state (run periodically)
    coop-observe report                # plain-text summary
    coop-observe attribution-check     # diagnose git-author/agent name mismatch

## What it does NOT do

- Block any agent action
- Modify `.agent-coop/` files
- Score agent behavior
- Decide what is "good" or "bad" coordination

If any of those become tempting later, that's V2 territory and a separate
decision.

## Setup

1. Drop `coop-observe` next to `coop`, `chmod +x` it.
2. Configure git so each agent commits under a distinguishable identity, OR
   add `Coop-Agent: <name>` trailers in commit messages. Otherwise the
   compliance numbers in `report` will be unreliable. Run
   `coop-observe attribution-check` after setup to verify.
3. Run `coop-observe snapshot` periodically. A simple cron entry works:

       */5 * * * * cd /path/to/project && ./coop-observe snapshot >> /tmp/coop-snap.log

   Or trigger after each agent invocation. Either is fine.

## What the report tells you

Six numbers, no verdicts:

- Event counts by type — are agents logging at all?
- Compliance ratio — file-changes matched vs. unmatched against active claims
- Attribution gaps — commits where author/agent linkage was unclear
- Claims expired without RELEASE — possible stale-claim incidents
- Events per agent — who's actually using the system
- DISAGREE/DECISION samples — read these by hand, they are signal

## Honest limitations

1. **Attribution is the weakest link.** If `git config user.name` is
   identical for all agents, the report cannot distinguish them. The
   `attribution-check` command will tell you if you have this problem.

2. **Compliance ratio counts file-changes, not intent.** Agent moves a file
   without claiming it = bypass. Agent claims `src/` and changes
   `src/auth.ts` = match. Both are crude. The number is a starting point
   for manual review, not a verdict.

3. **Working-tree changes are invisible** until committed. `snapshot`
   captures uncommitted state at run time, but `report` analyzes commits.
   If agents work without committing, you'll undercount.

4. **The observer effect is real but small.** Agents don't see this tool
   unless you tell them. As long as `coop-observe` runs out-of-band, V1
   behavior is uncontaminated.

## What to write in feldnotes alongside

The numbers are necessary but not sufficient. Each day, write 2-3 sentences
on:

- What surprised me?
- Did anything actually break?
- Did multi-agent feel useful, or like ceremony?
- One quote/example that captures today

These notes are what makes the V2 decision possible.

## When to look at the report

Not daily. Looking too often invites premature interpretation.

Suggested cadence:
- Day 3: quick glance, sanity check (is data being captured?)
- Day 7: full read, paired with feldnotes
- End of week 1: decide

Looking at the report after every agent invocation defeats the purpose.
