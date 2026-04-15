---
name: sdd-ship
description: Finalize change -- sync specs, archive, and ship
metadata:
  version: "0.1.0"
  sdd_action: ship
  delegates_to:
    - "sync-specs"
    - "archive-change"
    - "finishing-a-development-branch"
  overridable: true
---

# sdd-ship

Finalize an SDD change through a 3-step orchestration: sync specs to canonical location, archive the change directory, and finish the development branch.

---

## Pre-check

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.

2. **Verification gate**:
   - Check `reviews/` for a verification review with `verdict: pass`.
   - If no passing verification exists: "No passing verification found. Run `/sdd-verify` first." and stop.

3. **Uncommitted changes check**:
   - Run `git status` to detect uncommitted work.
   - If dirty working tree: warn the user and ask whether to commit first or abort.

4. **User confirmation**:
   > Ready to ship `<change-name>`. This will:
   > 1. Sync finalized specs to the project spec location.
   > 2. Archive the change directory.
   > 3. Finish the development branch.
   > Proceed? (y/n)

   Wait for explicit confirmation.

5. **Delegation availability check**:
   - For Step 1 & 2: search for the OpenSpec `sync-specs` and `archive-change` skills in the skill search paths (`~/.claude/skills/`, `.claude/skills/`, project-configured paths).
   - For Step 3: search for the Superpowers `finishing-a-development-branch` skill.
   - For each step, if the target skill is not found:
     - `sync-specs` missing: SDD performs a direct file copy from `.sdd/changes/<name>/specs/` to the project spec location.
     - `archive-change` missing: SDD performs a direct directory move to `.sdd/changes/archive/`.
     - `finishing-a-development-branch` missing: check for ECC `check` as fallback, or fall back to manual git operations:
       > Superpowers `finishing-a-development-branch` not found. SDD will present git options (merge/PR/preserve/discard) and execute directly.
   - Inform the user of any fallbacks:
     > Using direct SDD logic for spec sync and archive (OpenSpec not found). Using manual git for branch finishing (Superpowers not found).
   - Record which frameworks and skills are being used for each step -- this feeds into the Provenance stamp in Post-check.

---

## Core Execution

Execute three steps sequentially. If any step fails, stop and report -- do not continue to the next step.

### Step 1: Sync specs

**Delegate to**: OpenSpec `sync-specs`.

- Sync finalized specs from `.sdd/changes/<change-name>/specs/` to the project's canonical spec location (typically `openspec/specs/` or as configured).
- This ensures the project's living spec documentation stays up to date.

### Step 2: Archive change

**Delegate to**: OpenSpec `archive-change`.

- Archive the change directory (move to `.sdd/changes/archive/` or tag as shipped, per OpenSpec convention).
- The change artifacts are preserved for future reference but no longer active.

### Step 3: Finish branch

**Delegate to**: Superpowers `finishing-a-development-branch`.

- Present the user with integration options:
  1. Merge locally to base branch.
  2. Push and create a pull request.
  3. Preserve the branch for later.
  4. Discard the work.
- Execute the chosen option with appropriate cleanup.

### Override

| Alternative | When to prefer |
|---|---|
| ECC `check` + manual git | When Superpowers is not installed |
| Manual archive | When OpenSpec is not installed |

---

## Post-check

1. **Spec sync verification**:
   - Confirm specs exist in the canonical project location.
   - Flag if any spec failed to sync.

2. **Archive verification**:
   - Confirm the change directory has been archived (no longer in `.sdd/changes/` active list, or moved to archive).

3. **Completion report**:
   > `<change-name>` shipped.
   > - Specs synced to <canonical-location>.
   > - Change archived.
   > - Branch: <action taken (merged/PR created/preserved/discarded)>.
