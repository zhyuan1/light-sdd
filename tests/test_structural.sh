#!/usr/bin/env bash
# test_structural.sh -- Structural integrity tests for light-sdd
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# T1.1 Schema completeness
# ---------------------------------------------------------------------------
t1_1() {
  local label="T1.1 Schema completeness"
  local schema="$REPO_ROOT/schema.yaml"
  local ok=true

  for type in brainstorm proposal spec design tasks plan review; do
    if ! grep -q "^  $type:" "$schema"; then
      fail "$label -- artifact type '$type' missing"
      ok=false
    fi
  done

  for field in "file:" "required:" "sections:"; do
    local count
    count=$(grep -c "    $field" "$schema" || true)
    if [ "$count" -lt 7 ]; then
      fail "$label -- field '$field' found only $count times (expected >= 7)"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.2 Template-Schema alignment
# ---------------------------------------------------------------------------
t1_2() {
  local label="T1.2 Template-Schema alignment"
  local schema="$REPO_ROOT/schema.yaml"
  local ok=true

  local types="brainstorm proposal spec design tasks plan review"
  local templates="brainstorm.md proposal.md spec.md design.md tasks.md plan.md review.md"

  local i=0
  for type in $types; do
    i=$((i + 1))
    local tmpl_name
    tmpl_name=$(echo "$templates" | cut -d' ' -f"$i")
    local tmpl="$REPO_ROOT/templates/$tmpl_name"

    if [ ! -f "$tmpl" ]; then
      fail "$label -- template '$tmpl_name' missing"
      ok=false
      continue
    fi

    # Use awk to extract required section names for this artifact type
    local required_sections
    required_sections=$(awk -v t="$type" '
      /^  [a-z]+:/ { current = ($0 ~ "^  "t":") ? 1 : 0; next }
      current && /sections:/ { in_sec = 1; next }
      current && in_sec && /- name:/ { name = $0; sub(/.*- name: /, "", name); pending_name = name }
      current && in_sec && /required: true/ && pending_name { print pending_name; pending_name = "" }
      current && in_sec && /required: false/ { pending_name = "" }
    ' "$schema")

    while IFS= read -r section_name; do
      [ -z "$section_name" ] && continue
      if ! grep -qi "## $section_name" "$tmpl"; then
        fail "$label -- template '$tmpl_name' missing required section '## $section_name'"
        ok=false
      fi
    done <<< "$required_sections"
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.3 Skill completeness
# ---------------------------------------------------------------------------
t1_3() {
  local label="T1.3 Skill completeness"
  local ok=true

  local skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                sdd-review-spec sdd-review-code sdd-verify sdd-ship sdd-status)

  for skill in "${skills[@]}"; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if [ ! -f "$skill_file" ]; then
      fail "$label -- $skill/SKILL.md missing"
      ok=false
      continue
    fi

    # Check YAML frontmatter exists
    if ! head -1 "$skill_file" | grep -q "^---"; then
      fail "$label -- $skill/SKILL.md missing YAML frontmatter"
      ok=false
      continue
    fi

    # Check required frontmatter fields
    local fm
    fm=$(sed -n '/^---$/,/^---$/p' "$skill_file")
    for field in "name:" "description:" "metadata:"; do
      if ! echo "$fm" | grep -q "$field"; then
        fail "$label -- $skill frontmatter missing '$field'"
        ok=false
      fi
    done

    # Check delegates_to in metadata
    if ! echo "$fm" | grep -q "delegates_to:"; then
      fail "$label -- $skill frontmatter missing 'delegates_to'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.4 Skill three-part structure
# ---------------------------------------------------------------------------
t1_4() {
  local label="T1.4 Skill three-part structure"
  local ok=true

  for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")

    for section in "Pre-check" "Core Execution" "Post-check"; do
      if ! grep -q "## $section" "$skill_file"; then
        fail "$label -- $skill_name missing '## $section'"
        ok=false
      fi
    done
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.5 Command completeness
# ---------------------------------------------------------------------------
t1_5() {
  local label="T1.5 Command completeness"
  local ok=true

  local commands=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                  sdd-review-spec sdd-review-code sdd-verify sdd-ship sdd-status)

  for cmd in "${commands[@]}"; do
    local cmd_file="$REPO_ROOT/commands/$cmd.md"
    if [ ! -f "$cmd_file" ]; then
      fail "$label -- $cmd.md missing"
      ok=false
      continue
    fi

    # Check description frontmatter
    if ! grep -q "description:" "$cmd_file"; then
      fail "$label -- $cmd.md missing 'description:' frontmatter"
      ok=false
    fi

    # Check skill reference
    if ! grep -q "$cmd" "$cmd_file"; then
      fail "$label -- $cmd.md does not reference skill '$cmd'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.6 Delegation mapping & transition suppression
# ---------------------------------------------------------------------------
t1_6() {
  local label="T1.6 Delegation mapping & transition suppression"
  local ok=true

  # Check transition suppression in the 3 affected skills
  for skill in sdd-brainstorm sdd-plan sdd-code; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if ! grep -q "SDD OVERRIDE" "$skill_file"; then
      fail "$label -- $skill missing 'SDD OVERRIDE' transition suppression"
      ok=false
    fi
  done

  # Verify non-affected skills do NOT have transition suppression
  for skill in sdd-propose sdd-ff sdd-review-spec sdd-review-code sdd-verify sdd-ship sdd-status; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if grep -q "SDD OVERRIDE" "$skill_file"; then
      fail "$label -- $skill has unexpected 'SDD OVERRIDE' (should not have transition suppression)"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.7 Dependency chain
# ---------------------------------------------------------------------------
t1_7() {
  local label="T1.7 Dependency chain"
  local schema="$REPO_ROOT/schema.yaml"
  local ok=true

  # Expected predecessor mappings: "type:expected_predecessor"
  local expected_pairs="brainstorm:null proposal:brainstorm spec:proposal design:spec tasks:spec plan:tasks review:null"

  for pair in $expected_pairs; do
    local type="${pair%%:*}"
    local expected="${pair##*:}"
    local actual
    actual=$(awk "/^  $type:/{found=1} found && /predecessor:/{print \$2; exit}" "$schema")

    if [ "$actual" != "$expected" ]; then
      fail "$label -- $type predecessor: expected '$expected', got '$actual'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.8 Install script
# ---------------------------------------------------------------------------
t1_8() {
  local label="T1.8 Install script"
  local ok=true

  local install="$REPO_ROOT/install.sh"

  # Check executable
  if [ ! -x "$install" ]; then
    fail "$label -- install.sh is not executable"
    ok=false
  fi

  # Check --help output
  local help_output
  help_output=$("$install" --help 2>&1)
  if ! echo "$help_output" | grep -q "Usage:"; then
    fail "$label -- install.sh --help does not contain 'Usage:'"
    ok=false
  fi

  # Check --help mentions --target
  if ! echo "$help_output" | grep -q "\-\-target"; then
    fail "$label -- install.sh --help does not mention '--target'"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.9 Provenance frontmatter in templates
# ---------------------------------------------------------------------------
t1_9() {
  local label="T1.9 Provenance frontmatter in templates"
  local ok=true

  for tmpl in "$REPO_ROOT"/templates/*.md; do
    local tmpl_name
    tmpl_name=$(basename "$tmpl")

    # Check YAML frontmatter exists
    if ! head -1 "$tmpl" | grep -q "^---"; then
      fail "$label -- $tmpl_name missing YAML frontmatter"
      ok=false
      continue
    fi

    # Check required provenance fields
    for field in generated_by sdd_action timestamp; do
      if ! grep -q "$field:" "$tmpl"; then
        fail "$label -- $tmpl_name missing provenance field '$field'"
        ok=false
      fi
    done
  done

  # Check schema defines provenance
  if ! grep -q "^provenance:" "$REPO_ROOT/schema.yaml"; then
    fail "$label -- schema.yaml missing 'provenance:' definition"
    ok=false
  fi

  # Check skills have provenance stamp in Post-check (except sdd-status and sdd-ship)
  for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")
    if [ "$skill_name" = "sdd-status" ] || [ "$skill_name" = "sdd-ship" ]; then
      continue
    fi
    if ! grep -qi "provenance" "$skill_file"; then
      fail "$label -- $skill_name SKILL.md missing provenance stamp instruction"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.10 Delegation availability check in skills
# ---------------------------------------------------------------------------
t1_10() {
  local label="T1.10 Delegation availability check"
  local ok=true

  # All skills that delegate externally must have the availability check step
  local delegating_skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                           sdd-review-code sdd-verify sdd-ship)

  for skill in "${delegating_skills[@]}"; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if ! grep -q "Delegation availability check" "$skill_file"; then
      fail "$label -- $skill missing 'Delegation availability check' in Pre-check"
      ok=false
    fi
  done

  # Non-delegating skills should NOT have the check
  for skill in sdd-status sdd-review-spec; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if grep -q "Delegation availability check" "$skill_file"; then
      fail "$label -- $skill has unexpected 'Delegation availability check' (no external delegation)"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# Run all structural tests
# ---------------------------------------------------------------------------
run_structural() {
  echo "=== Structural Tests ==="
  t1_1
  t1_2
  t1_3
  t1_4
  t1_5
  t1_6
  t1_7
  t1_8
  t1_9
  t1_10
  echo ""
  echo "Structural: $PASS passed, $FAIL failed"
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_structural
fi
