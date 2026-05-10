# Log a structured DECISION event and verify it lands in the JSONL log.

out=$(coop log DECISION --agent alice --payload '{"topic":"db","choice":"postgres","reasoning":"team familiarity"}' 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "log returns 0"
assert_contains "Logged DECISION" "$out" "stdout confirms log"
assert_eq "1" "$(events_grep_count '"type": "DECISION"')" "1 DECISION event present"
assert_eq "1" "$(events_grep_count '"choice": "postgres"')" "payload.choice persisted verbatim"
