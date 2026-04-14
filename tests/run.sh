#!/usr/bin/env bash
# run.sh -- Run all light-sdd tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

echo "light-sdd test suite"
echo "===================="
echo ""

# Run structural tests
source "$SCRIPT_DIR/test_structural.sh"
run_structural
S_PASS=$PASS
S_FAIL=$FAIL

# Reset counters for E2E
PASS=0
FAIL=0

# Run E2E tests
source "$SCRIPT_DIR/test_e2e.sh"
run_e2e
E_PASS=$PASS
E_FAIL=$FAIL

# Summary
TOTAL_PASS=$((S_PASS + E_PASS))
TOTAL_FAIL=$((S_FAIL + E_FAIL))

echo ""
echo "===================="
echo "=== Summary ==="
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
echo ""

if [ "$TOTAL_FAIL" -gt 0 ]; then
  exit 1
fi
