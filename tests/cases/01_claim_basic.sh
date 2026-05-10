# Claim a single file as a single agent. Verify exit code, output,
# and that the claim is reflected in both events.jsonl and claims.json.

out=$(coop claim README.md --agent alice --reason "first" --ttl-min 30 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "claim returns 0"
assert_contains "Claimed README.md" "$out" "stdout confirms claim"
assert_eq "2" "$(events_count)" "events.jsonl has INIT + CLAIM (2 lines)"
assert_eq "1" "$(claims_count)" "claims.json has exactly 1 claim"
assert_eq "alice" "$(json_get "$COOP_ROOT/.agent-coop/claims.json" "d['claims'][0]['agent']")" "claim.agent == alice"
assert_eq "README.md" "$(json_get "$COOP_ROOT/.agent-coop/claims.json" "d['claims'][0]['path']")" "claim.path == README.md"
assert_eq "first" "$(json_get "$COOP_ROOT/.agent-coop/claims.json" "d['claims'][0]['reason']")" "claim.reason == first"
