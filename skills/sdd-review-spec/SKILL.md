---
name: sdd-review-spec
description: Review specs for completeness, consistency, and testability
metadata:
  version: "0.1.0"
  sdd_action: review-spec
  delegates_to: []
  overridable: false
---

# sdd-review-spec

Review specifications for quality before implementation begins. This is pure SDD logic with subagent dispatch -- no delegation to external skills.

---

## Pre-check

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.

2. **Specs gate**: at least one `specs/<capability>/spec.md` must exist.
   - If no specs found: "No specs to review. Run `/sdd-ff` first." and stop.

3. **Scope resolution**:
   - If the user specified a capability name, review only that spec.
   - Otherwise, review all specs in the change directory.

4. **Load proposal**: read `proposal.md` for cross-referencing capability list.

5. **KB context loading**:
   - Read `.sdd/kb.yaml` if it exists.
   - Filter sources where `scope` includes `sdd-review-spec`.
   - For each matched source:
     - `path` source → read the file directly.
     - `url` source → read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the spec-reviewer subagent as additional context (e.g. architecture docs inform cross-spec consistency checks).
   - If `.sdd/kb.yaml` does not exist: skip silently.
   - Report: "KB loaded: architecture.md" (or "No KB sources for this action.")

---

## Core Execution

Dispatch a spec-reviewer subagent to evaluate each spec against four dimensions:

### 1. Schema compliance

For each spec, validate against `schema.yaml` -> `artifacts.spec.sections`:
- Requirements section exists and contains testable statements (not vague wishes).
- Interfaces section exists and defines concrete API surface.
- Behavior section exists with at least one happy-path scenario.
- Acceptance Criteria section exists with verifiable, concrete criteria.

### 2. Cross-spec consistency

If multiple specs exist:
- Do interfaces referenced between capabilities match? (e.g., if spec A says it calls spec B's `processOrder()`, does spec B define that interface?)
- Are there contradictory requirements across specs?
- Are shared data models consistent?

### 3. Spec-to-proposal traceability

- Every capability listed in `proposal.md` must have a corresponding spec.
- Every spec must correspond to a capability in the proposal.
- Flag orphans in either direction.

### 4. Acceptance criteria quality

For each acceptance criterion, evaluate:
- Is it verifiable by running code (not subjective)?
- Is it specific enough to write a test from?
- Does it cover the edge cases described in the Behavior section?

Flag criteria that are vague (e.g., "system should be fast", "works correctly").

---

## Post-check

0. **Provenance stamp**: set the YAML frontmatter in the generated review file:
   - `generated_by.framework`: `sdd` (self-logic, no external delegation)
   - `generated_by.skill`: `sdd-review-spec`
   - `sdd_action`: `sdd-review-spec`
   - `timestamp`: current ISO 8601 timestamp

1. **Generate review artifact**:
   Create `reviews/spec-review-<timestamp>.md` using the review template with:
   - **Review Type**: spec-review
   - **Scope**: list of specs reviewed
   - **Findings**: categorized as Critical / Warnings / Notes
   - **Verdict**: 
     - `pass` -- all specs meet all four dimensions
     - `pass-with-notes` -- minor issues only (Notes category)
     - `fail` -- any Critical or Warning findings

2. **Verdict routing**:
   - If `fail`: list specific issues with the spec name and section reference.
     > Spec review failed. Fix the issues above and re-run `/sdd-review-spec`.
   - If `pass-with-notes`: list the notes.
     > Specs approved with notes. Consider addressing the items above. Proceed with `/sdd-plan` or `/sdd-code`.
   - If `pass`:
     > All specs passed review. Run `/sdd-plan` to create an execution plan, or `/sdd-code` to start implementing.
