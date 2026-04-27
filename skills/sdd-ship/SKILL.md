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

Finalize an SDD change through a 3-step orchestration: sync specs to canonical location, archive the change directory, and finish the development branch. Delegates to the skills configured in `delegates.yaml`.

---

## Pre-check

0. **Prerequisites** — locate the `sdd-templates` directory:
   Search the following paths in order, stopping at the first directory that contains `delegates.yaml`:
   1. `.{config_dir}/skills/sdd-templates/` — project-level install
   2. `.{config_dir}-internal/skills/sdd-templates/` — project-level private install
   3. `~/.{config_dir}/skills/sdd-templates/` — user-level install
   4. `~/.{config_dir}-internal/skills/sdd-templates/` — user-level private install

   Known `{config_dir}` values: `codebuddy`, `claude`, `claude-internal`. Check all at each level.

   Once found, this directory is `<sdd-templates-dir>`. It contains `delegates.yaml` and `delegation-protocol.md`.
   If not found: stop immediately and show the user this message (do not attempt to install or continue):
   > `delegates.yaml` not found. Is light-sdd installed?
   > Run `./install.sh` from the light-sdd repo to install, then retry.

1. **Locate change directory**: `.sdd/changes/<change-name>/` must exist.
   - **OpenSpec bridge**: if `openspec/changes` does not exist and the resolved delegate is an OpenSpec skill, create the symlink: `openspec/changes` -> `.sdd/changes` (create the `openspec/` parent directory first if needed).

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

**Use the Skill tool** to invoke the sync delegate resolved in Pre-check step 5. This is a mandatory tool call.

```
Skill({ skill: "<resolved-sync-skill-name>", args: "<context>" })
```

Pass as args:
- The change name and the source specs path: `.sdd/changes/<change-name>/specs/`.
- Instruction: sync finalized specs to the project's canonical spec location.

### Step 2: Archive change

**Use the Skill tool** to invoke the archive delegate resolved in Pre-check step 5. This is a mandatory tool call.

```
Skill({ skill: "<resolved-archive-skill-name>", args: "<context>" })
```

Pass as args:
- The change name and the change directory path.
- Instruction: archive the change directory (move to `.sdd/changes/archive/` or tag as shipped, per the delegate's convention). The change artifacts are preserved for future reference but no longer active.

### Step 3: Finish branch

**Use the Skill tool** to invoke the finish delegate resolved in Pre-check step 5. This is a mandatory tool call.

```
Skill({ skill: "<resolved-finish-skill-name>", args: "<context>" })
```

Pass as args:
- The change name and current branch name.
- Instruction: present the user with integration options and execute the chosen option:
  1. Merge locally to base branch.
  2. Push and create a pull request.
  3. Preserve the branch for later.
  4. Discard the work.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-ship`.
> Use `/sdd-use <profile>` to switch framework stacks.

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
