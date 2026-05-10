# Two distinct claims by two agents on two paths should both show up.

coop claim README.md         --agent alice --reason "rA" --ttl-min 30 >/dev/null
coop claim AGENT_PROTOCOL.md --agent bob   --reason "rB" --ttl-min 30 >/dev/null

out=$(coop claims 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "claims returns 0"
assert_contains "alice"             "$out" "lists alice"
assert_contains "bob"               "$out" "lists bob"
assert_contains "README.md"         "$out" "lists README.md"
assert_contains "AGENT_PROTOCOL.md" "$out" "lists AGENT_PROTOCOL.md"
assert_eq "2" "$(claims_count)" "claims.json has 2 claims"
