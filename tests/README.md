# agent-coop tests

Black-box tests that exercise the `coop` and `coop-observe` CLIs the same
way an agent would. Each case runs in an isolated `COOP_ROOT` (fresh
`mktemp -d`), so your real `.agent-coop/` is never touched.

## Run

    ./tests/run.sh

Exit 0 if every assertion passes, 1 otherwise. On failure each `[FAIL]`
line prints the expected and actual values side by side.

## Layout

    tests/
    |-- run.sh           # runner; sets up/tears down per case, prints summary
    |-- lib.sh           # helpers: setup, assertions, JSON readers
    `-- cases/           # alphabetical run order
        |-- 01_claim_basic.sh
        |-- 02_claim_conflict.sh
        |-- 03_claim_refresh.sh
        |-- 04_release_basic.sh
        |-- 05_release_no_claim.sh
        |-- 06_claims_empty.sh
        |-- 07_claims_listing.sh
        |-- 08_log_decision.sh
        |-- 09_log_invalid_json.sh
        |-- 10_events_filter_agent.sh
        |-- 11_events_filter_since.sh
        |-- 12_status_counts.sh
        |-- 13_ttl_prune.sh
        |-- 14_observe_snapshot.sh
        |-- 15_observe_attribution.sh
        `-- 16_observe_report.sh

## What each case checks

| #  | Case                       | Checks                                                         |
|----|----------------------------|----------------------------------------------------------------|
| 01 | claim_basic                | exit 0, stdout, events.jsonl row, claims.json fields           |
| 02 | claim_conflict             | exit 2, CONFLICT in stderr, original owner unchanged           |
| 03 | claim_refresh              | same agent re-claim updates in place (no duplicate row)        |
| 04 | release_basic              | claim removed, RELEASE event appended                          |
| 05 | release_no_claim           | exit 1, no phantom RELEASE event                               |
| 06 | claims_empty               | "No active claims" on fresh repo                               |
| 07 | claims_listing             | two distinct claims both shown                                 |
| 08 | log_decision               | DECISION event present with payload preserved verbatim         |
| 09 | log_invalid_json           | exit 1 on bad payload, log not polluted                        |
| 10 | events_filter_agent        | --agent filter excludes other agents                           |
| 11 | events_filter_since        | --since cutoff excludes earlier events                         |
| 12 | status_counts              | aggregates by type and by agent                                |
| 13 | ttl_prune                  | expired claim pruned on next read (deterministic, no sleep)    |
| 14 | observe_snapshot           | observations.jsonl created and appended to                     |
| 15 | observe_attribution        | lists both git authors and coop agents                         |
| 16 | observe_report             | aggregates events, surfaces DECISION/DISAGREE samples          |

## Adding a case

Drop a file into `cases/`. `run.sh` sources it after `setup_coop_root` has
created an isolated env, then calls `teardown_coop_root` afterwards. Use
the helpers from `lib.sh`:

    coop / coop_observe         # invoke the CLIs (uses $COOP_ROOT)
    assert_eq / assert_contains / assert_not_contains
    assert_exit / assert_file_exists
    events_count / claims_count / events_grep_count / json_get

## What these tests do NOT cover

- Concurrent agent collisions (no real file locking — single-writer assumed)
- Wall-clock TTL expiration (case 13 injects a stale claim instead)
- Real git history beyond a single empty commit
- Performance / large-event-log scaling

These are honest gaps. Add cases as the V1 experiment surfaces real bugs;
do not add coverage for hypothetical ones.
