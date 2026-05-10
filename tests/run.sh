#!/usr/bin/env bash
# Test runner for agent-coop.
# Each case file in tests/cases/ runs in an isolated COOP_ROOT.
# Exits 0 if every case passes, 1 if any assertion fails.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
CASES_RUN=0
FAILED_CASES=()

shopt -s nullglob
for case_file in "$SCRIPT_DIR"/cases/*.sh; do
    test_name="$(basename "$case_file" .sh)"
    echo ""
    echo "=== $test_name ==="

    # reset per-case counters
    PASS_COUNT=0
    FAIL_COUNT=0

    setup_coop_root
    # shellcheck disable=SC1090
    source "$case_file"
    teardown_coop_root

    CASES_RUN=$((CASES_RUN + 1))
    TOTAL_PASS=$((TOTAL_PASS + PASS_COUNT))
    TOTAL_FAIL=$((TOTAL_FAIL + FAIL_COUNT))
    if [ "$FAIL_COUNT" -gt 0 ]; then
        FAILED_CASES+=("$test_name ($FAIL_COUNT failed)")
    fi
done

echo ""
echo "=== Summary ==="
echo "Cases:        $CASES_RUN"
echo "Assertions:   $((TOTAL_PASS + TOTAL_FAIL))"
echo "  Passed:     $TOTAL_PASS"
echo "  Failed:     $TOTAL_FAIL"

if [ "$TOTAL_FAIL" -gt 0 ]; then
    echo ""
    echo "Failing cases:"
    for c in "${FAILED_CASES[@]}"; do
        echo "  - $c"
    done
    exit 1
fi

echo "All assertions passed."
