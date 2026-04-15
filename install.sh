#!/usr/bin/env bash
set -euo pipefail

# light-sdd installer
# Copies SDD skills, commands, and templates into the target directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TEMPLATES_SRC="$SCRIPT_DIR/templates"
COMMANDS_SRC="$SCRIPT_DIR/commands"
SCHEMA_SRC="$SCRIPT_DIR/schema.yaml"

SDD_REPO="https://github.com/zhyuan1/light-sdd.git"
SDD_LOCAL_VERSION=$(grep '^version:' "$SCHEMA_SRC" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")

# Default install root: ~/.claude
# Skills -> <root>/skills/, Commands -> <root>/commands/
INSTALL_ROOT="${SDD_INSTALL_ROOT:-$HOME/.claude}"
LANG_CHOICE="en"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install light-sdd skills, commands, and templates for Claude Code.

Options:
  --target DIR    Install to DIR (skills/ and commands/ created inside)
  --lang LANG     Template language: en (default) or zh-CN
  --project       Install into the current project (.claude/) instead of user-level
  --check         Verify installation integrity without installing
  --update        Pull latest from GitHub and reinstall
  --uninstall     Remove SDD skills, commands, and templates
  -h, --help      Show this help

Examples:
  ./install.sh                            # Install to ~/.claude/ (English)
  ./install.sh --lang zh-CN              # Install with Chinese templates
  ./install.sh --target .claude-internal --lang zh-CN
  ./install.sh --project                  # Install to ./.claude/
  ./install.sh --check                    # Verify existing installation
  ./install.sh --update                   # Pull latest + reinstall
  ./install.sh --uninstall               # Remove SDD from default location
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
  local tmpl_src="$TEMPLATES_SRC"
  if [ "$LANG_CHOICE" != "en" ] && [ -d "$TEMPLATES_SRC/$LANG_CHOICE" ]; then
    tmpl_src="$TEMPLATES_SRC/$LANG_CHOICE"
    echo "  language: $LANG_CHOICE"
  fi
  local tmpl_dest="$skills_dir/sdd-templates"
  mkdir -p "$tmpl_dest"
  for tmpl in "${SDD_TEMPLATES[@]}"; do
    cp "$tmpl_src/$tmpl" "$tmpl_dest/$tmpl"
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

do_update() {
  local root="$1"

  echo "light-sdd updater"
  echo "  Local version:  $SDD_LOCAL_VERSION"
  echo "  Source repo:    $SDD_REPO"
  echo ""

  # Step 1: Check if we are inside the light-sdd repo
  local in_repo=false
  if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local remote_url
    remote_url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")
    if [[ "$remote_url" == *"light-sdd"* ]]; then
      in_repo=true
    fi
  fi

  if $in_repo; then
    # We are inside the cloned repo -- just pull
    echo "Pulling latest from origin..."
    local before_sha after_sha
    before_sha=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
    git -C "$SCRIPT_DIR" pull --ff-only 2>&1 | sed 's/^/  /'
    after_sha=$(git -C "$SCRIPT_DIR" rev-parse HEAD)

    if [ "$before_sha" = "$after_sha" ]; then
      echo ""
      echo "Already up to date ($SDD_LOCAL_VERSION)."

      # Still reinstall in case the install target is stale
      echo "Reinstalling to ensure target is in sync..."
      echo ""
      do_install "$root"
      return
    fi

    # Re-read version after pull
    local new_version
    new_version=$(grep '^version:' "$SCHEMA_SRC" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")
    echo ""
    echo "Updated: $SDD_LOCAL_VERSION -> $new_version"
    echo ""

    # Show what changed
    echo "Changes:"
    git -C "$SCRIPT_DIR" log --oneline "${before_sha}..${after_sha}" | sed 's/^/  /'
    echo ""

    # Reinstall
    do_install "$root"
  else
    # We are running from an installed copy or arbitrary location
    # Clone/pull to a temp dir, then reinstall from there
    local tmpdir
    tmpdir=$(mktemp -d /tmp/light-sdd-update-XXXX)
    trap "rm -rf '$tmpdir'" EXIT

    echo "Cloning latest from $SDD_REPO..."
    git clone --depth 1 "$SDD_REPO" "$tmpdir" 2>&1 | sed 's/^/  /'

    local new_version
    new_version=$(grep '^version:' "$tmpdir/schema.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")
    echo ""
    echo "Remote version: $new_version"

    if [ "$SDD_LOCAL_VERSION" = "$new_version" ]; then
      echo "Already up to date."
      echo ""
      echo "Reinstalling to ensure target is in sync..."
    else
      echo "Updating: $SDD_LOCAL_VERSION -> $new_version"
    fi
    echo ""

    # Run install from the fresh clone
    bash "$tmpdir/install.sh" --target "$root"
  fi
}

# Parse arguments
ACTION="install"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --lang)
      LANG_CHOICE="$2"
      if [ "$LANG_CHOICE" != "en" ] && [ ! -d "$SCRIPT_DIR/templates/$LANG_CHOICE" ]; then
        echo "Error: language '$LANG_CHOICE' not available. Options: en, zh-CN"
        exit 1
      fi
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
    --update)
      ACTION="update"
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
  update)
    do_update "$INSTALL_ROOT"
    ;;
  uninstall)
    do_uninstall "$INSTALL_ROOT"
    ;;
esac
