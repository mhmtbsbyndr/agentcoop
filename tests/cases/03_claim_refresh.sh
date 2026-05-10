# Same agent reclaims the same file. Should refresh the existing claim
# in place (not error, not duplicate) and update the reason/expiry.

coop claim README.md --agent alice --reason "first"  --ttl-min 5  >/dev/null
coop claim README.md --agent alice --reason "second" --ttl-min 30 >/dev/null
exit_code=$?

assert_exit 0 "$exit_code" "refresh by same agent succeeds"
assert_eq "1" "$(claims_count)" "still 1 claim (refreshed, not duplicated)"
assert_eq "second" "$(json_get "$COOP_ROOT/.agent-coop/claims.json" "d['claims'][0]['reason']")" "reason updated to 'second'"
