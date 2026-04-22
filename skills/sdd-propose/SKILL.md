---
name: sdd-propose
description: Create or continue a change proposal via OpenSpec
metadata:
  version: "0.1.0"
  sdd_action: propose
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-propose

Create a new SDD change or continue an existing proposal. Delegates the core proposal generation to the skill configured in `delegates.yaml`.

---

## Pre-check

1. **Resolve change name**:
   - If the user supplied `<change-name>`, use it.
   - Otherwise, ask the user for a short slug (e.g. `user-auth`, `fix-payment-timeout`).

2. **Directory setup**:
   - If `.sdd/changes/<change-name>/` does not exist, create it.
   - If `proposal.md` already exists in the directory, this is a "continue" case -- inform the user and proceed to update it.

3. **Template seeding**:
   - If `proposal.md` does not exist, copy `templates/proposal.md` into the change directory.
   - Create `specs/` subdirectory if it does not exist.

4. **Brainstorm check**:
   - If `brainstorm.md` exists in the change directory, read it for context.
   - If it does not exist, that is fine -- brainstorming is optional.

5. **KB context loading**:
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-propose`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-propose`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context.
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: architecture.md [global], domain-model.md [project]" (or "No KB sources for this action.")

6. **Delegation**: Resolve delegates per `delegates.yaml → sdd-propose`,
   following `delegation-protocol.md`. Record resolved framework/skill for provenance.

---

## Core Execution

**Use the Skill tool** to invoke the delegate resolved in Pre-check step 6. This is a mandatory tool call — do not perform the proposal work inline.

```
Skill({ skill: "<resolved-skill-name>", args: "<context>" })
```

Pass as args:
- The change name.
- Contents of `brainstorm.md` (if it exists) as prior context.
- The user's feature description or problem statement.
- The `proposal.md` template as the target format.

Expect from the delegate:
- A populated `proposal.md` with all required sections filled:
  - **Motivation**: clear problem statement.
  - **Approach**: chosen technical direction.
  - **Capabilities**: at least one capability listed with description.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-propose`.
> Use `/sdd-use <profile>` to switch framework stacks.

---

## Post-check

0. **Provenance stamp**: update the YAML frontmatter in `proposal.md` with the
   framework and skill resolved during Pre-check delegation:
   - `generated_by.framework`: the resolved framework
   - `generated_by.skill`: the resolved skill
   - `sdd_action`: `sdd-propose`
   - `timestamp`: current ISO 8601 timestamp

1. **Required section validation**:
   - Verify `proposal.md` contains non-empty Motivation, Approach, and Capabilities sections.
   - If any required section is missing or empty, report the gap and re-invoke the delegate with specific guidance. Max 2 retries.

2. **Decision traceability** (only if `brainstorm.md` exists):
   - Verify the Approach section references or aligns with the Decision from `brainstorm.md`.
   - If there is no traceable connection, warn: "Proposal approach does not trace back to brainstorm decision. Intentional?"

3. **Capability directory creation**:
   - Parse the Capabilities list from `proposal.md`.
   - For each capability slug, create `specs/<capability>/` subdirectory if it does not exist.

4. **Next-step guidance**:
   > Proposal created for `<change-name>` with N capabilities.
   > Next: run `/sdd-ff` to generate specs and tasks, or manually author specs in `specs/`.
