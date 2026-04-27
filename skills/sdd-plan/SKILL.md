---
name: sdd-plan
description: Create a detailed execution plan for the current batch
metadata:
  version: "0.1.0"
  sdd_action: plan
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-plan

Create a detailed, actionable execution plan for the next batch of tasks. Delegates to the skill configured in `delegates.yaml`.

---

## Pre-check

0. **Prerequisites** — locate the `sdd-templates` directory:
   Search the following paths in order, stopping at the first directory that contains `delegates.yaml`:
   1. `.{config_dir}/skills/sdd-templates/` — project-level install
   2. `.{config_dir}-internal/skills/sdd-templates/` — project-level private install
   3. `~/.{config_dir}/skills/sdd-templates/` — user-level install
   4. `~/.{config_dir}-internal/skills/sdd-templates/` — user-level private install

   Known `{config_dir}` values: `codebuddy`, `claude`, `claude-internal`. Check all at each level.

   Once found, this directory is `<sdd-templates-dir>`. It contains `delegates.yaml`, `delegation-protocol.md`, and all artifact templates (`brainstorm.md`, `proposal.md`, etc.).
   If not found: stop immediately and show the user this message (do not attempt to install or continue):
   > `delegates.yaml` not found. Is light-sdd installed?
   > Run `./install.sh` from the light-sdd repo to install, then retry.

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

6. **KB context loading**:
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-plan`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-plan`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context.
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: roadmap.md [global]" (or "No KB sources for this action.")

7. **Delegation**: Resolve delegates per `delegates.yaml → sdd-plan`,
   following `delegation-protocol.md`. Record resolved framework/skill for provenance.

---

## Core Execution

**Use the Skill tool** to invoke the delegate resolved in Pre-check step 7. This is a mandatory tool call — do not generate the plan inline.

```
Skill({ skill: "<resolved-skill-name>", args: "<context>" })
```

Pass as args:
- Any `transition_suppression.override_text` from `delegates.yaml → sdd-plan` for the resolved delegate (prepend this so it is seen first).
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

### Transition suppression

Some delegates have built-in auto-transition logic that presents an execution handoff after plan generation. **SDD must suppress this behavior.**

The `transition_suppression.override_text` from `delegates.yaml → sdd-plan` must be prepended in the args passed to the Skill tool call above.

**SDD OVERRIDE**: Do NOT invoke `subagent-driven-development`, `executing-plans`, or any other skill after plan generation. Do NOT present an execution handoff prompt. Your scope is limited to producing `plan.md`. Return control to SDD when the plan document is finalized. SDD controls the workflow -- the next step is `/sdd-code`, not an execution skill.

If the delegate presents an execution choice anyway, intercept and stop. Inform the user:
> Plan complete. The delegate tried to auto-advance to execution -- SDD intercepted this. Run `/sdd-code` to continue the SDD workflow.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-plan`.
> Use `/sdd-use <profile>` to switch framework stacks.

---

## Post-check

0. **Provenance stamp**: update the YAML frontmatter in `plan.md` with the
   framework and skill resolved during Pre-check delegation:
   - `generated_by.framework`: the resolved framework
   - `generated_by.skill`: the resolved skill
   - `sdd_action`: `sdd-plan`
   - `timestamp`: current ISO 8601 timestamp

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
