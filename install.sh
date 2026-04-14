#!/usr/bin/env bash
set -euo pipefail

# light-sdd installer
# Copies SDD skills and templates into the Claude Code skill directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TEMPLATES_SRC="$SCRIPT_DIR/templates"
COMMANDS_SRC="$SCRIPT_DIR/commands"
SCHEMA_SRC="$SCRIPT_DIR/schema.yaml"

# Default install targets
CLAUDE_SKILLS_DIR="${SDD_INSTALL_DIR:-$HOME/.claude/skills}"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install light-sdd skills and templates for Claude Code.

Options:
  --target DIR    Install skills to DIR instead of ~/.claude/skills/
  --project       Install into the current project (.claude/skills/) instead of user-level
  --check         Verify installation integrity without installing
  --uninstall     Remove SDD skills and templates
  -h, --help      Show this help

Examples:
  ./install.sh                  # Install to ~/.claude/skills/
  ./install.sh --project        # Install to ./.claude/skills/
  ./install.sh --check          # Verify existing installation
  ./install.sh --uninstall      # Remove SDD skills
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
  local target="$1"

  echo "Installing light-sdd to: $target"
  echo ""

  # Install skills
  for skill in "${SDD_SKILLS[@]}"; do
    local dest="$target/$skill"
    mkdir -p "$dest"
    cp "$SKILLS_SRC/$skill/SKILL.md" "$dest/SKILL.md"
    echo "  skill: $skill"
  done

  # Install templates into a shared sdd-templates directory
  local tmpl_dest="$target/sdd-templates"
  mkdir -p "$tmpl_dest"
  for tmpl in "${SDD_TEMPLATES[@]}"; do
    cp "$TEMPLATES_SRC/$tmpl" "$tmpl_dest/$tmpl"
    echo "  template: $tmpl"
  done

  # Install schema
  cp "$SCHEMA_SRC" "$tmpl_dest/schema.yaml"
  echo "  schema: schema.yaml"

  # Install commands
  local cmd_dest="$CLAUDE_COMMANDS_DIR"
  if [ "$target" != "$HOME/.claude/skills" ]; then
    # Project-level install: put commands next to skills
    cmd_dest="$(dirname "$target")/commands"
  fi
  mkdir -p "$cmd_dest"
  for cmd in "${SDD_COMMANDS[@]}"; do
    cp "$COMMANDS_SRC/$cmd" "$cmd_dest/$cmd"
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
  local target="$1"
  local errors=0

  echo "Checking light-sdd installation at: $target"
  echo ""

  for skill in "${SDD_SKILLS[@]}"; do
    if [ -f "$target/$skill/SKILL.md" ]; then
      echo "  [ok] $skill"
    else
      echo "  [MISSING] $skill"
      ((errors++))
    fi
  done

  local tmpl_dest="$target/sdd-templates"
  for tmpl in "${SDD_TEMPLATES[@]}"; do
    if [ -f "$tmpl_dest/$tmpl" ]; then
      echo "  [ok] template: $tmpl"
    else
      echo "  [MISSING] template: $tmpl"
      ((errors++))
    fi
  done

  if [ -f "$tmpl_dest/schema.yaml" ]; then
    echo "  [ok] schema.yaml"
  else
    echo "  [MISSING] schema.yaml"
    ((errors++))
  fi

  # Check commands
  local cmd_dest="$CLAUDE_COMMANDS_DIR"
  if [ "$target" != "$HOME/.claude/skills" ]; then
    cmd_dest="$(dirname "$target")/commands"
  fi
  for cmd in "${SDD_COMMANDS[@]}"; do
    if [ -f "$cmd_dest/$cmd" ]; then
      echo "  [ok] command: $cmd"
    else
      echo "  [MISSING] command: $cmd"
      ((errors++))
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
  local target="$1"

  echo "Uninstalling light-sdd from: $target"
  echo ""

  for skill in "${SDD_SKILLS[@]}"; do
    if [ -d "$target/$skill" ]; then
      rm -rf "$target/$skill"
      echo "  removed: $skill"
    fi
  done

  if [ -d "$target/sdd-templates" ]; then
    rm -rf "$target/sdd-templates"
    echo "  removed: sdd-templates"
  fi

  # Remove commands
  local cmd_dest="$CLAUDE_COMMANDS_DIR"
  if [ "$target" != "$HOME/.claude/skills" ]; then
    cmd_dest="$(dirname "$target")/commands"
  fi
  for cmd in "${SDD_COMMANDS[@]}"; do
    if [ -f "$cmd_dest/$cmd" ]; then
      rm -f "$cmd_dest/$cmd"
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
      CLAUDE_SKILLS_DIR="$2"
      shift 2
      ;;
    --project)
      CLAUDE_SKILLS_DIR=".claude/skills"
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
    do_install "$CLAUDE_SKILLS_DIR"
    ;;
  check)
    do_check "$CLAUDE_SKILLS_DIR"
    ;;
  uninstall)
    do_uninstall "$CLAUDE_SKILLS_DIR"
    ;;
esac
