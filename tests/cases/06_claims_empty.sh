# `coop claims` on a fresh repo says so explicitly and exits 0.

out=$(coop claims 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "claims returns 0 when empty"
assert_contains "No active claims" "$out" "states that no claims exist"
