# Invalid JSON in --payload should fail (exit 1) and must NOT pollute
# the event log with a malformed entry.

out=$(coop log NOTE --agent alice --payload 'not json at all' 2>&1)
exit_code=$?

assert_exit 1 "$exit_code" "invalid JSON returns 1"
assert_contains "Invalid JSON" "$out" "stderr explains the JSON error"
assert_eq "0" "$(events_grep_count '"type": "NOTE"')" "no NOTE event was appended"
