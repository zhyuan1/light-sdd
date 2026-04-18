---
name: sdd-brainstorm
description: Structured brainstorming for a new change
metadata:
  version: "0.1.0"
  sdd_action: brainstorm
  delegates_to:
    - "brainstorming"
  overridable: true
---

# sdd-brainstorm

Facilitate structured, divergent exploration before committing to an approach. Delegates to Superpowers' `brainstorming` skill for Socratic-style idea generation.

---

## Pre-check

1. **Resolve change name**:
   - If the user supplied `<change-name>`, use it.
   - Otherwise, ask the user for a short slug.

2. **Directory setup** (SDD self-logic):
   - Create `.sdd/changes/<change-name>/` if it does not exist.

3. **Template seeding**:
   - If `brainstorm.md` does not exist in the change directory, copy `templates/brainstorm.md` into it.
   - If `brainstorm.md` already exists, ask the user: "Brainstorm already exists. Overwrite or continue editing?"

4. **Context gathering**:
   - Read existing project context (README, architecture docs) if available.
   - Read the user's problem description.

5. **KB context loading**:
   - Read `.sdd/kb.yaml` if it exists.
   - Filter sources where `scope` includes `sdd-brainstorm`.
   - For each matched source:
     - `path` source → read the file directly.
     - `url` source → read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context.
   - If `.sdd/kb.yaml` does not exist: skip silently.
   - Report: "KB loaded: architecture.md, domain-model.md" (or "No KB sources for this action.")

6. **Delegation**: Resolve delegates per `delegates.yaml → sdd-brainstorm`,
   following `delegation-protocol.md`. Record resolved framework/skill for provenance.

---

## Core Execution

**Default delegation**: invoke Superpowers `brainstorming`.

Provide to the delegate:
- The user's problem description or feature request.
- Existing project context (architecture, tech stack, constraints).
- The `brainstorm.md` template as the target output format.
- Instruction: generate at least 3 distinct approaches through Socratic exploration, then converge on a recommendation.

Expect from the delegate:
- A populated `brainstorm.md` with:
  - Clear problem statement.
  - At least 3 raw ideas with trade-off analysis.
  - A decision section recommending which idea(s) to pursue.

### Transition suppression

Superpowers `brainstorming` has built-in auto-transition logic: after the user approves the spec, it automatically invokes `writing-plans`. **SDD must suppress this behavior.**

When invoking `brainstorming`, append this constraint to the delegation context:

> **SDD OVERRIDE**: Do NOT invoke `writing-plans` or any other skill after brainstorming completes. Your scope is limited to producing `brainstorm.md`. Return control to SDD when the brainstorm document is finalized. SDD controls the workflow -- the next step is `/sdd-propose`, not `writing-plans`.

If the delegate attempts to transition anyway, intercept and stop. Inform the user:
> Brainstorm complete. The delegate tried to auto-advance to planning -- SDD intercepted this. Run `/sdd-propose` to continue the SDD workflow.

### Skill override

| Alternative | When to prefer |
|---|---|
| ECC `think` | When Superpowers is not installed |
| Manual | User wants to brainstorm themselves and just needs the template |

---

## Post-check

0. **Provenance stamp**: update the YAML frontmatter in `brainstorm.md` with the
   framework and skill resolved during Pre-check delegation (step 5):
   - `generated_by.framework`: the resolved framework (e.g. `superpowers`, `gstack`, `ecc`, or `sdd` for manual)
   - `generated_by.skill`: the resolved skill (e.g. `brainstorming`, `office-hours`, `think`)
   - `sdd_action`: `sdd-brainstorm`
   - `timestamp`: current ISO 8601 timestamp

1. **Required section validation**:
   - Verify `brainstorm.md` contains non-empty: Problem Statement, Raw Ideas (>= 3 items), Decision.
   - If any required section is missing or empty, report the gap and re-invoke the delegate.

2. **Review loop** (SDD self-logic):
   Dispatch a brainstorm-reviewer subagent to evaluate:
   - Are the ideas genuinely distinct, not variations of the same approach?
   - Does the decision logically follow from the analysis?
   - Are there obvious ideas missing?

   Present the review to the user. If the user requests changes, re-invoke the delegate with the feedback. **Max 3 review rounds** -- after that, accept the current state and move on.

3. **Next-step guidance**:
   > Brainstorm complete for `<change-name>`.
   > Next: run `/sdd-propose` to formalize into a change proposal.
