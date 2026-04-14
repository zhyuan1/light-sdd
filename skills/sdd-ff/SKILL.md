---
name: sdd-ff
description: Fast-forward -- batch-generate missing artifacts
metadata:
  version: "0.1.0"
  sdd_action: ff
  delegates_to:
    - "ff-change"
  overridable: true
---

# sdd-ff

Fast-forward through the artifact dependency chain by batch-generating all missing required artifacts. Delegates to OpenSpec's `ff-change` skill.

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

---

## Core Execution

**Default delegation**: invoke OpenSpec `ff-change`.

Provide to the delegate:
- Contents of `proposal.md`.
- The list of missing artifacts to generate.
- The corresponding templates (`templates/spec.md`, `templates/tasks.md`) as format guides.
- Contents of `design.md` if it exists (as additional context for task generation).

Expect from the delegate:
- All listed artifacts generated in their correct file locations.

### Override

| Alternative | When to prefer |
|---|---|
| ECC `plan` | When OpenSpec is not installed -- use to generate tasks |
| Manual | User wants to write artifacts by hand |

---

## Post-check

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
