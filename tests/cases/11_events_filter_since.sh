# `coop events --since <iso>` returns only events with ts >= cutoff.
# We sleep to ensure timestamps differ at second granularity.

coop log DECISION --agent alice --payload '{"x":1}' >/dev/null
sleep 1
cutoff=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sleep 1
coop log DECISION --agent alice --payload '{"x":2}' >/dev/null

count=$(coop events --since "$cutoff" | wc -l | tr -d ' ')
out=$(coop events --since "$cutoff")

assert_eq "1" "$count" "exactly 1 event after cutoff"
assert_contains      '"x": 2' "$out" "later event present"
assert_not_contains  '"x": 1' "$out" "earlier event filtered out"
