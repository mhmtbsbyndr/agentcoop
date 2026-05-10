# attribution-check should list both git authors and coop agents so the
# operator can spot identity mismatches.

cd "$COOP_ROOT"
git_init_with_commit "Alice Author" "alice@example.com" "first"

coop log DECISION --agent claude --payload '{"x":1}' >/dev/null

out=$(coop_observe attribution-check 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "attribution-check returns 0"
assert_contains "Git authors"   "$out" "has git-authors header"
assert_contains "Alice Author"  "$out" "lists git author"
assert_contains "Coop agents"   "$out" "has coop-agents header"
assert_contains "claude"        "$out" "lists claude (from logged event)"
assert_contains "system"        "$out" "lists system (from INIT)"
