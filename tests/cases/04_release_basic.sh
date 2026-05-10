# Claim then release. Claim should disappear and a RELEASE event should
# be appended.

coop claim README.md --agent alice --reason "x" --ttl-min 30 >/dev/null
out=$(coop release README.md --agent alice 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "release returns 0"
assert_contains "Released README.md" "$out" "stdout confirms release"
assert_eq "0" "$(claims_count)" "no active claims after release"
assert_eq "1" "$(events_grep_count '"type": "RELEASE"')" "exactly 1 RELEASE event recorded"
