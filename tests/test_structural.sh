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
                sdd-review-spec sdd-review-code sdd-verify sdd-ship sdd-status sdd-use sdd-kb)

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
                  sdd-review-spec sdd-review-code sdd-verify sdd-ship sdd-status sdd-use sdd-kb)

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
  local label="T1.10 Delegation references delegates.yaml + protocol"
  local ok=true

  # All skills that delegate externally must reference both delegates.yaml and delegation-protocol.md
  local delegating_skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                           sdd-review-code sdd-verify sdd-ship)

  for skill in "${delegating_skills[@]}"; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if ! grep -q "delegates.yaml" "$skill_file"; then
      fail "$label -- $skill missing 'delegates.yaml' reference in Pre-check"
      ok=false
    fi
    if ! grep -q "delegation-protocol.md" "$skill_file"; then
      fail "$label -- $skill missing 'delegation-protocol.md' reference in Pre-check"
      ok=false
    fi
  done

  # Non-delegating skills should NOT reference delegates.yaml
  for skill in sdd-status sdd-review-spec; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if grep -q "delegates.yaml" "$skill_file"; then
      fail "$label -- $skill has unexpected 'delegates.yaml' reference (no external delegation)"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.11 delegates.yaml integrity
# ---------------------------------------------------------------------------
t1_11() {
  local label="T1.11 delegates.yaml integrity"
  local ok=true
  local delegates="$REPO_ROOT/delegates.yaml"

  # File must exist
  if [ ! -f "$delegates" ]; then
    fail "$label -- delegates.yaml missing"
    return
  fi

  # Must contain entries for all 8 delegating skills
  local delegating_skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                           sdd-review-code sdd-verify sdd-ship)

  for skill in "${delegating_skills[@]}"; do
    if ! grep -q "^${skill}:" "$delegates"; then
      fail "$label -- delegates.yaml missing entry for '$skill'"
      ok=false
    fi
  done

  # Each entry must have primary (or phases) and manual_message (or phases with manual_message)
  for skill in "${delegating_skills[@]}"; do
    # Check for primary or phases key under the skill
    local has_primary has_phases
    has_primary=$(awk "/^${skill}:/{found=1; next} /^[a-z]/{found=0} found && /^  primary:/{print 1; exit}" "$delegates")
    has_phases=$(awk "/^${skill}:/{found=1; next} /^[a-z]/{found=0} found && /^  phases:/{print 1; exit}" "$delegates")

    if [ -z "$has_primary" ] && [ -z "$has_phases" ]; then
      fail "$label -- $skill missing 'primary' or 'phases' in delegates.yaml"
      ok=false
    fi

    # Check for manual_message at action level or within phases
    local has_manual
    has_manual=$(awk "/^${skill}:/{found=1; next} /^[a-z]/{found=0} found && /manual_message:/{print 1; exit}" "$delegates")

    if [ -z "$has_manual" ]; then
      fail "$label -- $skill missing 'manual_message' in delegates.yaml"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.12 delegation-protocol.md existence
# ---------------------------------------------------------------------------
t1_12() {
  local label="T1.12 delegation-protocol.md existence"
  local ok=true
  local protocol="$REPO_ROOT/delegation-protocol.md"

  if [ ! -f "$protocol" ]; then
    fail "$label -- delegation-protocol.md missing"
    return
  fi

  # Check key protocol sections
  for section in "Search Path Resolution" "Single-Delegate Resolution" "Multi-Skill Partial Availability" "Multi-Phase Independent Resolution" "User Notification Format" "Provenance Recording" "Transition Suppression"; do
    if ! grep -q "$section" "$protocol"; then
      fail "$label -- delegation-protocol.md missing section '$section'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.13 delegates.yaml <-> SKILL.md frontmatter cross-validation
# ---------------------------------------------------------------------------
t1_13() {
  local label="T1.13 delegates.yaml <-> SKILL.md frontmatter alignment"
  local ok=true
  local delegates="$REPO_ROOT/delegates.yaml"

  local delegating_skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                           sdd-review-code sdd-verify sdd-ship)

  for skill in "${delegating_skills[@]}"; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"

    # Extract delegates_to list from SKILL.md frontmatter
    local fm_delegates
    fm_delegates=$(sed -n '/^---$/,/^---$/p' "$skill_file" | awk '/delegates_to:/{found=1; next} found && /- /{gsub(/.*- "?/, ""); gsub(/".*/, ""); print} found && !/- / && !/^$/{found=0}')

    # For each delegate in frontmatter, verify it appears as a skill in delegates.yaml under this action
    while IFS= read -r delegate_skill; do
      [ -z "$delegate_skill" ] && continue
      # Check that delegates.yaml mentions this skill name under the action entry
      local in_registry
      in_registry=$(awk "/^${skill}:/{found=1; next} /^[a-z]/{found=0} found && /skill: ${delegate_skill}/{print 1; exit}" "$delegates")

      if [ -z "$in_registry" ]; then
        fail "$label -- $skill frontmatter lists delegate '$delegate_skill' not found in delegates.yaml"
        ok=false
      fi
    done <<< "$fm_delegates"
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.14 transition_suppression consistency (delegates.yaml <-> SKILL.md)
# ---------------------------------------------------------------------------
t1_14() {
  local label="T1.14 transition_suppression <-> SDD OVERRIDE consistency"
  local ok=true
  local delegates="$REPO_ROOT/delegates.yaml"

  # Extract skills that have transition_suppression in delegates.yaml
  local yaml_suppressed=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    yaml_suppressed+=("$line")
  done < <(awk '/^profiles:/{exit} /^[a-z].*:$/{skill=$0; sub(/:$/,"",skill)} /transition_suppression:/{print skill}' "$delegates")

  # Extract skills that have SDD OVERRIDE in SKILL.md
  local md_suppressed=()
  for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")
    if grep -q "SDD OVERRIDE" "$skill_file"; then
      md_suppressed+=("$skill_name")
    fi
  done

  # Check every yaml_suppressed is in md_suppressed
  for skill in "${yaml_suppressed[@]}"; do
    local found=false
    for md_skill in "${md_suppressed[@]}"; do
      if [ "$skill" = "$md_skill" ]; then
        found=true
        break
      fi
    done
    if ! $found; then
      fail "$label -- $skill has transition_suppression in delegates.yaml but no SDD OVERRIDE in SKILL.md"
      ok=false
    fi
  done

  # Check every md_suppressed is in yaml_suppressed
  for skill in "${md_suppressed[@]}"; do
    local found=false
    for yaml_skill in "${yaml_suppressed[@]}"; do
      if [ "$skill" = "$yaml_skill" ]; then
        found=true
        break
      fi
    done
    if ! $found; then
      fail "$label -- $skill has SDD OVERRIDE in SKILL.md but no transition_suppression in delegates.yaml"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.15 Multi-profile support (profiles section + delegation-protocol §0)
# ---------------------------------------------------------------------------
t1_15() {
  local label="T1.15 Multi-profile support"
  local ok=true
  local delegates="$REPO_ROOT/delegates.yaml"
  local protocol="$REPO_ROOT/delegation-protocol.md"

  # delegates.yaml must have a profiles: section
  if ! grep -q "^profiles:" "$delegates"; then
    fail "$label -- delegates.yaml missing top-level 'profiles:' section"
    ok=false
  fi

  # profiles.gstack must exist
  if ! grep -q "^  gstack:" "$delegates"; then
    fail "$label -- delegates.yaml missing 'profiles.gstack' entry"
    ok=false
  fi

  # profiles.ai_native_kit must exist
  if ! grep -q "^  ai_native_kit:" "$delegates"; then
    fail "$label -- delegates.yaml missing 'profiles.ai_native_kit' entry"
    ok=false
  fi

  # gstack profile must cover key actions
  for action in sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code sdd-verify sdd-ship; do
    if ! awk '/^  gstack:/{found=1} found && /'"$action"':/{print 1; exit}' "$delegates" | grep -q 1; then
      fail "$label -- delegates.yaml profiles.gstack missing entry for '$action'"
      ok=false
    fi
  done

  # delegation-protocol.md must have §0 Profile Resolution section
  if ! grep -q "Profile Resolution" "$protocol"; then
    fail "$label -- delegation-protocol.md missing '§0 Profile Resolution' section"
    ok=false
  fi

  # sdd-use skill must exist
  if [ ! -f "$REPO_ROOT/skills/sdd-use/SKILL.md" ]; then
    fail "$label -- skills/sdd-use/SKILL.md missing"
    ok=false
  fi

  # sdd-use command must exist
  if [ ! -f "$REPO_ROOT/commands/sdd-use.md" ]; then
    fail "$label -- commands/sdd-use.md missing"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.1 delegates.yaml -- partial_availability actions
# ---------------------------------------------------------------------------
t2_1() {
  local label="T2.1 partial_availability correctness"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # Exactly these two base actions must have partial_availability: true
  local expected_partial=(sdd-code sdd-verify)

  for action in "${expected_partial[@]}"; do
    local has
    has=$(awk "/^${action}:/{found=1; next} /^[a-z]/{found=0} found && /^  partial_availability: true/{print 1; exit}" "$delegates")
    if [ -z "$has" ]; then
      fail "$label -- base action '$action' missing 'partial_availability: true'"
      ok=false
    fi
  done

  # sdd-brainstorm, sdd-propose, sdd-ff, sdd-plan, sdd-ship should NOT have partial_availability
  local no_partial=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-ship)
  for action in "${no_partial[@]}"; do
    local has
    has=$(awk "/^${action}:/{found=1; next} /^[a-z]/{found=0} found && /partial_availability:/{print 1; exit}" "$delegates")
    if [ -n "$has" ]; then
      fail "$label -- base action '$action' has unexpected 'partial_availability'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.2 delegates.yaml -- multi-phase action structure
# ---------------------------------------------------------------------------
t2_2() {
  local label="T2.2 Multi-phase action structure"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # sdd-review-code must have phases: phase1 and phase2
  for phase in phase1 phase2; do
    if ! awk "/^sdd-review-code:/{found=1} found && /^  phases:/{in_phases=1} in_phases && /^    ${phase}:/{print 1; exit}" "$delegates" | grep -q 1; then
      fail "$label -- sdd-review-code missing phase '$phase' in delegates.yaml"
      ok=false
    fi
  done

  # sdd-review-code phase1 must be 'delegate: self'
  local phase1_self
  phase1_self=$(awk "/^sdd-review-code:/{found=1} found && /^    phase1:/{in_p1=1} in_p1 && /delegate: self/{print 1; exit}" "$delegates")
  if [ -z "$phase1_self" ]; then
    fail "$label -- sdd-review-code phase1 must have 'delegate: self'"
    ok=false
  fi

  # sdd-verify must have phases: step1 and step2
  for step in step1 step2; do
    if ! awk "/^sdd-verify:/{found=1} found && /^  phases:/{in_phases=1} in_phases && /^    ${step}:/{print 1; exit}" "$delegates" | grep -q 1; then
      fail "$label -- sdd-verify missing phase '$step' in delegates.yaml"
      ok=false
    fi
  done

  # sdd-ship must have phases: sync, archive, finish
  for phase in sync archive finish; do
    if ! awk "/^sdd-ship:/{found=1} found && /^  phases:/{in_phases=1} in_phases && /^    ${phase}:/{print 1; exit}" "$delegates" | grep -q 1; then
      fail "$label -- sdd-ship missing phase '$phase' in delegates.yaml"
      ok=false
    fi
  done

  # sdd-ship sync and archive must have inline_fallback (not fallback)
  for phase in sync archive; do
    local has_inline
    has_inline=$(awk "/^sdd-ship:/{found=1} found && /^    ${phase}:/{in_p=1} in_p && /inline_fallback:/{print 1; exit}" "$delegates")
    if [ -z "$has_inline" ]; then
      fail "$label -- sdd-ship.$phase must use 'inline_fallback', not external fallback"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.3 delegates.yaml -- fallback chain non-emptiness for non-phase actions
# ---------------------------------------------------------------------------
t2_3() {
  local label="T2.3 Fallback chain non-emptiness"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # All flat-structure delegating actions must have either fallback or manual_message at base level
  local flat_actions=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code)

  for action in "${flat_actions[@]}"; do
    local has_fallback has_manual
    has_fallback=$(awk "/^${action}:/{found=1; next} /^[a-z]/{found=0} found && /^  fallback:/{print 1; exit}" "$delegates")
    has_manual=$(awk "/^${action}:/{found=1; next} /^[a-z]/{found=0} found && /^  manual_message:/{print 1; exit}" "$delegates")
    if [ -z "$has_fallback" ] && [ -z "$has_manual" ]; then
      fail "$label -- '$action' has neither fallback nor manual_message"
      ok=false
    fi
  done

  # Phase-based actions must have manual_message at action level (or within phases)
  local phase_actions=(sdd-review-code sdd-verify)
  for action in "${phase_actions[@]}"; do
    local has_manual
    has_manual=$(awk "/^${action}:/{found=1; next} /^[a-z]/{found=0} found && /manual_message:/{print 1; exit}" "$delegates")
    if [ -z "$has_manual" ]; then
      fail "$label -- phase action '$action' missing manual_message"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.4 gstack profile -- completeness and invariants
# ---------------------------------------------------------------------------
t2_4() {
  local label="T2.4 gstack profile completeness"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # Must have profiles.gstack section
  if ! grep -q "^  gstack:" "$delegates"; then
    fail "$label -- delegates.yaml missing 'profiles.gstack'"
    return
  fi

  # gstack must override exactly these 9 actions
  local gstack_actions=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                        sdd-review-spec sdd-review-code sdd-verify sdd-ship)

  for action in "${gstack_actions[@]}"; do
    local found
    found=$(awk "/^  gstack:/{in_gstack=1} in_gstack && /^    ${action}:/{print 1; exit}" "$delegates")
    if [ -z "$found" ]; then
      fail "$label -- gstack profile missing override for '$action'"
      ok=false
    fi
  done

  # gstack profile must have primary for each single-delegate action
  local gstack_single=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-review-spec)
  for action in "${gstack_single[@]}"; do
    local has_primary
    has_primary=$(awk "/^  gstack:/{in_gstack=1} in_gstack && /^    ${action}:/{in_act=1} in_act && /^      primary:/{print 1; exit}" "$delegates")
    if [ -z "$has_primary" ]; then
      fail "$label -- gstack.$action missing 'primary'"
      ok=false
    fi
  done

  # gstack sdd-code must have partial_availability: true
  local gstack_code_partial
  gstack_code_partial=$(awk "/^  gstack:/{in_gstack=1} in_gstack && /^    sdd-code:/{in_act=1} in_act && /partial_availability: true/{print 1; exit}" "$delegates")
  if [ -z "$gstack_code_partial" ]; then
    fail "$label -- gstack.sdd-code missing 'partial_availability: true'"
    ok=false
  fi

  # gstack sdd-verify must have partial_availability: true
  local gstack_verify_partial
  gstack_verify_partial=$(awk "/^  gstack:/{in_gstack=1} in_gstack && /^    sdd-verify:/{in_act=1} in_act && /partial_availability: true/{print 1; exit}" "$delegates")
  if [ -z "$gstack_verify_partial" ]; then
    fail "$label -- gstack.sdd-verify missing 'partial_availability: true'"
    ok=false
  fi

  # gstack sdd-ship: sync and archive must still use openspec (not gstack)
  for phase in sync archive; do
    local framework
    framework=$(awk "
      /^  gstack:/{in_gstack=1}
      in_gstack && /^    sdd-ship:/{in_ship=1}
      in_ship && /^        ${phase}:/{in_phase=1}
      in_phase && /framework:/{gsub(/.*framework: /, \"\"); gsub(/ *$/, \"\"); print; exit}
    " "$delegates")
    # We just need any framework entry under sync/archive in gstack.sdd-ship
    # The actual check: openspec must appear as primary framework for sync/archive
    local openspec_found
    openspec_found=$(awk "
      /^  gstack:/{in_gstack=1}
      in_gstack && /^    sdd-ship:/{in_ship=1}
      in_ship && /^      phases:/{in_phases=1}
    " "$delegates")
    # More direct check: under profiles.gstack.sdd-ship, find the phase and verify openspec
    local phase_framework
    phase_framework=$(python3 -c "
import sys, re
content = open('$delegates').read()
# Find the gstack profile sdd-ship section
m = re.search(r'profiles:.*?gstack:.*?sdd-ship:(.*?)(?=\n    [a-z]|\nprofiles|\Z)', content, re.DOTALL)
if not m:
    sys.exit(0)
ship_block = m.group(1)
# Find the phase block
pm = re.search(r'${phase}:.*?framework: (\S+)', ship_block, re.DOTALL)
if pm:
    print(pm.group(1).strip())
" 2>/dev/null || echo "")
    if [ "$phase_framework" != "openspec" ]; then
      fail "$label -- gstack.sdd-ship.$phase should use openspec, got '$phase_framework'"
      ok=false
    fi
  done

  # gstack sdd-ship finish must use gstack framework
  local finish_framework
  finish_framework=$(python3 -c "
import sys, re
content = open('$delegates').read()
m = re.search(r'profiles:.*?gstack:.*?sdd-ship:(.*?)(?=\n    [a-z]|\nprofiles|\Z)', content, re.DOTALL)
if not m:
    sys.exit(0)
ship_block = m.group(1)
pm = re.search(r'finish:.*?framework: (\S+)', ship_block, re.DOTALL)
if pm:
    print(pm.group(1).strip())
" 2>/dev/null || echo "")
  if [ "$finish_framework" != "gstack" ]; then
    fail "$label -- gstack.sdd-ship.finish must use 'gstack', got '$finish_framework'"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.5 gstack profile -- transition_suppression coverage
# ---------------------------------------------------------------------------
t2_5() {
  local label="T2.5 gstack transition_suppression coverage"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # gstack profile must have transition_suppression for brainstorm, plan, code
  local gstack_suppressed=(sdd-brainstorm sdd-plan sdd-code)

  for action in "${gstack_suppressed[@]}"; do
    local has_ts
    has_ts=$(awk "
      /^  gstack:/{in_gstack=1}
      in_gstack && /^    ${action}:/{in_act=1}
      in_act && /transition_suppression:/{print 1; exit}
    " "$delegates")
    if [ -z "$has_ts" ]; then
      fail "$label -- gstack.$action missing 'transition_suppression'"
      ok=false
    fi
  done

  # gstack sdd-brainstorm override_text must contain 'SDD OVERRIDE'
  local has_override_text
  has_override_text=$(awk "
    /^  gstack:/{in_gstack=1}
    in_gstack && /^    sdd-brainstorm:/{in_act=1}
    in_act && /SDD OVERRIDE/{print 1; exit}
  " "$delegates")
  if [ -z "$has_override_text" ]; then
    fail "$label -- gstack.sdd-brainstorm transition_suppression missing 'SDD OVERRIDE' text"
    ok=false
  fi

  # gstack actions that should NOT have transition_suppression
  local gstack_no_ts=(sdd-propose sdd-ff sdd-review-spec sdd-review-code sdd-verify sdd-ship)
  for action in "${gstack_no_ts[@]}"; do
    local has_ts
    has_ts=$(awk "
      /^  gstack:/{in_gstack=1}
      in_gstack && /^    ${action}:/{in_act=1; next}
      in_act && /^    [a-z]/{in_act=0}
      in_act && /transition_suppression:/{print 1; exit}
    " "$delegates")
    if [ -n "$has_ts" ]; then
      fail "$label -- gstack.$action has unexpected 'transition_suppression'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.6 Template placeholder validation (no hardcoded framework/skill values)
# ---------------------------------------------------------------------------
t2_6() {
  local label="T2.6 Template placeholder validation"
  local ok=true

  # Templates that produce artifacts with generated_by provenance
  # review.md uses example values in comments -- that's acceptable, but
  # the actual frontmatter values must be placeholders (not hardcoded).
  # Check both en and zh-CN templates.
  local template_dirs=("$REPO_ROOT/templates" "$REPO_ROOT/templates/zh-CN")

  for tmpl_dir in "${template_dirs[@]}"; do
    [ -d "$tmpl_dir" ] || continue

    for tmpl in "$tmpl_dir"/*.md; do
      local tmpl_name
      tmpl_name=$(basename "$tmpl")

      # Extract YAML frontmatter (between first two --- lines, excluding the --- delimiters)
      local fm
      fm=$(awk '/^---$/{n++; if(n==2) exit; next} n==1{print}' "$tmpl")

      # If frontmatter has generated_by.framework, the value must be a placeholder
      # (a quoted string containing braces, not a bare framework name like "superpowers")
      if echo "$fm" | grep -q "framework:"; then
        local fw_value
        fw_value=$(echo "$fm" | awk '/framework:/{sub(/.*framework: */, ""); print}')
        # Must contain { } -- it's a placeholder
        if ! echo "$fw_value" | grep -q "{"; then
          fail "$label -- $tmpl_name frontmatter has hardcoded framework value: $fw_value"
          ok=false
        fi
      fi

      # Same check for skill:
      if echo "$fm" | grep -qE "^  skill:"; then
        local skill_value
        skill_value=$(echo "$fm" | awk '/^  skill:/{sub(/.*skill: */, ""); print}')
        if ! echo "$skill_value" | grep -q "{"; then
          fail "$label -- $tmpl_name frontmatter has hardcoded skill value: $skill_value"
          ok=false
        fi
      fi

      # timestamp must be a placeholder, not a real ISO date
      if echo "$fm" | grep -q "timestamp:"; then
        local ts_value
        ts_value=$(echo "$fm" | awk '/timestamp:/{sub(/.*timestamp: */, ""); print}')
        if ! echo "$ts_value" | grep -q "{"; then
          fail "$label -- $tmpl_name frontmatter has hardcoded timestamp value: $ts_value"
          ok=false
        fi
      fi
    done
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.7 install.sh array sync with actual filesystem
# ---------------------------------------------------------------------------
t2_7() {
  local label="T2.7 install.sh array sync"
  local install="$REPO_ROOT/install.sh"
  local ok=true

  # Extract SDD_SKILLS from install.sh
  local install_skills
  install_skills=$(sed -n '/^SDD_SKILLS=(/,/^)/p' "$install" | grep -v '^SDD_SKILLS=(' | grep -v '^)' | tr -d ' ')

  # Compare against actual skills/ directories
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    local skill_name
    skill_name=$(basename "$skill_dir")
    if ! echo "$install_skills" | grep -q "^${skill_name}$"; then
      fail "$label -- skills/$skill_name exists but not in install.sh SDD_SKILLS"
      ok=false
    fi
  done

  # And vice versa: every skill in SDD_SKILLS must have a directory
  while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    if [ ! -d "$REPO_ROOT/skills/$skill" ]; then
      fail "$label -- install.sh SDD_SKILLS lists '$skill' but skills/$skill/ does not exist"
      ok=false
    fi
  done <<< "$install_skills"

  # Extract SDD_COMMANDS from install.sh
  local install_commands
  install_commands=$(sed -n '/^SDD_COMMANDS=(/,/^)/p' "$install" | grep -v '^SDD_COMMANDS=(' | grep -v '^)' | tr -d ' ')

  # Compare against actual commands/ files
  for cmd_file in "$REPO_ROOT"/commands/*.md; do
    local cmd_name
    cmd_name=$(basename "$cmd_file")
    if ! echo "$install_commands" | grep -q "^${cmd_name}$"; then
      fail "$label -- commands/$cmd_name exists but not in install.sh SDD_COMMANDS"
      ok=false
    fi
  done

  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    if [ ! -f "$REPO_ROOT/commands/$cmd" ]; then
      fail "$label -- install.sh SDD_COMMANDS lists '$cmd' but commands/$cmd does not exist"
      ok=false
    fi
  done <<< "$install_commands"

  # Extract SDD_TEMPLATES from install.sh
  local install_templates
  install_templates=$(sed -n '/^SDD_TEMPLATES=(/,/^)/p' "$install" | grep -v '^SDD_TEMPLATES=(' | grep -v '^)' | tr -d ' ')

  # Compare against actual templates/ files (top-level only, not zh-CN)
  for tmpl_file in "$REPO_ROOT"/templates/*.md; do
    local tmpl_name
    tmpl_name=$(basename "$tmpl_file")
    if ! echo "$install_templates" | grep -q "^${tmpl_name}$"; then
      fail "$label -- templates/$tmpl_name exists but not in install.sh SDD_TEMPLATES"
      ok=false
    fi
  done

  while IFS= read -r tmpl; do
    [ -z "$tmpl" ] && continue
    if [ ! -f "$REPO_ROOT/templates/$tmpl" ]; then
      fail "$label -- install.sh SDD_TEMPLATES lists '$tmpl' but templates/$tmpl does not exist"
      ok=false
    fi
  done <<< "$install_templates"

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.8 Provenance instruction completeness across SKILL.md files
# ---------------------------------------------------------------------------
t2_8() {
  local label="T2.8 Provenance instruction completeness"
  local ok=true

  # Skills that generate artifacts: must reference 'generated_by' in Post-check
  local generating_skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan
                           sdd-review-spec sdd-review-code sdd-verify)
  for skill in "${generating_skills[@]}"; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    local postcheck
    postcheck=$(sed -n '/^## Post-check/,/^## /p' "$skill_file")
    if ! echo "$postcheck" | grep -q "generated_by"; then
      fail "$label -- $skill Post-check missing 'generated_by' provenance instruction"
      ok=false
    fi
  done

  # sdd-code updates artifacts (not generate): must reference 'last_updated_by'
  local code_file="$REPO_ROOT/skills/sdd-code/SKILL.md"
  local code_postcheck
  code_postcheck=$(sed -n '/^## Post-check/,/^## /p' "$code_file")
  if ! echo "$code_postcheck" | grep -q "last_updated_by"; then
    fail "$label -- sdd-code Post-check missing 'last_updated_by' provenance instruction"
    ok=false
  fi

  # sdd-status and sdd-use must NOT reference generated_by (no artifact produced)
  for skill in sdd-status sdd-use; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    if grep -q "generated_by" "$skill_file"; then
      fail "$label -- $skill should NOT have 'generated_by' (no artifact produced)"
      ok=false
    fi
  done

  # sdd-use Post-check must explicitly say no artifact / no provenance stamp
  local use_postcheck
  use_postcheck=$(sed -n '/^## Post-check/,/^## /p' "$REPO_ROOT/skills/sdd-use/SKILL.md")
  if ! echo "$use_postcheck" | grep -qi "no.*artifact\|no provenance"; then
    fail "$label -- sdd-use Post-check must state 'No artifact' or 'No provenance stamp'"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.9 delegation-protocol.md -- section depth checks
# ---------------------------------------------------------------------------
t2_9() {
  local label="T2.9 delegation-protocol.md section depth"
  local protocol="$REPO_ROOT/delegation-protocol.md"
  local ok=true

  # §0 Profile Resolution must reference .sdd/config.yaml and active_profile
  if ! grep -q "\.sdd/config\.yaml" "$protocol"; then
    fail "$label -- §0 missing '.sdd/config.yaml' reference"
    ok=false
  fi
  if ! grep -q "active_profile" "$protocol"; then
    fail "$label -- §0 missing 'active_profile' key reference"
    ok=false
  fi

  # §0 must describe action-level merge (not key-level patching)
  if ! grep -qi "action level\|action-level\|replaces.*block\|whole block" "$protocol"; then
    fail "$label -- §0 must describe action-level merge semantics"
    ok=false
  fi

  # §3 must reference partial_availability
  if ! grep -q "partial_availability" "$protocol"; then
    fail "$label -- §3 missing 'partial_availability' reference"
    ok=false
  fi

  # §4 must reference 'phases' or 'multi-phase'
  if ! grep -qi "phases\|multi-phase" "$protocol"; then
    fail "$label -- §4 missing 'phases' reference"
    ok=false
  fi

  # §7 must reference transition_suppression
  if ! grep -q "transition_suppression" "$protocol" && ! grep -q "Transition Suppression" "$protocol"; then
    fail "$label -- §7 missing 'transition_suppression' reference"
    ok=false
  fi

  # §6 must reference generated_by
  if ! grep -q "generated_by" "$protocol"; then
    fail "$label -- §6 missing 'generated_by' provenance field reference"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.10 sdd-use skill -- behavioural content checks
# ---------------------------------------------------------------------------
t2_10() {
  local label="T2.10 sdd-use behavioural content"
  local skill_file="$REPO_ROOT/skills/sdd-use/SKILL.md"
  local ok=true

  # Must have delegates_to: [] (no external delegation)
  local fm
  fm=$(sed -n '/^---$/,/^---$/p' "$skill_file")
  if ! echo "$fm" | grep -q "delegates_to: \[\]"; then
    fail "$label -- sdd-use frontmatter must have 'delegates_to: []'"
    ok=false
  fi

  # Must have overridable: false
  if ! echo "$fm" | grep -q "overridable: false"; then
    fail "$label -- sdd-use frontmatter must have 'overridable: false'"
    ok=false
  fi

  # Core Execution must mention Set Mode
  if ! grep -qi "set mode\|Set Mode" "$skill_file"; then
    fail "$label -- sdd-use missing 'Set Mode' in Core Execution"
    ok=false
  fi

  # Core Execution must mention List Mode
  if ! grep -qi "list mode\|List Mode" "$skill_file"; then
    fail "$label -- sdd-use missing 'List Mode' in Core Execution"
    ok=false
  fi

  # Must reference .sdd/config.yaml for writing the active profile
  if ! grep -q "\.sdd/config\.yaml" "$skill_file"; then
    fail "$label -- sdd-use missing '.sdd/config.yaml' reference"
    ok=false
  fi

  # Pre-check must validate unknown profile names
  local precheck
  precheck=$(sed -n '/^## Pre-check/,/^## /p' "$skill_file")
  if ! echo "$precheck" | grep -qi "not found\|invalid\|missing\|unknown\|available profiles"; then
    fail "$label -- sdd-use Pre-check missing unknown-profile validation"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T1.16 sdd-kb skill -- structural content checks
# ---------------------------------------------------------------------------
t1_16() {
  local label="T1.16 sdd-kb skill completeness"
  local skill_file="$REPO_ROOT/skills/sdd-kb/SKILL.md"
  local ok=true

  if [ ! -f "$skill_file" ]; then
    fail "$label -- skills/sdd-kb/SKILL.md missing"
    return
  fi

  # Must have delegates_to: [] (no external delegation)
  local fm
  fm=$(sed -n '/^---$/,/^---$/p' "$skill_file")
  if ! echo "$fm" | grep -q "delegates_to: \[\]"; then
    fail "$label -- sdd-kb frontmatter must have 'delegates_to: []'"
    ok=false
  fi

  # Must have overridable: false
  if ! echo "$fm" | grep -q "overridable: false"; then
    fail "$label -- sdd-kb frontmatter must have 'overridable: false'"
    ok=false
  fi

  # All four sub-commands must be documented
  for subcmd in init add update status; do
    if ! grep -q "$subcmd" "$skill_file"; then
      fail "$label -- sdd-kb missing sub-command '$subcmd'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.11 kb.yaml schema documentation in sdd-kb SKILL.md
# ---------------------------------------------------------------------------
t2_11() {
  local label="T2.11 kb.yaml schema documentation"
  local skill_file="$REPO_ROOT/skills/sdd-kb/SKILL.md"
  local ok=true

  if [ ! -f "$skill_file" ]; then
    fail "$label -- skills/sdd-kb/SKILL.md missing"
    return
  fi

  # Must document the 'sources:' key
  if ! grep -q "sources:" "$skill_file"; then
    fail "$label -- sdd-kb missing 'sources:' key documentation"
    ok=false
  fi

  # Must document the 'scope' field
  if ! grep -q "scope" "$skill_file"; then
    fail "$label -- sdd-kb missing 'scope' field documentation"
    ok=false
  fi

  # Must document that scope is required (not optional)
  if ! grep -qi "required\|mandatory\|must" "$skill_file"; then
    fail "$label -- sdd-kb missing indication that scope is required"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.12 URL cache mechanics in sdd-kb SKILL.md
# ---------------------------------------------------------------------------
t2_12() {
  local label="T2.12 URL cache mechanics"
  local skill_file="$REPO_ROOT/skills/sdd-kb/SKILL.md"
  local ok=true

  if [ ! -f "$skill_file" ]; then
    fail "$label -- skills/sdd-kb/SKILL.md missing"
    return
  fi

  # Must reference kb-cache directory (project level)
  if ! grep -q "kb-cache" "$skill_file"; then
    fail "$label -- sdd-kb missing 'kb-cache' directory reference"
    ok=false
  fi

  # Must reference global cache directory ~/.sdd/kb-cache
  if ! grep -q "~/\.sdd/kb-cache\|~/.sdd/kb-cache" "$skill_file"; then
    fail "$label -- sdd-kb missing global '~/.sdd/kb-cache' directory reference"
    ok=false
  fi

  # Must document fetched_at field
  if ! grep -q "fetched_at" "$skill_file"; then
    fail "$label -- sdd-kb missing 'fetched_at' field documentation"
    ok=false
  fi

  # Must document stale_after field
  if ! grep -q "stale_after" "$skill_file"; then
    fail "$label -- sdd-kb missing 'stale_after' field documentation"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.14 Global/project two-layer KB support
# ---------------------------------------------------------------------------
t2_14() {
  local label="T2.14 Global/project two-layer KB support"
  local ok=true

  # sdd-kb SKILL.md must document --global flag
  local skill_file="$REPO_ROOT/skills/sdd-kb/SKILL.md"
  if ! grep -q "\-\-global" "$skill_file"; then
    fail "$label -- sdd-kb missing '--global' flag documentation"
    ok=false
  fi

  # sdd-kb must reference both global (~/.sdd/kb.yaml) and project (.sdd/kb.yaml)
  if ! grep -q "~/\.sdd/kb\.yaml\|~/.sdd/kb.yaml" "$skill_file"; then
    fail "$label -- sdd-kb missing global '~/.sdd/kb.yaml' reference"
    ok=false
  fi

  # status must document --all flag
  if ! grep -q "\-\-all" "$skill_file"; then
    fail "$label -- sdd-kb status missing '--all' flag documentation"
    ok=false
  fi

  # All 8 delegating skills must reference both global and project kb.yaml
  local skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                sdd-review-spec sdd-review-code sdd-verify)
  for skill in "${skills[@]}"; do
    local sf="$REPO_ROOT/skills/$skill/SKILL.md"
    # Must reference global kb (~/.sdd/kb.yaml)
    if ! grep -q "~/\.sdd/kb\.yaml\|~/.sdd/kb.yaml" "$sf"; then
      fail "$label -- $skill missing global '~/.sdd/kb.yaml' reference in KB loading step"
      ok=false
    fi
    # Must describe deduplication logic
    if ! grep -qi "dedup\|deduplicate\|project entry wins\|path.*url" "$sf"; then
      fail "$label -- $skill missing deduplication logic in KB loading step"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.13 KB context loading step present in all 8 delegating skills
# ---------------------------------------------------------------------------
t2_13() {
  local label="T2.13 KB context loading in all delegating skills"
  local ok=true

  local skills=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                sdd-review-spec sdd-review-code sdd-verify)

  for skill in "${skills[@]}"; do
    local skill_file="$REPO_ROOT/skills/$skill/SKILL.md"

    if [ ! -f "$skill_file" ]; then
      fail "$label -- $skill/SKILL.md missing"
      ok=false
      continue
    fi

    # Pre-check section must reference kb.yaml
    local precheck
    precheck=$(sed -n '/^## Pre-check/,/^## /p' "$skill_file")
    if ! echo "$precheck" | grep -q "kb\.yaml"; then
      fail "$label -- $skill Pre-check missing 'kb.yaml' reference"
      ok=false
    fi

    # Pre-check must describe scope filtering
    if ! echo "$precheck" | grep -qi "scope"; then
      fail "$label -- $skill Pre-check missing 'scope' filter for KB loading"
      ok=false
    fi

    # Pre-check must mention kb-cache for URL sources
    if ! echo "$precheck" | grep -q "kb-cache"; then
      fail "$label -- $skill Pre-check missing 'kb-cache' reference for URL sources"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.15 ai_native_kit profile -- completeness and invariants
# ---------------------------------------------------------------------------
t2_15() {
  local label="T2.15 ai_native_kit profile completeness"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # Must have profiles.ai_native_kit section
  if ! grep -q "^  ai_native_kit:" "$delegates"; then
    fail "$label -- delegates.yaml missing 'profiles.ai_native_kit'"
    return
  fi

  # ai_native_kit must override exactly these 9 actions
  local ank_actions=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-code
                     sdd-review-spec sdd-review-code sdd-verify sdd-ship)

  for action in "${ank_actions[@]}"; do
    local found
    found=$(awk "/^  ai_native_kit:/{in_ank=1} in_ank && /^    ${action}:/{print 1; exit}" "$delegates")
    if [ -z "$found" ]; then
      fail "$label -- ai_native_kit profile missing override for '$action'"
      ok=false
    fi
  done

  # ai_native_kit profile must have primary for each single-delegate action
  local ank_single=(sdd-brainstorm sdd-propose sdd-ff sdd-plan sdd-review-spec)
  for action in "${ank_single[@]}"; do
    local has_primary
    has_primary=$(awk "/^  ai_native_kit:/{in_ank=1} in_ank && /^    ${action}:/{in_act=1} in_act && /^      primary:/{print 1; exit}" "$delegates")
    if [ -z "$has_primary" ]; then
      fail "$label -- ai_native_kit.$action missing 'primary'"
      ok=false
    fi
  done

  # ai_native_kit sdd-code must have partial_availability: true
  local ank_code_partial
  ank_code_partial=$(awk "/^  ai_native_kit:/{in_ank=1} in_ank && /^    sdd-code:/{in_act=1} in_act && /partial_availability: true/{print 1; exit}" "$delegates")
  if [ -z "$ank_code_partial" ]; then
    fail "$label -- ai_native_kit.sdd-code missing 'partial_availability: true'"
    ok=false
  fi

  # ai_native_kit sdd-verify must have partial_availability: true
  local ank_verify_partial
  ank_verify_partial=$(awk "/^  ai_native_kit:/{in_ank=1} in_ank && /^    sdd-verify:/{in_act=1} in_act && /partial_availability: true/{print 1; exit}" "$delegates")
  if [ -z "$ank_verify_partial" ]; then
    fail "$label -- ai_native_kit.sdd-verify missing 'partial_availability: true'"
    ok=false
  fi

  # ai_native_kit sdd-ship: sync and archive must still use openspec
  for phase in sync archive; do
    local phase_framework
    phase_framework=$(python3 -c "
import sys, re
content = open('$delegates').read()
m = re.search(r'profiles:.*?ai_native_kit:.*?sdd-ship:(.*?)(?=\n    [a-z]|\nprofiles|\Z)', content, re.DOTALL)
if not m:
    sys.exit(0)
ship_block = m.group(1)
pm = re.search(r'${phase}:.*?framework: (\S+)', ship_block, re.DOTALL)
if pm:
    print(pm.group(1).strip())
" 2>/dev/null || echo "")
    if [ "$phase_framework" != "openspec" ]; then
      fail "$label -- ai_native_kit.sdd-ship.$phase should use openspec, got '$phase_framework'"
      ok=false
    fi
  done

  # ai_native_kit sdd-ship finish must use ai_native_kit framework
  local finish_framework
  finish_framework=$(python3 -c "
import sys, re
content = open('$delegates').read()
m = re.search(r'profiles:.*?ai_native_kit:.*?sdd-ship:(.*?)(?=\n    [a-z]|\nprofiles|\Z)', content, re.DOTALL)
if not m:
    sys.exit(0)
ship_block = m.group(1)
# Match 'finish:' at YAML key indent (8 spaces), not in comments
pm = re.search(r'\n        finish:.*?framework: (\S+)', ship_block, re.DOTALL)
if pm:
    print(pm.group(1).strip())
" 2>/dev/null || echo "")
  if [ "$finish_framework" != "ai_native_kit" ]; then
    fail "$label -- ai_native_kit.sdd-ship.finish must use 'ai_native_kit', got '$finish_framework'"
    ok=false
  fi

  # ai_native_kit sdd-brainstorm must use ecc (no direct counterpart in ai_native_kit)
  local brainstorm_framework
  brainstorm_framework=$(awk "
    /^  ai_native_kit:/{in_ank=1}
    in_ank && /^    sdd-brainstorm:/{in_act=1}
    in_act && /framework:/{gsub(/.*framework: /, \"\"); gsub(/ *$/, \"\"); print; exit}
  " "$delegates")
  if [ "$brainstorm_framework" != "ecc" ]; then
    fail "$label -- ai_native_kit.sdd-brainstorm should use ecc, got '$brainstorm_framework'"
    ok=false
  fi

  if $ok; then pass "$label"; fi
}

# ---------------------------------------------------------------------------
# T2.16 ai_native_kit profile -- transition_suppression coverage
# ---------------------------------------------------------------------------
t2_16() {
  local label="T2.16 ai_native_kit transition_suppression coverage"
  local delegates="$REPO_ROOT/delegates.yaml"
  local ok=true

  # ai_native_kit profile must have transition_suppression for brainstorm, plan, code
  local ank_suppressed=(sdd-brainstorm sdd-plan sdd-code)

  for action in "${ank_suppressed[@]}"; do
    local has_ts
    has_ts=$(awk "
      /^  ai_native_kit:/{in_ank=1}
      in_ank && /^    ${action}:/{in_act=1}
      in_act && /transition_suppression:/{print 1; exit}
    " "$delegates")
    if [ -z "$has_ts" ]; then
      fail "$label -- ai_native_kit.$action missing 'transition_suppression'"
      ok=false
    fi
  done

  # ai_native_kit sdd-brainstorm override_text must contain 'SDD OVERRIDE'
  local has_override_text
  has_override_text=$(awk "
    /^  ai_native_kit:/{in_ank=1}
    in_ank && /^    sdd-brainstorm:/{in_act=1}
    in_act && /SDD OVERRIDE/{print 1; exit}
  " "$delegates")
  if [ -z "$has_override_text" ]; then
    fail "$label -- ai_native_kit.sdd-brainstorm transition_suppression missing 'SDD OVERRIDE' text"
    ok=false
  fi

  # ai_native_kit actions that should NOT have transition_suppression
  local ank_no_ts=(sdd-propose sdd-ff sdd-review-spec sdd-review-code sdd-verify sdd-ship)
  for action in "${ank_no_ts[@]}"; do
    local has_ts
    has_ts=$(awk "
      /^  ai_native_kit:/{in_ank=1}
      in_ank && /^    ${action}:/{in_act=1; next}
      in_act && /^    [a-z]/{in_act=0}
      in_act && /transition_suppression:/{print 1; exit}
    " "$delegates")
    if [ -n "$has_ts" ]; then
      fail "$label -- ai_native_kit.$action has unexpected 'transition_suppression'"
      ok=false
    fi
  done

  if $ok; then pass "$label"; fi
}

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
  t1_11
  t1_12
  t1_13
  t1_14
  t1_15
  t1_16
  echo ""
  echo "=== Configuration Tests ==="
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
  t2_11
  t2_12
  t2_13
  t2_14
  t2_15
  t2_16
  echo ""
  echo "Structural: $PASS passed, $FAIL failed"
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_structural
fi
