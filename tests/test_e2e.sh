#!/usr/bin/env bash
# test_e2e.sh -- E2E simulation tests for light-sdd workflow
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures"
PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1: $2"; FAIL=$((FAIL + 1)); }

# --- Helper: infer phase from change directory ---
# Mirrors the logic defined in sdd-status SKILL.md
infer_phase() {
  local dir="$1"

  # Check for proposal
  if [ ! -f "$dir/proposal.md" ]; then
    echo "not started"
    return
  fi

  # Check for specs
  local spec_count=0
  if [ -d "$dir/specs" ]; then
    spec_count=$(find "$dir/specs" -name "spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$spec_count" -eq 0 ]; then
    echo "proposing"
    return
  fi

  # Check for tasks
  if [ ! -f "$dir/tasks.md" ]; then
    echo "specifying"
    return
  fi

  # Count task completion
  local total done
  total=$(grep -c '\- \[.\]' "$dir/tasks.md" || true)
  done=$(grep -c '\- \[x\]' "$dir/tasks.md" || true)

  if [ "$total" -eq 0 ]; then
    echo "ready to plan/code"
    return
  fi

  if [ "$done" -eq 0 ]; then
    echo "ready to plan/code"
    return
  fi

  if [ "$done" -lt "$total" ]; then
    echo "coding"
    return
  fi

  # All tasks done -- check verification
  if [ -d "$dir/reviews" ]; then
    local has_pass
    has_pass=$(grep -rl '^pass$' "$dir/reviews/" 2>/dev/null | head -1 || true)
    if [ -n "$has_pass" ]; then
      echo "ready to ship"
      return
    fi
  fi

  echo "ready to verify"
}

# --- Helper: count tasks ---
count_tasks() {
  local file="$1"
  local total done
  total=$(grep -c '\- \[.\]' "$file" || true)
  done=$(grep -c '\- \[x\]' "$file" || true)
  echo "$done/$total"
}

# --- Helper: cross-reference capabilities ---
# Returns lines like "MISSING:storage" or "ORPHAN:orphan"
xref_capabilities() {
  local dir="$1"
  local result=""

  # Extract capabilities from proposal
  local caps=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^-[[:space:]]+\`([a-zA-Z0-9_-]+)\` ]]; then
      caps+=("${BASH_REMATCH[1]}")
    fi
  done < "$dir/proposal.md"

  # Check each capability has a spec
  for cap in "${caps[@]}"; do
    if [ ! -f "$dir/specs/$cap/spec.md" ]; then
      result="${result}MISSING:$cap "
    fi
  done

  # Check for orphan specs
  if [ -d "$dir/specs" ]; then
    for spec_dir in "$dir/specs"/*/; do
      local spec_name
      spec_name=$(basename "$spec_dir")
      local found=false
      for cap in "${caps[@]}"; do
        if [ "$cap" = "$spec_name" ]; then
          found=true
          break
        fi
      done
      if ! $found; then
        result="${result}ORPHAN:$spec_name "
      fi
    done
  fi

  echo "$result"
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------
TMPDIR=""
CHANGE_DIR=""

setup() {
  TMPDIR=$(mktemp -d /tmp/sdd-test-XXXX)
  CHANGE_DIR="$TMPDIR/.sdd/changes/test-feature"
  mkdir -p "$CHANGE_DIR"
}

teardown() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}

# ---------------------------------------------------------------------------
# T2.1 Empty change -> "not started"
# ---------------------------------------------------------------------------
t2_1() {
  local label="T2.1 Empty change -> not started"
  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "not started" ]; then
    pass "$label"
  else
    fail "$label" "expected 'not started', got '$phase'"
  fi
}

# ---------------------------------------------------------------------------
# T2.2 After propose -> "proposing"
# ---------------------------------------------------------------------------
t2_2() {
  local label="T2.2 After propose -> proposing"
  cp "$FIXTURES/proposal.md" "$CHANGE_DIR/"
  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "proposing" ]; then
    pass "$label"
  else
    fail "$label" "expected 'proposing', got '$phase'"
  fi
}

# ---------------------------------------------------------------------------
# T2.3 After ff -> "specifying" then "ready to plan/code"
# ---------------------------------------------------------------------------
t2_3() {
  local label_a="T2.3a After ff (specs only) -> specifying"
  local label_b="T2.3b After ff (specs + tasks) -> ready to plan/code"

  # Add specs but no tasks
  mkdir -p "$CHANGE_DIR/specs/auth" "$CHANGE_DIR/specs/storage"
  cp "$FIXTURES/spec.md" "$CHANGE_DIR/specs/auth/spec.md"
  cp "$FIXTURES/spec.md" "$CHANGE_DIR/specs/storage/spec.md"

  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "specifying" ]; then
    pass "$label_a"
  else
    fail "$label_a" "expected 'specifying', got '$phase'"
  fi

  # Add tasks (all unchecked)
  cp "$FIXTURES/tasks.md" "$CHANGE_DIR/"
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "ready to plan/code" ]; then
    pass "$label_b"
  else
    fail "$label_b" "expected 'ready to plan/code', got '$phase'"
  fi
}

# ---------------------------------------------------------------------------
# T2.4 Coding progress -> "coding"
# ---------------------------------------------------------------------------
t2_4() {
  local label="T2.4 Coding progress -> coding"

  # Mark 3 of 7 tasks as done using awk (portable)
  awk 'BEGIN{c=0} /- \[ \]/ && c<3 {sub(/- \[ \]/, "- [x]"); c++} {print}' \
    "$CHANGE_DIR/tasks.md" > "$CHANGE_DIR/tasks.md.tmp" && \
    mv "$CHANGE_DIR/tasks.md.tmp" "$CHANGE_DIR/tasks.md"

  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "coding" ]; then
    pass "$label"
  else
    fail "$label" "expected 'coding', got '$phase'"
  fi

  # Verify task ratio
  local ratio
  ratio=$(count_tasks "$CHANGE_DIR/tasks.md")
  if [[ "$ratio" == 3/* ]]; then
    pass "T2.4b Task ratio correct ($ratio)"
  else
    fail "T2.4b Task ratio" "expected '3/N', got '$ratio'"
  fi
}

# ---------------------------------------------------------------------------
# T2.5 All tasks complete -> "ready to verify"
# ---------------------------------------------------------------------------
t2_5() {
  local label="T2.5 All tasks complete -> ready to verify"

  # Mark all tasks as done
  awk '{gsub(/- \[ \]/, "- [x]")} {print}' \
    "$CHANGE_DIR/tasks.md" > "$CHANGE_DIR/tasks.md.tmp" && \
    mv "$CHANGE_DIR/tasks.md.tmp" "$CHANGE_DIR/tasks.md"

  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "ready to verify" ]; then
    pass "$label"
  else
    fail "$label" "expected 'ready to verify', got '$phase'"
  fi
}

# ---------------------------------------------------------------------------
# T2.6 Verification pass -> "ready to ship"
# ---------------------------------------------------------------------------
t2_6() {
  local label="T2.6 Verification pass -> ready to ship"

  mkdir -p "$CHANGE_DIR/reviews"
  cp "$FIXTURES/review-pass.md" "$CHANGE_DIR/reviews/verification-2026-04-15.md"

  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "ready to ship" ]; then
    pass "$label"
  else
    fail "$label" "expected 'ready to ship', got '$phase'"
  fi
}

# ---------------------------------------------------------------------------
# T2.7 Verification fail -> still "ready to verify"
# ---------------------------------------------------------------------------
t2_7() {
  local label="T2.7 Verification fail -> ready to verify"

  # Replace with failing review
  cp "$FIXTURES/review-fail.md" "$CHANGE_DIR/reviews/verification-2026-04-15.md"

  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" = "ready to verify" ]; then
    pass "$label"
  else
    fail "$label" "expected 'ready to verify', got '$phase'"
  fi
}

# ---------------------------------------------------------------------------
# T2.8 Capability cross-reference
# ---------------------------------------------------------------------------
t2_8() {
  local label="T2.8 Capability cross-reference"

  # Reset: proposal lists auth + storage, but only auth spec exists
  rm -rf "$CHANGE_DIR/specs/storage" "$CHANGE_DIR/reviews"
  mkdir -p "$CHANGE_DIR/specs/orphan"
  cp "$FIXTURES/spec.md" "$CHANGE_DIR/specs/orphan/spec.md"

  local xref
  xref=$(xref_capabilities "$CHANGE_DIR")

  local ok=true
  if ! echo "$xref" | grep -q "MISSING:storage"; then
    fail "$label" "expected MISSING:storage in xref"
    ok=false
  fi
  if ! echo "$xref" | grep -q "ORPHAN:orphan"; then
    fail "$label" "expected ORPHAN:orphan in xref"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.9 Optional artifact skip
# ---------------------------------------------------------------------------
t2_9() {
  local label="T2.9 Optional artifact skip"

  # Clean change dir: only required artifacts
  rm -rf "$CHANGE_DIR"
  mkdir -p "$CHANGE_DIR/specs/auth" "$CHANGE_DIR/specs/storage"
  cp "$FIXTURES/proposal.md" "$CHANGE_DIR/"
  cp "$FIXTURES/spec.md" "$CHANGE_DIR/specs/auth/spec.md"
  cp "$FIXTURES/spec.md" "$CHANGE_DIR/specs/storage/spec.md"
  cp "$FIXTURES/tasks.md" "$CHANGE_DIR/"

  # No brainstorm.md, no design.md, no plan.md
  local ok=true

  # brainstorm is optional
  if [ -f "$CHANGE_DIR/brainstorm.md" ]; then
    fail "$label" "brainstorm.md should not exist in this test"
    ok=false
  fi

  # design is optional
  if [ -f "$CHANGE_DIR/design.md" ]; then
    fail "$label" "design.md should not exist in this test"
    ok=false
  fi

  # plan is optional
  if [ -f "$CHANGE_DIR/plan.md" ]; then
    fail "$label" "plan.md should not exist in this test"
    ok=false
  fi

  # Workflow should still work -- phase should be "ready to plan/code"
  local phase
  phase=$(infer_phase "$CHANGE_DIR")
  if [ "$phase" != "ready to plan/code" ]; then
    fail "$label" "expected 'ready to plan/code' without optional artifacts, got '$phase'"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.10 Install round-trip
# ---------------------------------------------------------------------------
t2_10() {
  local label="T2.10 Install round-trip"
  local install="$REPO_ROOT/install.sh"
  local target="$TMPDIR/sdd-install-test"
  local ok=true

  # Install (--target is now the root dir, skills/ and commands/ created inside)
  "$install" --target "$target" > /dev/null 2>&1
  # Check
  local check_output
  check_output=$("$install" --check --target "$target" 2>&1)
  if echo "$check_output" | grep -q "MISSING"; then
    fail "$label (install)" "some items missing after install: $(echo "$check_output" | grep MISSING)"
    ok=false
  fi

  # Verify directory structure: skills/ and commands/ should exist
  if [ ! -d "$target/skills" ] || [ ! -d "$target/commands" ]; then
    fail "$label (structure)" "expected skills/ and commands/ dirs inside target"
    ok=false
  fi

  # Uninstall
  "$install" --uninstall --target "$target" > /dev/null 2>&1
  # Re-check
  local recheck_output
  recheck_output=$("$install" --check --target "$target" 2>&1 || true)
  if ! echo "$recheck_output" | grep -q "MISSING"; then
    fail "$label (uninstall)" "items still present after uninstall"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# Run all E2E tests
# ---------------------------------------------------------------------------
run_e2e() {
  echo "=== E2E Simulation Tests ==="
  setup
  trap teardown EXIT

  t2_1
  t2_2
  t2_3
  t2_4
  t2_5
  t2_6
  t2_7
  t2_8
  t2_9
  t2_10

  echo ""
  echo "E2E: $PASS passed, $FAIL failed"
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_e2e
fi
