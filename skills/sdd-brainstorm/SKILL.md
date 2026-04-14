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

### Override

| Alternative | When to prefer |
|---|---|
| ECC `think` | When Superpowers is not installed |
| Manual | User wants to brainstorm themselves and just needs the template |

---

## Post-check

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
