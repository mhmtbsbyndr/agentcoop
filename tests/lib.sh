# Shared helpers for agent-coop test cases.
# Sourced by run.sh before each case file.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Per-case state (reset by run.sh between cases)
PASS_COUNT=0
FAIL_COUNT=0

setup_coop_root() {
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.agent-coop/derived_state"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"ts":"%s","agent":"system","type":"INIT","payload":{"note":"test init"}}\n' "$now" \
        > "$TEST_ROOT/.agent-coop/events.jsonl"
    printf '{"claims":[]}\n' > "$TEST_ROOT/.agent-coop/claims.json"
    export COOP_ROOT="$TEST_ROOT"
}

teardown_coop_root() {
    if [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ]; then
        rm -rf "$TEST_ROOT"
    fi
    unset COOP_ROOT TEST_ROOT
}

# CLI shims: always use the project's CLIs, COOP_ROOT routes them to the tmp dir
coop() {
    "$REPO_ROOT/coop" "$@"
}

coop_observe() {
    "$REPO_ROOT/coop-observe" "$@"
}

# Assertion helpers — every assertion prints PASS/FAIL with expected vs actual
assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="${3:-values}"
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

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local label="${3:-contains}"
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
    local needle="$1"
    local haystack="$2"
    local label="${3:-does not contain}"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  [FAIL] $label"
        echo "         unexpected needle: $needle"
        echo "         haystack:          $haystack"
    else
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  [PASS] $label"
    fi
}

assert_exit() {
    assert_eq "$1" "$2" "${3:-exit code}"
}

assert_file_exists() {
    local path="$1"
    local label="${2:-file exists: $path}"
    if [ -f "$path" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  [PASS] $label"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  [FAIL] $label"
        echo "         missing: $path"
    fi
}

# JSON readers (no jq dependency — uses python which is already required by coop)
events_count() {
    wc -l < "$COOP_ROOT/.agent-coop/events.jsonl" | tr -d ' '
}

claims_count() {
    python3 -c "import json; print(len(json.load(open('$COOP_ROOT/.agent-coop/claims.json'))['claims']))"
}

json_get() {
    local file="$1"
    local expr="$2"
    python3 -c "import json; d=json.load(open('$file')); print($expr)"
}

events_grep_count() {
    # grep -c prints "0" itself when there are no matches (and exits 1),
    # so swallow the non-zero exit with `|| true` rather than appending another 0.
    local pattern="$1"
    grep -c -- "$pattern" "$COOP_ROOT/.agent-coop/events.jsonl" 2>/dev/null || true
}

# Initialize a git repo at the current cwd with one empty commit by the given
# author. Uses plumbing (commit-tree + update-ref) instead of `git commit` so
# the call path bypasses any commit-signing hook the test environment may have.
git_init_with_commit() {
    local name="${1:-Test User}"
    local email="${2:-test@example.com}"
    local message="${3:-init}"
    git init -q
    local tree commit
    tree=$(git write-tree)
    commit=$(GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" \
             GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
             git commit-tree "$tree" -m "$message")
    git update-ref HEAD "$commit"
}
