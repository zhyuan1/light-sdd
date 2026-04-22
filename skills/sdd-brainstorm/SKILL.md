---
name: sdd-brainstorm
description: Structured brainstorming for a new change
metadata:
  version: "0.1.0"
  sdd_action: brainstorm
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-brainstorm

Facilitate structured, divergent exploration before committing to an approach. Delegates to the skill configured in `delegates.yaml`.

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
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-brainstorm`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-brainstorm`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context.
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: architecture.md [global], domain-model.md [project]" (or "No KB sources for this action.")

6. **Delegation**: Resolve delegates per `delegates.yaml → sdd-brainstorm`,
   following `delegation-protocol.md`. Record resolved framework/skill for provenance.

---

## Core Execution

**Use the Skill tool** to invoke the delegate resolved in Pre-check step 6. This is a mandatory tool call — do not perform the brainstorming work inline.

```
Skill({ skill: "<resolved-skill-name>", args: "<context>" })
```

Pass as args:
- Any `transition_suppression.override_text` from `delegates.yaml → sdd-brainstorm` for the resolved delegate (prepend this so it is seen first).
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

Some delegates have built-in auto-transition logic that advances to a planning skill after completion. **SDD must suppress this behavior.**

The `transition_suppression.override_text` from `delegates.yaml → sdd-brainstorm` must be prepended in the args passed to the Skill tool call above.

If the delegate attempts to transition anyway, intercept and stop. Inform the user:
> Brainstorm complete. The delegate tried to auto-advance to planning -- SDD intercepted this. Run `/sdd-propose` to continue the SDD workflow.

---

## Post-check

0. **Provenance stamp**: update the YAML frontmatter in `brainstorm.md` with the
   framework and skill resolved during Pre-check delegation (step 5):
   - `generated_by.framework`: the resolved framework
   - `generated_by.skill`: the resolved skill
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
