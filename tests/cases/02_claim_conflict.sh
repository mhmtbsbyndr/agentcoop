# Two agents try to claim the same file. Second one must fail with
# CONFLICT (exit 2) and must not modify state.

coop claim README.md --agent alice --reason "first" --ttl-min 30 >/dev/null
out=$(coop claim README.md --agent bob --reason "second" --ttl-min 30 2>&1)
exit_code=$?

assert_exit 2 "$exit_code" "second claim returns 2 (CONFLICT)"
assert_contains "CONFLICT" "$out" "stderr contains CONFLICT"
assert_contains "alice" "$out" "stderr names original claimant"
assert_eq "1" "$(claims_count)" "still only 1 claim after conflict"
assert_eq "alice" "$(json_get "$COOP_ROOT/.agent-coop/claims.json" "d['claims'][0]['agent']")" "owner is still alice"
