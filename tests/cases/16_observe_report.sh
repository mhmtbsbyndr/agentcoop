# `coop-observe report` should aggregate events by type and surface
# DISAGREE/DECISION samples for human review.

cd "$COOP_ROOT"
git_init_with_commit "alice" "alice@example.com"

coop log DECISION --agent alice --payload '{"topic":"db","choice":"postgres","reasoning":"r"}' >/dev/null
coop log DISAGREE --agent bob   --payload '{"with":"alice","note":"prefer sqlite"}'           >/dev/null
coop claim README.md --agent alice --reason "x" --ttl-min 30 >/dev/null

out=$(coop_observe report 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "report returns 0"
assert_contains "Total events:" "$out" "has totals header"
assert_contains "CLAIM:"        "$out" "lists CLAIM count"
assert_contains "DECISION:"     "$out" "lists DECISION count"
assert_contains "DISAGREE:"     "$out" "lists DISAGREE count"
assert_contains "postgres"      "$out" "DECISION sample shows the choice"
assert_contains "prefer sqlite" "$out" "DISAGREE sample shows the note"
