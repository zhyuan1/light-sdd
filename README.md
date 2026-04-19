# light-sdd

Lightweight, composable, pluggable Spec-Driven Development workflow for Claude Code.

SDD is a thin orchestration layer. It does not implement core capabilities -- it delegates to battle-tested skills from OpenSpec, Superpowers, ECC, or any framework you choose.

## What SDD Does

- **Orchestrates** -- defines the flow: brainstorm, propose, spec, plan, code, review, verify, ship
- **Validates** -- checks artifact quality against a schema after each step
- **Guides** -- tells you what to do next based on what exists
- **Delegates** -- the hard work goes to OpenSpec, Superpowers, or your preferred skills

## Architecture

```
Schema (schema.yaml)         -- content constraints: what each artifact must contain
    |
Templates (templates/)       -- interface contracts: standard format for each artifact
    |
Actions (skills/)            -- flow orchestration: pre-check -> delegate -> post-check
```

Each action skill follows a three-part structure:

1. **Pre-check** (SDD-owned): validate dependencies, locate change directory, load KB context
2. **Core Execution** (delegate): invoke the configured bottom-layer skill
3. **Post-check** (SDD-owned): review loop, format validation, next-step guidance

## Installation

```bash
# User-level (all projects)
./install.sh

# With Chinese templates
./install.sh --lang zh-CN

# Project-level (current project only)
./install.sh --project

# Custom target directory
./install.sh --target .claude-internal

# Combine options
./install.sh --target .claude-internal --lang zh-CN

# Verify installation
./install.sh --check

# Update to latest version
./install.sh --update

# Uninstall
./install.sh --uninstall
```

### Prerequisites

SDD delegates to these frameworks by default:

| Framework | Used by | Install |
|-----------|---------|---------|
| [OpenSpec](https://github.com/fission-ai/openspec) | propose, ff, verify, ship | `npm i -g @fission-ai/openspec` |
| [Superpowers](https://github.com/obra/superpowers) | brainstorm, plan, code, review-code, verify, ship | Copy skills to `~/.claude/skills/` |

Each SDD action automatically detects whether the target framework is available at runtime. If not found, it falls back to an alternative skill (typically ECC) or manual mode. No manual configuration needed.

## Workflow

### Full flow (large feature)

```
sdd-brainstorm -> sdd-propose -> sdd-ff -> sdd-review-spec
                                               |
                                 sdd-plan -> sdd-code (repeat)
                                               |
                           sdd-review-code -> sdd-verify -> sdd-ship
```

### Minimal flow (small fix)

```
sdd-propose -> sdd-ff -> sdd-code -> sdd-ship
```

### Gradual adoption

Start with just the core loop and add quality gates as needed:

| Level | Actions | What you get |
|-------|---------|--------------|
| Basic | propose, ff, code, ship | Spec-driven development |
| Review | + review-spec, review-code | Quality gates |
| Full | + brainstorm, plan, verify | Complete engineering discipline |

Use `sdd-status` at any point to see where you are.

## Actions

| Action | Purpose | Delegates to |
|--------|---------|-------------|
| `/sdd-brainstorm` | Divergent exploration before committing | Superpowers `brainstorming` |
| `/sdd-propose` | Create a change proposal | OpenSpec `continue-change` |
| `/sdd-ff` | Batch-generate missing artifacts | OpenSpec `ff-change` |
| `/sdd-plan` | Detailed plan for the next task batch | Superpowers `writing-plans` |
| `/sdd-code` | Implement tasks with TDD | Superpowers `test-driven-development` + `executing-plans` + `systematic-debugging` |
| `/sdd-review-spec` | Review specs for quality | SDD subagent (no delegation) |
| `/sdd-review-code` | Two-phase code review | Phase 1: SDD spec compliance, Phase 2: Superpowers `requesting-code-review` |
| `/sdd-verify` | Verify implementation against specs | OpenSpec `verify-change` + Superpowers `verification-before-completion` |
| `/sdd-ship` | Sync specs, archive, finish branch | OpenSpec `sync-specs` + `archive-change` + Superpowers `finishing-a-development-branch` |
| `/sdd-status` | Scan artifacts, report progress | SDD self-logic (no delegation) |
| `/sdd-use` | Switch active delegate profile | SDD self-logic (no delegation) |
| `/sdd-kb` | Manage knowledge base registry | SDD self-logic (no delegation) |

## Delegate Profiles

SDD ships with a `delegates.yaml` registry mapping every action to its primary skill(s), fallbacks, and manual-mode messages. The active profile controls which framework handles each action.

### Switch profiles

```bash
/sdd-use              # list available profiles and current active
/sdd-use gstack       # activate gstack profile
/sdd-use default      # reset to superpowers / openspec / ecc
```

The active profile is persisted to `.sdd/config.yaml` and read before every skill invocation.

### Built-in profiles

| Profile | Framework | Notes |
|---------|-----------|-------|
| `default` | Superpowers + OpenSpec + ECC fallback | Installed out of the box |
| `gstack` | gstack skills | Alternative framework stack; falls through to manual if not installed |
| `ai_native_kit` | LCT AI-Native Kit skills | Enterprise workflow stack (requirement-spec, backend/frontend-task-executor, design-review, etc.); ECC `think` fills brainstorming since the framework starts from structured requirements |

### Adding profiles

Add a named block under `profiles:` in `delegates.yaml`. Each profile entry for an action replaces that action's `primary`, `fallback`, and `transition_suppression` keys. Actions absent from a profile inherit base (default) values.

## Knowledge Base

`/sdd-kb` manages a registry of project-specific context -- architecture docs, coding standards, domain models, security guidelines -- that SDD injects into skills at the right workflow stage.

### Two registry layers

| Layer | Location | Scope |
|-------|----------|-------|
| Global | `~/.sdd/kb.yaml` | Set once, applies to every project |
| Project | `.sdd/kb.yaml` | Per-project additions and overrides |

When both layers are active, global sources are merged with project sources. Same-id entries resolve in favour of the project layer.

### Commands

```bash
/sdd-kb init [--global]               # create empty kb.yaml scaffold
/sdd-kb add [--global] <path-or-url>  # register a local file, directory, or URL
/sdd-kb update [--global] [id]        # re-fetch and refresh cached URL sources
/sdd-kb status [--global|--all]       # show which sources each action will load
```

### Scope inference

When you run `/sdd-kb add`, SDD reads each document's filename, heading, and first 200 characters, then maps it to the relevant SDD actions automatically:

| Keywords | Injected into |
|----------|--------------|
| architecture, system, component, design | sdd-brainstorm, sdd-propose, sdd-ff, sdd-review-spec |
| coding, standard, convention, style | sdd-code, sdd-review-code, sdd-ff |
| domain, model, entity, business | sdd-brainstorm, sdd-propose, sdd-ff |
| security, auth, permission | sdd-review-code, sdd-verify |
| api, interface, endpoint | sdd-code, sdd-review-code |
| test, qa, quality, coverage | sdd-verify, sdd-review-code |
| plan, task, roadmap | sdd-plan, sdd-ff |

You confirm or adjust the inferred scope before anything is written.

### Example

```bash
# Set up global KB once
/sdd-kb init --global
/sdd-kb add --global ~/company-kb/
/sdd-kb status --global

# Add project-specific KB
/sdd-kb init
/sdd-kb add ./docs/api-spec.md
/sdd-kb status --all

# From this point, /sdd-code pre-check automatically loads
# coding-standards.md + auth-patterns.md as context.
```

## Artifact Dependency Chain

```
brainstorm.md -> proposal.md -> specs/ -> design.md -> tasks.md -> plan.md
  (optional)      (required)   (required)  (optional)  (required)  (optional)
```

All artifacts live in `.sdd/changes/<change-name>/`. Progress is inferred from which files exist -- no separate state tracking.

## Change Directory Structure

```
.sdd/
  changes/<change-name>/
    brainstorm.md          # optional
    proposal.md            # required
    specs/
      <capability>/spec.md # required, one per capability
    design.md              # optional
    tasks.md               # required
    plan.md                # optional
    reviews/               # generated by review/verify actions
      spec-review-*.md
      code-review-*.md
      verification-*.md
  config.yaml              # active_profile: <name>
  kb.yaml                  # project KB registry (if initialised)
  kb-cache/                # cached URL sources (if any)
```

## Override Mechanism

### Automatic Fallback

Every delegating action includes a **Delegation availability check** in its Pre-check phase. It searches for the target skill in the standard skill paths (`~/.claude/skills/`, `.claude/skills/`, project-configured paths). If the target is not found:

1. Try the listed fallback skill (e.g., ECC `think` instead of Superpowers `brainstorming`)
2. If fallback also missing, proceed in manual mode (SDD guides the user through the template directly)
3. Inform the user which skill is being used and why

This means SDD works out of the box -- install OpenSpec and Superpowers for the best experience, but SDD degrades gracefully without them.

### Manual Override

Each action's SKILL.md also contains an Override section listing alternative skills. To permanently switch from the default, edit the skill file or replace the delegation target. Example:

**Default** (Superpowers installed):
```
Core Execution: invoke brainstorming
```

**Override** (ECC instead):
```
Core Execution: invoke think
```

### Transition Suppression

Some Superpowers skills auto-advance to the next skill after completion. SDD suppresses this to keep orchestration control:

| SDD Action | Suppressed transition |
|------------|---------------------|
| `sdd-brainstorm` | brainstorming -> writing-plans |
| `sdd-plan` | writing-plans -> executing-plans |
| `sdd-code` | executing-plans -> git-worktrees / finishing-branch |

## Provenance

Every generated artifact carries YAML frontmatter recording its origin:

```yaml
---
generated_by:
  framework: superpowers    # which framework the bottom-layer skill belongs to
  skill: brainstorming      # the specific skill that produced this artifact
sdd_action: sdd-brainstorm  # SDD action that orchestrated it
timestamp: "2026-04-15T10:00:00Z"
---
```

This enables traceability for debugging, override auditing, and team handoffs.

## Schema

`schema.yaml` defines content constraints for all 7 artifact types and the provenance frontmatter spec. It specifies which sections are required in each artifact but says nothing about flow or execution. Templates are the interface contract between schema and actions.

## Templates

Templates are available in two languages:

| Language | Directory | Install |
|----------|-----------|---------|
| English (default) | `templates/` | `./install.sh` |
| Chinese | `templates/zh-CN/` | `./install.sh --lang zh-CN` |

Both maintain the same section structure and provenance frontmatter. Schema validation works with either language.

## License

MIT
