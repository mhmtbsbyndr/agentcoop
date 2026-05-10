# `coop events --agent <name>` should return only events from that agent.

coop log DECISION --agent alice --payload '{"x":1}' >/dev/null
coop log DECISION --agent bob   --payload '{"x":2}' >/dev/null

out=$(coop events --agent alice 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "events --agent returns 0"
assert_contains      "alice" "$out" "alice's event present"
assert_not_contains  "bob"   "$out" "bob's event filtered out"
