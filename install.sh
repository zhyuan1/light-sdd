#!/usr/bin/env bash
set -euo pipefail

# light-sdd installer
# Copies SDD skills, commands, and templates into the target directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TEMPLATES_SRC="$SCRIPT_DIR/templates"
COMMANDS_SRC="$SCRIPT_DIR/commands"
SCHEMA_SRC="$SCRIPT_DIR/schema.yaml"

# Default install root: ~/.claude
# Skills -> <root>/skills/, Commands -> <root>/commands/
INSTALL_ROOT="${SDD_INSTALL_ROOT:-$HOME/.claude}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install light-sdd skills, commands, and templates for Claude Code.

Options:
  --target DIR    Install to DIR (skills/ and commands/ created inside)
  --project       Install into the current project (.claude/) instead of user-level
  --check         Verify installation integrity without installing
  --uninstall     Remove SDD skills, commands, and templates
  -h, --help      Show this help

Examples:
  ./install.sh                          # Install to ~/.claude/
  ./install.sh --target .claude-internal  # Install to .claude-internal/
  ./install.sh --project                # Install to ./.claude/
  ./install.sh --check                  # Verify existing installation
  ./install.sh --uninstall              # Remove SDD from default location
  ./install.sh --uninstall --target .claude-internal  # Remove from custom location
EOF
}

SDD_SKILLS=(
  sdd-brainstorm
  sdd-propose
  sdd-ff
  sdd-plan
  sdd-code
  sdd-review-spec
  sdd-review-code
  sdd-verify
  sdd-ship
  sdd-status
)

SDD_TEMPLATES=(
  brainstorm.md
  proposal.md
  spec.md
  design.md
  tasks.md
  plan.md
  review.md
)

SDD_COMMANDS=(
  sdd-status.md
  sdd-brainstorm.md
  sdd-propose.md
  sdd-ff.md
  sdd-plan.md
  sdd-code.md
  sdd-review-spec.md
  sdd-review-code.md
  sdd-verify.md
  sdd-ship.md
)

do_install() {
  local root="$1"
  local skills_dir="$root/skills"
  local commands_dir="$root/commands"

  echo "Installing light-sdd to: $root"
  echo "  skills  -> $skills_dir"
  echo "  commands -> $commands_dir"
  echo ""

  # Install skills
  for skill in "${SDD_SKILLS[@]}"; do
    local dest="$skills_dir/$skill"
    mkdir -p "$dest"
    cp "$SKILLS_SRC/$skill/SKILL.md" "$dest/SKILL.md"
    echo "  skill: $skill"
  done

  # Install templates into a shared sdd-templates directory
  local tmpl_dest="$skills_dir/sdd-templates"
  mkdir -p "$tmpl_dest"
  for tmpl in "${SDD_TEMPLATES[@]}"; do
    cp "$TEMPLATES_SRC/$tmpl" "$tmpl_dest/$tmpl"
    echo "  template: $tmpl"
  done

  # Install schema
  cp "$SCHEMA_SRC" "$tmpl_dest/schema.yaml"
  echo "  schema: schema.yaml"

  # Install commands
  mkdir -p "$commands_dir"
  for cmd in "${SDD_COMMANDS[@]}"; do
    cp "$COMMANDS_SRC/$cmd" "$commands_dir/$cmd"
    echo "  command: $cmd"
  done

  echo ""
  echo "Done. Installed ${#SDD_SKILLS[@]} skills, ${#SDD_COMMANDS[@]} commands, ${#SDD_TEMPLATES[@]} templates, 1 schema."
  echo ""
  echo "Available commands:"
  echo "  /sdd-status       -- Check progress of a change"
  echo "  /sdd-brainstorm   -- Brainstorm ideas for a change"
  echo "  /sdd-propose      -- Create a change proposal"
  echo "  /sdd-ff           -- Fast-forward: generate missing artifacts"
  echo "  /sdd-plan         -- Plan the next batch of tasks"
  echo "  /sdd-code         -- Implement tasks with TDD"
  echo "  /sdd-review-spec  -- Review specs for quality"
  echo "  /sdd-review-code  -- Two-phase code review"
  echo "  /sdd-verify       -- Verify implementation against specs"
  echo "  /sdd-ship         -- Finalize and ship the change"
}

do_check() {
  local root="$1"
  local skills_dir="$root/skills"
  local commands_dir="$root/commands"
  local errors=0

  echo "Checking light-sdd installation at: $root"
  echo ""

  for skill in "${SDD_SKILLS[@]}"; do
    if [ -f "$skills_dir/$skill/SKILL.md" ]; then
      echo "  [ok] $skill"
    else
      echo "  [MISSING] $skill"
      errors=$((errors + 1))
    fi
  done

  local tmpl_dest="$skills_dir/sdd-templates"
  for tmpl in "${SDD_TEMPLATES[@]}"; do
    if [ -f "$tmpl_dest/$tmpl" ]; then
      echo "  [ok] template: $tmpl"
    else
      echo "  [MISSING] template: $tmpl"
      errors=$((errors + 1))
    fi
  done

  if [ -f "$tmpl_dest/schema.yaml" ]; then
    echo "  [ok] schema.yaml"
  else
    echo "  [MISSING] schema.yaml"
    errors=$((errors + 1))
  fi

  for cmd in "${SDD_COMMANDS[@]}"; do
    if [ -f "$commands_dir/$cmd" ]; then
      echo "  [ok] command: $cmd"
    else
      echo "  [MISSING] command: $cmd"
      errors=$((errors + 1))
    fi
  done

  echo ""
  if [ "$errors" -eq 0 ]; then
    echo "All checks passed."
  else
    echo "$errors item(s) missing. Run ./install.sh to fix."
  fi
  return "$errors"
}

do_uninstall() {
  local root="$1"
  local skills_dir="$root/skills"
  local commands_dir="$root/commands"

  echo "Uninstalling light-sdd from: $root"
  echo ""

  for skill in "${SDD_SKILLS[@]}"; do
    if [ -d "$skills_dir/$skill" ]; then
      rm -rf "$skills_dir/$skill"
      echo "  removed: $skill"
    fi
  done

  if [ -d "$skills_dir/sdd-templates" ]; then
    rm -rf "$skills_dir/sdd-templates"
    echo "  removed: sdd-templates"
  fi

  for cmd in "${SDD_COMMANDS[@]}"; do
    if [ -f "$commands_dir/$cmd" ]; then
      rm -f "$commands_dir/$cmd"
      echo "  removed: command $cmd"
    fi
  done

  echo ""
  echo "Done."
}

# Parse arguments
ACTION="install"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --project)
      INSTALL_ROOT=".claude"
      shift
      ;;
    --check)
      ACTION="check"
      shift
      ;;
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

case "$ACTION" in
  install)
    do_install "$INSTALL_ROOT"
    ;;
  check)
    do_check "$INSTALL_ROOT"
    ;;
  uninstall)
    do_uninstall "$INSTALL_ROOT"
    ;;
esac
