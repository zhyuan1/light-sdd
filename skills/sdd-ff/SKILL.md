---
name: sdd-ff
description: Fast-forward -- batch-generate missing artifacts
metadata:
  version: "0.1.0"
  sdd_action: ff
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-ff

Fast-forward through the artifact dependency chain by batch-generating all missing required artifacts. Delegates to the skill configured in `delegates.yaml`.

---

## Pre-check

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.

2. **Proposal gate**: `proposal.md` must exist and be non-empty.
   - If missing: "No proposal found. Run `/sdd-propose` first." and stop.

3. **Missing artifact identification** (SDD self-logic):
   Walk the dependency chain and build a list of what needs generating:

   | Artifact | Check |
   |---|---|
   | `specs/<cap>/spec.md` | For each capability in `proposal.md`, check if its spec exists |
   | `tasks.md` | Check if file exists |

   Also note optional missing artifacts (`design.md`) but do not require them.

4. **Report batch to user**:
   > Will generate: spec for `auth`, spec for `storage`, tasks.md.
   > Proceed? (y/n)

   Wait for confirmation before proceeding.

5. **KB context loading**:
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-ff`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-ff`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context.
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: architecture.md [global], coding-standards.md [project]" (or "No KB sources for this action.")

6. **Delegation**: Resolve delegates per `delegates.yaml → sdd-ff`,
   following `delegation-protocol.md`. Record resolved framework/skill for provenance.

---

## Core Execution

Invoke the delegate resolved by `delegates.yaml → sdd-ff` following `delegation-protocol.md`.

Provide to the delegate:
- Contents of `proposal.md`.
- The list of missing artifacts to generate.
- The corresponding templates (`templates/spec.md`, `templates/tasks.md`) as format guides.
- Contents of `design.md` if it exists (as additional context for task generation).

Expect from the delegate:
- All listed artifacts generated in their correct file locations.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-ff`.
> Use `/sdd-use <profile>` to switch framework stacks.

---

## Post-check

0. **Provenance stamp**: for each generated artifact (specs, tasks.md, design.md), update its YAML frontmatter with the framework and skill resolved during Pre-check delegation:
   - `generated_by.framework`: the resolved framework
   - `generated_by.skill`: the resolved skill
   - `sdd_action`: `sdd-ff`
   - `timestamp`: current ISO 8601 timestamp

1. **Per-artifact validation**:
   For each generated artifact, validate against `schema.yaml`:
   - **spec.md**: must have Requirements, Interfaces, Behavior, Acceptance Criteria.
   - **tasks.md**: must have Task List, Dependency Order, Verification Task.
   If any artifact fails validation, re-invoke the delegate for just that artifact with the specific gaps listed. Max 2 retries per artifact.

2. **Cross-reference check**:
   - Every capability in `proposal.md` must have a corresponding `specs/<cap>/spec.md`.
   - Every spec must reference a capability that exists in the proposal.
   - Flag orphans in either direction.

3. **Task-spec alignment**:
   - If `tasks.md` was generated, verify each task references a valid capability from `specs/`.
   - Flag any task that references a non-existent spec.

4. **Next-step guidance**:
   > Fast-forward complete. Generated N specs and tasks.md.
   > Next: run `/sdd-review-spec` to validate specs, `/sdd-plan` to create an execution plan, or `/sdd-code` to start implementing.
