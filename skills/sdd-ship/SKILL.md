---
name: sdd-ship
description: Finalize change -- sync specs, archive, and ship
metadata:
  version: "0.1.0"
  sdd_action: ship
  delegates_to: delegates.yaml
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

5. **Delegation**: Resolve delegates per `delegates.yaml → sdd-ship`,
   following `delegation-protocol.md` (multi-phase independent resolution). Record resolved frameworks/skills for provenance.

---

## Core Execution

Execute three steps sequentially. If any step fails, stop and report -- do not continue to the next step.

### Step 1: Sync specs

**Delegate to**: OpenSpec `openspec-sync-specs`.

- Sync finalized specs from `.sdd/changes/<change-name>/specs/` to the project's canonical spec location (typically `openspec/specs/` or as configured).
- This ensures the project's living spec documentation stays up to date.

### Step 2: Archive change

**Delegate to**: OpenSpec `openspec-archive-change`.

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
