---
name: sdd-code
description: Execute implementation tasks with TDD discipline
metadata:
  version: "0.1.0"
  sdd_action: code
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-code

Execute implementation tasks following TDD discipline. Delegates to the skills configured in `delegates.yaml`.

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

5. **KB context loading**:
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-code`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-code`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context.
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: coding-standards.md [global], internal-api.md [project]" (or "No KB sources for this action.")

6. **Delegation**: Resolve delegates per `delegates.yaml → sdd-code`,
   following `delegation-protocol.md` (partial availability mode). Record resolved framework/skills for provenance.

---

## Core Execution

**Use the Skill tool** to invoke each delegate resolved in Pre-check step 6 (partial availability mode). These are mandatory tool calls — do not perform the implementation work inline.

```
Skill({ skill: "<resolved-skill-name>", args: "<context>" })
```

### Primary delegation: execution

**Use the Skill tool** to invoke the primary execution delegate (e.g. `executing-plans`). Pass as args:
- Any `transition_suppression.override_text` from `delegates.yaml → sdd-code` for the resolved delegate (prepend this so it is seen first).
- The current batch detail from `plan.md` (if it exists), or the next unchecked task from `tasks.md`.
- The referenced spec context for each task.
- Instruction to follow TDD discipline (see below).

### TDD discipline

For each task, enforce the RED-GREEN-REFACTOR cycle:
1. **RED**: Write a failing test based on the spec's Acceptance Criteria and Behavior.
2. **GREEN**: Write minimal implementation to pass the test.
3. **REFACTOR**: Clean up while keeping tests green.

This applies whether executing via `executing-plans` or directly from `tasks.md`.

### Error recovery

If tests fail unexpectedly or implementation encounters errors:
- **Use the Skill tool** to invoke the debugging delegate (e.g. `systematic-debugging`) to find root cause before attempting fixes.
- Do not apply symptom fixes -- always trace to root cause.

### Transition suppression

Some delegates have built-in auto-transitions that conflict with SDD workflow control. **SDD must suppress these behaviors.**

The `transition_suppression.override_text` from `delegates.yaml → sdd-code` must be prepended in the args passed to the Skill tool call above.

If the delegate attempts either transition, intercept and stop. Inform the user:
> Task execution paused. The delegate tried to auto-advance to branch finishing -- SDD intercepted this. Run `/sdd-review-code` or `/sdd-verify` to continue the SDD workflow.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-code`.
> Use `/sdd-use <profile>` to switch framework stacks.

---

## Post-check

0. **Provenance stamp**: when updating `tasks.md` (marking tasks `[x]`), ensure the frontmatter `generated_by` fields are preserved. Do not overwrite existing provenance — append update tracking:
   - `last_updated_by.framework`: the resolved framework
   - `last_updated_by.skill`: the resolved skill
   - `last_updated_by.sdd_action`: `sdd-code`
   - `last_updated_at`: current ISO 8601 timestamp

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
