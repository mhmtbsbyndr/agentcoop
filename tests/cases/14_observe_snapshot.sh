# `coop-observe snapshot` should append to observations.jsonl. Needs git
# present in COOP_ROOT (snapshot reads HEAD/status).

cd "$COOP_ROOT"
git_init_with_commit "Test User" "test@example.com"

out=$(coop_observe snapshot 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "snapshot returns 0"
assert_contains "Snapshot @"   "$out" "stdout names a snapshot timestamp"
assert_file_exists "$COOP_ROOT/.agent-coop/observations.jsonl" "observations.jsonl was created"
assert_eq "1" "$(wc -l < "$COOP_ROOT/.agent-coop/observations.jsonl" | tr -d ' ')" "1 observation row"

# A second snapshot should append, not overwrite
coop_observe snapshot >/dev/null
assert_eq "2" "$(wc -l < "$COOP_ROOT/.agent-coop/observations.jsonl" | tr -d ' ')" "second snapshot appends"
