---
name: sdd-code
description: Execute implementation tasks with TDD discipline
metadata:
  version: "0.1.0"
  sdd_action: code
  delegates_to:
    - "test-driven-development"
    - "executing-plans"
    - "systematic-debugging"
  overridable: true
---

# sdd-code

Execute implementation tasks following TDD discipline. Delegates to Superpowers' `test-driven-development`, `executing-plans`, and `systematic-debugging` skills as needed.

---

## Pre-check

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.

2. **Tasks gate**: `tasks.md` must exist with at least one unchecked task (`- [ ]`).
   - If all tasks are checked: "All tasks complete. Run `/sdd-verify` to validate." and stop.
   - If `tasks.md` does not exist: "No tasks found. Run `/sdd-ff` to generate." and stop.

3. **Plan parsing** (SDD self-logic):
   - If `plan.md` exists, read it to identify the current batch and per-task detail (approach, files, tests, complexity).
   - If `plan.md` does not exist, fall back to `tasks.md` -- pick the next unchecked task in the earliest incomplete batch.

4. **Load spec context**:
   - For the target task, read the `spec:` reference to identify the capability.
   - Load the corresponding `specs/<capability>/spec.md` for: Interfaces, Behavior, Acceptance Criteria.
   - This context is provided to the delegate so implementation aligns with the spec.

---

## Core Execution

### Primary delegation: `executing-plans`

If `plan.md` exists, invoke `executing-plans` with:
- The current batch detail from `plan.md`.
- The referenced spec context for each task.
- Instruction to follow TDD discipline (see below).

### TDD discipline: `test-driven-development`

For each task, enforce the RED-GREEN-REFACTOR cycle:
1. **RED**: Write a failing test based on the spec's Acceptance Criteria and Behavior.
2. **GREEN**: Write minimal implementation to pass the test.
3. **REFACTOR**: Clean up while keeping tests green.

This applies whether executing via `executing-plans` or directly from `tasks.md`.

### Error recovery: `systematic-debugging`

If tests fail unexpectedly or implementation encounters errors:
- Invoke `systematic-debugging` to find root cause before attempting fixes.
- Do not apply symptom fixes -- always trace to root cause.

### Override

| Alternative | When to prefer |
|---|---|
| ECC `tdd` | When Superpowers is not installed |
| ECC `hunt` | Alternative to `systematic-debugging` |
| Direct coding | User explicitly opts out of TDD for this task |

---

## Post-check

1. **Task status update** (SDD self-logic):
   - For each completed task, update `tasks.md`: change `- [ ]` to `- [x]`.
   - If the task was partially completed, leave it unchecked and add a note.

2. **Test verification**:
   - Confirm all tests pass for the implemented capability.
   - If tests fail, do not mark the task complete.

3. **Batch progress check**:
   - Count remaining unchecked tasks in the current batch.
   - If more tasks remain in batch:
     > Task complete (N remaining in Batch M). Run `/sdd-code` to continue.
   - If batch complete but more batches remain:
     > Batch M complete. Run `/sdd-plan` to plan next batch, or `/sdd-code` to continue directly.
   - If all tasks complete:
     > All tasks complete. Run `/sdd-review-code` for code review, then `/sdd-verify`.
