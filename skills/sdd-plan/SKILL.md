---
name: sdd-plan
description: Create a detailed execution plan for the current batch
metadata:
  version: "0.1.0"
  sdd_action: plan
  delegates_to:
    - "writing-plans"
  overridable: true
---

# sdd-plan

Create a detailed, actionable execution plan for the next batch of tasks. Delegates to Superpowers' `writing-plans` skill for structured plan generation.

---

## Pre-check

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.

2. **Tasks gate**: `tasks.md` must exist.
   - If missing: "No tasks found. Run `/sdd-ff` to generate." and stop.

3. **Batch positioning** (SDD self-logic):
   - Parse `tasks.md` to identify batches and their completion status.
   - Find the first batch with at least one unchecked task (`- [ ]`).
   - If all batches are complete: "All tasks done. Run `/sdd-verify` to validate." and stop.
   - Report: "Planning for Batch N (M unchecked tasks)."

4. **Context loading**:
   - Read all specs referenced by tasks in the target batch (from `specs/<capability>/spec.md`).
   - Read `design.md` if it exists.
   - Read the current codebase structure relevant to the batch tasks.

5. **Template seeding**:
   - If `plan.md` does not exist, copy `templates/plan.md` into the change directory.
   - If `plan.md` exists from a previous batch, it will be overwritten for the new batch.

---

## Core Execution

**Default delegation**: invoke Superpowers `writing-plans`.

Provide to the delegate:
- The target batch tasks from `tasks.md` (task titles, spec references, sizes).
- The full content of each referenced spec (Interfaces, Behavior, Acceptance Criteria).
- Contents of `design.md` if available.
- Relevant codebase context (file tree, existing implementations).
- Instruction: for each task, produce a plan entry with approach, exact files to touch, test strategy, and complexity estimate. Every step must be actionable within 2-5 minutes.

Expect from the delegate:
- A populated `plan.md` with:
  - Current Batch identified.
  - Task Detail for every task in the batch.
  - Each task detail includes approach, files, tests, and complexity.

### Override

| Alternative | When to prefer |
|---|---|
| ECC `plan` / `think` | When Superpowers is not installed |
| Manual | User wants to plan themselves |

---

## Post-check

1. **Completeness validation**:
   - Verify `plan.md` identifies the correct batch.
   - Verify every unchecked task in the batch has a corresponding Task Detail section.
   - Verify each Task Detail has non-empty: Approach, Files, Tests.
   - If any gap, report it and re-invoke the delegate for the missing tasks.

2. **Plan-reviewer loop** (SDD self-logic):
   Present the plan to the user for approval. Check:
   - Does each task's approach align with the referenced spec?
   - Are file paths plausible (do the directories exist)?
   - Is the test strategy concrete (not vague "add tests")?

   If the user requests revisions, re-invoke the delegate with feedback. **Max 2 revision rounds**.

3. **Next-step guidance**:
   > Plan approved for Batch N.
   > Next: run `/sdd-code` to start implementing.
