#!/usr/bin/env bash
# Black-box tests for `coop` and `coop-observe`.
#
#   bash tests/run_tests.sh                       # all tests
#   bash tests/run_tests.sh test_claim_conflict   # single test
#   bash tests/run_tests.sh test_a test_b         # selected subset
#
# Each test runs in an isolated sandbox (mktemp -d) with its own
# COOP_ROOT, so the real .agent-coop/ in the repo is never touched.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ----- per-test counters (reset by run_test) -----
PASS_COUNT=0
FAIL_COUNT=0

# ----- CLI shims (route via $COOP_ROOT) -----
coop()         { "$REPO_ROOT/coop" "$@"; }
coop_observe() { "$REPO_ROOT/coop-observe" "$@"; }

# ----- assertions -----
assert_eq() {
    local expected="$1" actual="$2" label="${3:-values}"
    if [ "$expected" = "$actual" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  [PASS] $label"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  [FAIL] $label"
        echo "         expected: $expected"
        echo "         actual:   $actual"
    fi
}

assert_exit() { assert_eq "$1" "$2" "${3:-exit code}"; }

assert_contains() {
    local needle="$1" haystack="$2" label="${3:-contains}"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  [PASS] $label"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  [FAIL] $label"
        echo "         needle:   $needle"
        echo "         haystack: $haystack"
    fi
}

assert_not_contains() {
    local needle="$1" haystack="$2" label="${3:-does not contain}"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  [FAIL] $label"
        echo "         unexpected: $needle"
    else
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  [PASS] $label"
    fi
}

assert_file_exists() {
    local path="$1" label="${2:-file exists: $1}"
    if [ -f "$path" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  [PASS] $label"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  [FAIL] $label (missing: $path)"
    fi
}

# ----- JSON / log readers (use python; no jq dependency) -----
events_count() {
    wc -l < "$COOP_ROOT/.agent-coop/events.jsonl" | tr -d ' '
}

claims_count() {
    python3 -c "import json; print(len(json.load(open('$COOP_ROOT/.agent-coop/claims.json'))['claims']))"
}

# grep -c already prints 0 on no-match (and exits 1); swallow with || true
events_grep_count() {
    grep -c -- "$1" "$COOP_ROOT/.agent-coop/events.jsonl" 2>/dev/null || true
}

# ----- sandbox lifecycle -----
setup_sandbox() {
    SANDBOX="$(mktemp -d)"
    mkdir -p "$SANDBOX/.agent-coop/derived_state"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"ts":"%s","agent":"system","type":"INIT","payload":{"note":"test init"}}\n' "$now" \
        > "$SANDBOX/.agent-coop/events.jsonl"
    printf '{"claims":[]}\n' > "$SANDBOX/.agent-coop/claims.json"
    export COOP_ROOT="$SANDBOX"
    cd "$SANDBOX"
}

teardown_sandbox() {
    cd "$REPO_ROOT"
    if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
        rm -rf "$SANDBOX"
    fi
    unset COOP_ROOT SANDBOX
}

# Use commit-tree plumbing instead of `git commit` so the call path
# does not invoke any commit-signing hook the test environment may have.
git_init_with_commit() {
    local name="${1:-Test User}"
    local email="${2:-test@example.com}"
    local message="${3:-init}"
    git init -q
    local tree commit
    tree=$(git write-tree)
    commit=$(GIT_AUTHOR_NAME="$name"   GIT_AUTHOR_EMAIL="$email" \
             GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
             git commit-tree "$tree" -m "$message")
    git update-ref HEAD "$commit"
}

# =====================================================================
# Test cases — see tests/README.md for the GIVEN/WHEN/THEN narration
# =====================================================================

test_claim_basic() {
    local out rc
    out=$(coop claim src/auth.ts --agent claude --reason "refactor" 2>&1)
    rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_contains "Claimed src/auth.ts" "$out" "stdout confirms claim"
    assert_eq "1" "$(claims_count)" "1 entry in claims.json"
    assert_eq "1" "$(events_grep_count '"type": "CLAIM"')" "CLAIM event in events.jsonl"
}

test_claim_conflict() {
    coop claim src/auth.ts --agent claude --reason "first" >/dev/null
    local out rc
    out=$(coop claim src/auth.ts --agent codex --reason "second" 2>&1)
    rc=$?
    assert_exit 2 "$rc" "exit code 2 (CONFLICT)"
    assert_contains "CONFLICT" "$out" "stderr contains CONFLICT"
    assert_contains "claude"   "$out" "stderr names holder claude"
}

test_claim_refresh_same_agent() {
    coop claim src/auth.ts --agent claude --reason "first"  --ttl-min 5  >/dev/null
    coop claim src/auth.ts --agent claude --reason "second" --ttl-min 60 >/dev/null
    local rc=$?
    assert_exit 0 "$rc" "refresh returns 0"
    assert_eq "1" "$(claims_count)" "exactly 1 entry (no duplicate)"
}

test_release_basic() {
    coop claim src/auth.ts --agent claude --reason "x" >/dev/null
    local out rc
    out=$(coop release src/auth.ts --agent claude 2>&1)
    rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_contains "Released" "$out" "stdout confirms release"
    assert_eq "0" "$(claims_count)" "claims.json empty"
    assert_eq "1" "$(events_grep_count '"type": "RELEASE"')" "RELEASE event logged"
}

test_release_nonexistent() {
    local out rc
    out=$(coop release src/auth.ts --agent claude 2>&1)
    rc=$?
    assert_exit 1 "$rc" "exit code 1"
    assert_contains "No active claim" "$out" "error message present"
}

test_claim_expiry_allows_takeover() {
    coop claim src/auth.ts --agent claude --reason "expiring" --ttl-min 0 >/dev/null
    sleep 2
    local out rc
    out=$(coop claim src/auth.ts --agent codex --reason "takeover" 2>&1)
    rc=$?
    assert_exit 0 "$rc" "takeover succeeds (exit 0)"
    assert_contains "Claimed" "$out" "stdout confirms takeover"
    assert_eq "codex" "$(python3 -c "import json; print(json.load(open('$COOP_ROOT/.agent-coop/claims.json'))['claims'][0]['agent'])")" "new owner is codex"
}

test_log_decision() {
    local out rc
    out=$(coop log DECISION --agent claude --payload '{"topic":"auth","choice":"session","reasoning":"simpler"}' 2>&1)
    rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_eq "1" "$(events_grep_count '"type": "DECISION"')" "DECISION event present"
    assert_eq "1" "$(events_grep_count '"topic": "auth"')"     "payload.topic preserved"
    assert_eq "1" "$(events_grep_count '"choice": "session"')" "payload.choice preserved"
    assert_eq "1" "$(events_grep_count '"reasoning": "simpler"')" "payload.reasoning preserved"
}

test_log_invalid_json() {
    local before out rc
    before=$(events_count)
    out=$(coop log DECISION --agent claude --payload 'not json {{{' 2>&1)
    rc=$?
    assert_exit 1 "$rc" "exit code 1"
    assert_contains "Invalid JSON" "$out" "stderr explains JSON error"
    assert_eq "$before" "$(events_count)" "no event was appended"
}

test_events_filter_by_agent() {
    coop log DECISION --agent claude --payload '{"x":1}' >/dev/null
    coop log DECISION --agent claude --payload '{"x":2}' >/dev/null
    coop log DECISION --agent codex  --payload '{"x":3}' >/dev/null
    local out claude_lines
    out=$(coop events --agent claude)
    claude_lines=$(printf '%s\n' "$out" | grep -c '"agent": "claude"' || true)
    assert_eq "2" "$claude_lines" "exactly 2 claude events returned"
    assert_not_contains '"agent": "codex"' "$out" "no codex event in filtered output"
}

test_status_summary() {
    coop claim src/auth.ts --agent claude --reason "x" >/dev/null
    coop log DECISION --agent claude --payload '{"x":1}' >/dev/null
    coop log DONE     --agent claude --payload '{"y":2}' >/dev/null
    local out rc
    out=$(coop status 2>&1)
    rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_contains "agent-coop status" "$out" "header present"
    assert_contains "DECISION"          "$out" "DECISION in type breakdown"
    assert_contains "DONE"              "$out" "DONE in type breakdown"
    assert_contains "Active claims: 1"  "$out" "active-claims line"
    assert_contains "claude"            "$out" "shows claude"
    assert_contains "src/auth.ts"       "$out" "shows claimed path"
}

test_observe_report_runs() {
    cd "$COOP_ROOT"
    git_init_with_commit "human-developer" "dev@example.com"
    coop claim src/auth.ts --agent claude --reason "x" >/dev/null
    coop log DECISION --agent claude --payload '{"topic":"t","choice":"c","reasoning":"r"}' >/dev/null
    local out rc
    out=$(coop_observe report 2>&1)
    rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_contains "coop-observe report"   "$out" "report header present"
    assert_contains "Total events"          "$out" "totals section present"
    assert_contains "Numbers, not verdicts" "$out" "honest disclaimer present"
}

test_observe_snapshot_creates_log() {
    cd "$COOP_ROOT"
    git_init_with_commit "human-developer" "dev@example.com"
    coop_observe snapshot >/dev/null
    local rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_file_exists "$COOP_ROOT/.agent-coop/observations.jsonl" "observations.jsonl created"
    local lines
    lines=$(wc -l < "$COOP_ROOT/.agent-coop/observations.jsonl" | tr -d ' ')
    assert_eq "1" "$lines" "exactly 1 observation row"
}

test_observe_attribution_check() {
    cd "$COOP_ROOT"
    git_init_with_commit "human-developer" "dev@example.com"
    coop log DECISION --agent claude --payload '{"x":1}' >/dev/null
    local out rc
    out=$(coop_observe attribution-check 2>&1)
    rc=$?
    assert_exit 0 "$rc" "exit code 0"
    assert_contains "human-developer" "$out" "lists git author"
    assert_contains "claude"          "$out" "lists coop agent claude"
    assert_contains "don't overlap"   "$out" "warns about non-overlap"
}

# ----- runner -----

ALL_TESTS=(
    test_claim_basic
    test_claim_conflict
    test_claim_refresh_same_agent
    test_release_basic
    test_release_nonexistent
    test_claim_expiry_allows_takeover
    test_log_decision
    test_log_invalid_json
    test_events_filter_by_agent
    test_status_summary
    test_observe_report_runs
    test_observe_snapshot_creates_log
    test_observe_attribution_check
)

run_test() {
    local name="$1"
    PASS_COUNT=0
    FAIL_COUNT=0
    echo ""
    echo "=== $name ==="
    setup_sandbox
    "$name"
    teardown_sandbox
}

main() {
    local tests_to_run=()
    if [ "$#" -eq 0 ]; then
        tests_to_run=("${ALL_TESTS[@]}")
    else
        for t in "$@"; do
            if ! declare -F "$t" >/dev/null; then
                echo "Unknown test: $t" >&2
                echo "Available tests:" >&2
                printf '  %s\n' "${ALL_TESTS[@]}" >&2
                exit 2
            fi
            tests_to_run+=("$t")
        done
    fi

    local passed_tests=0 failed_tests=0
    local failed_names=()
    for t in "${tests_to_run[@]}"; do
        run_test "$t"
        if [ "$FAIL_COUNT" -eq 0 ]; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
            failed_names+=("$t")
        fi
    done

    echo ""
    echo "========================================"
    echo "  PASS: $passed_tests"
    echo "  FAIL: $failed_tests"
    echo "========================================"
    if [ "$failed_tests" -gt 0 ]; then
        echo ""
        echo "Failed tests:"
        printf '  - %s\n' "${failed_names[@]}"
        exit 1
    fi
}

main "$@"
