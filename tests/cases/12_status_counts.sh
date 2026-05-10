# `coop status` aggregates events by type and agent. Verify both axes.

coop log DECISION --agent alice --payload '{"x":1}' >/dev/null
coop log RISK     --agent bob   --payload '{"y":2}' >/dev/null

out=$(coop status 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "status returns 0"
assert_contains "Events:"       "$out" "shows event total"
assert_contains "DECISION"      "$out" "shows DECISION type"
assert_contains "RISK"          "$out" "shows RISK type"
assert_contains "alice"         "$out" "shows alice in agent breakdown"
assert_contains "bob"           "$out" "shows bob in agent breakdown"
assert_contains "Active claims" "$out" "shows active-claims line"
