# Stale (expired) claim should be pruned the next time `coop claims` runs.
# We inject a long-expired claim directly so the test is deterministic
# (no real wall-clock sleeping).

python3 - <<'PY'
import json, os
path = os.path.join(os.environ['COOP_ROOT'], '.agent-coop', 'claims.json')
data = {"claims": [{
    "agent":      "ghost",
    "path":       "old.md",
    "reason":     "long ago",
    "claimed_at": "2020-01-01T00:00:00Z",
    "expires":    "2020-01-01T00:30:00Z",
}]}
with open(path, "w") as f:
    json.dump(data, f)
PY

out=$(coop claims 2>&1)
exit_code=$?

assert_exit 0 "$exit_code" "claims returns 0"
assert_contains "No active claims" "$out" "stale claim was pruned from output"
assert_eq "0" "$(claims_count)" "claims.json now empty (pruned to disk)"
