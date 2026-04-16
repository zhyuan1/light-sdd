---
name: sdd-review-code
description: Two-phase code review -- spec compliance then code quality
metadata:
  version: "0.1.0"
  sdd_action: review-code
  delegates_to:
    - "requesting-code-review"
  overridable: true
---

# sdd-review-code

Perform a two-phase code review: first check spec compliance (SDD self-logic), then delegate code quality review to Superpowers' `requesting-code-review` skill.

---

## Pre-check

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.

2. **Implementation gate**: `tasks.md` must exist with at least one completed task (`- [x]`).
   - If no completed tasks: "No completed tasks to review. Run `/sdd-code` first." and stop.

3. **Identify changed files**:
   - Use `git diff` against the base branch (or the commit before the change began) to identify all modified/added files.
   - If no diff is available, ask the user which files to review.

4. **Load specs**:
   - For each completed task in `tasks.md`, identify the referenced capability.
   - Load the corresponding `specs/<capability>/spec.md` for comparison.

5. **Delegation**: Resolve delegates per `delegates.yaml → sdd-review-code`,
   following `delegation-protocol.md` (multi-phase independent resolution). Record resolved framework/skill for provenance.

---

## Core Execution

### Phase 1: Spec compliance review (SDD self-logic)

For each completed capability, compare the implementation against the spec:

| Check | What to verify |
|---|---|
| Requirements coverage | Each requirement in the spec has corresponding implementation |
| Interface fidelity | Implementation matches the Interfaces section (function signatures, endpoints, event names) |
| Behavior conformance | Happy path and edge cases from Behavior section are handled |
| Acceptance criteria | Each AC is addressed by the implementation |

Produce a Phase 1 findings list:
- **Missing requirement**: REQ-N from spec `<cap>` has no implementation.
- **Interface mismatch**: spec says `processOrder(id: string)`, implementation has `processOrder(id: number)`.
- **Untested edge case**: spec describes timeout behavior, no handling found.

### Phase 2: Code quality review

**Delegate to**: Superpowers `requesting-code-review`.

Provide to the delegate:
- The list of changed files (or git diff SHAs).
- The relevant specs as context for what the code should accomplish.
- Phase 1 findings as additional review context.

Expect from the delegate:
- Code quality feedback covering: style, patterns, performance, security, error handling, test coverage.

### Override

| Alternative | When to prefer |
|---|---|
| ECC `check` | When Superpowers is not installed |
| Manual review | User wants to review code themselves |

---

## Post-check

0. **Provenance stamp**: set the YAML frontmatter in the generated review file:
   - `generated_by.framework`: Phase 1 `sdd` + Phase 2 `superpowers` (or override framework)
   - `generated_by.skill`: Phase 1 `sdd-review-code` + Phase 2 `requesting-code-review` (or override skill)
   - `sdd_action`: `sdd-review-code`
   - `timestamp`: current ISO 8601 timestamp

1. **Merge findings**:
   Combine Phase 1 (spec compliance) and Phase 2 (code quality) findings into a single review artifact.

2. **Generate review artifact**:
   Create `reviews/code-review-<timestamp>.md` using the review template with:
   - **Review Type**: code-review
   - **Scope**: list of files reviewed, capabilities covered
   - **Findings**: all findings from both phases, categorized by severity
   - **Verdict**:
     - `fail` -- any Critical finding from Phase 1 (spec non-compliance is always critical)
     - `pass-with-notes` -- Phase 1 clean, Phase 2 has warnings or notes
     - `pass` -- both phases clean

3. **Verdict routing**:
   - If `fail`:
     > Code review failed. Spec compliance issues must be fixed before shipping.
     > Fix the issues above, then re-run `/sdd-review-code`.
   - If `pass-with-notes`:
     > Code review passed with notes. Consider addressing the items above.
     > Next: run `/sdd-verify` for final verification.
   - If `pass`:
     > Code review passed. Run `/sdd-verify` for final verification.
