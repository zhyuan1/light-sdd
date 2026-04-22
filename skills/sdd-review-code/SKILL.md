---
name: sdd-review-code
description: Two-phase code review -- spec compliance then code quality
metadata:
  version: "0.1.0"
  sdd_action: review-code
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-review-code

Perform a two-phase code review: first check spec compliance (SDD self-logic), then delegate code quality review to the skill configured in `delegates.yaml`.

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

5. **KB context loading**:
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-review-code`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-review-code`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context (e.g. coding standards and security guidelines enrich Phase 2 review).
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: coding-standards.md [global], auth-patterns.md [project]" (or "No KB sources for this action.")

6. **Delegation**: Resolve delegates per `delegates.yaml → sdd-review-code`,
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

Invoke the Phase 2 delegate resolved by `delegates.yaml → sdd-review-code → phases.phase2` following `delegation-protocol.md`.

Provide to the delegate:
- The list of changed files (or git diff SHAs).
- The relevant specs as context for what the code should accomplish.
- Phase 1 findings as additional review context.

Expect from the delegate:
- Code quality feedback covering: style, patterns, performance, security, error handling, test coverage.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-review-code`.
> Use `/sdd-use <profile>` to switch framework stacks.

---

## Post-check

0. **Provenance stamp**: set the YAML frontmatter in the generated review file:
   - `generated_by.framework`: Phase 1 `sdd` + Phase 2 the resolved framework (e.g. `superpowers`, `gstack`, or absent if skipped)
   - `generated_by.skill`: Phase 1 `sdd-review-code` + Phase 2 the resolved skill (e.g. `requesting-code-review`, `review`)
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
