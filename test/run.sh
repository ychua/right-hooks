#!/usr/bin/env bash
# RIGHT-HOOKS Test Runner — runs all tests, reports pass/fail counts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export RH_TEST=1

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_RUN=0
FAILED_SUITES=()

echo ""
echo "🥊  Right Hooks Test Suite"
echo "═══════════════════════════════════"
echo ""

# Find and run all test scripts
for test_file in "$SCRIPT_DIR"/hooks/test-*.sh "$SCRIPT_DIR"/cli/test-*.sh "$SCRIPT_DIR"/integration/test-*.sh; do
  [ -f "$test_file" ] || continue
  
  suite_name=$(basename "$test_file" .sh | sed 's/^test-//')
  echo "▸ $suite_name"
  
  # Run test in subshell to isolate failures
  output=$(bash "$test_file" 2>&1) || true
  
  # Debug: show full output if no assertions found
  if ! echo "$output" | grep -qE '(✓|✗)'; then
    echo "  [DEBUG] No test output — full stderr/stdout:"
    echo "$output" | head -20 | sed 's/^/    /'
  fi
  
  # Print test lines (indented with ✓ or ✗)
  echo "$output" | grep -E '(✓|✗|→)' || true
  
  # Extract counts from summary line
  passed=$(echo "$output" | grep -oE '[0-9]+ tests passed' | grep -oE '^[0-9]+' || echo "0")
  if [ "$passed" = "0" ]; then
    passed=$(echo "$output" | grep -oE '[0-9]+ passed' | grep -oE '^[0-9]+' || echo "0")
  fi
  failed=$(echo "$output" | grep -oE '[0-9]+ failed' | grep -oE '^[0-9]+' || echo "0")
  run=$(echo "$output" | grep -oE 'out of [0-9]+' | grep -oE '[0-9]+' || echo "0")
  
  # If "All N tests passed", run = passed
  if [ "$run" = "0" ] && [ "$passed" != "0" ]; then
    run=$passed
  fi
  
  TOTAL_PASS=$((TOTAL_PASS + passed))
  TOTAL_FAIL=$((TOTAL_FAIL + failed))
  TOTAL_RUN=$((TOTAL_RUN + run))
  
  if [ "$failed" -gt 0 ]; then
    FAILED_SUITES+=("$suite_name")
  fi
  echo ""
done

echo "═══════════════════════════════════"
echo ""
if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "\033[0;32m✅ All $TOTAL_PASS tests passed ($TOTAL_RUN total)\033[0m"
else
  echo -e "\033[0;31m❌ $TOTAL_FAIL failed\033[0m, \033[0;32m$TOTAL_PASS passed\033[0m out of $TOTAL_RUN tests"
  echo ""
  echo "Failed suites:"
  for s in "${FAILED_SUITES[@]}"; do
    echo "  • $s"
  done
  exit 1
fi
