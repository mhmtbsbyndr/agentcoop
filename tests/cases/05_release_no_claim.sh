# Releasing a file you don't hold should fail loudly (exit 1) and not
# log a phantom RELEASE event.

out=$(coop release README.md --agent alice 2>&1)
exit_code=$?

assert_exit 1 "$exit_code" "release of non-existent claim returns 1"
assert_contains "No active claim" "$out" "error explains the situation"
assert_eq "0" "$(events_grep_count '"type": "RELEASE"')" "no RELEASE event was logged"
