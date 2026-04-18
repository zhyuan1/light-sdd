---
name: sdd-use
description: Switch the active delegate profile for this project
metadata:
  version: "0.1.0"
  sdd_action: use
  delegates_to: []
  overridable: false
---

# sdd-use

Switch which delegate profile SDD uses when resolving framework skills. Profiles are
defined in `delegates.yaml → profiles:`. The active profile is persisted to
`.sdd/config.yaml` and read by the delegation protocol before every skill invocation.

Usage:
```
/sdd-use              -- list available profiles and current active
/sdd-use <profile>    -- activate the named profile
/sdd-use default      -- reset to default (superpowers / openspec / ecc)
```

---

## Pre-check

1. **Parse arguments**: extract `<profile>` from `$ARGUMENTS`.
   - If no argument supplied: jump to Core Execution — List Mode.

2. **Locate `delegates.yaml`**: search using the path priority from delegation-protocol.md §1:
   - `.claude/skills/sdd-templates/delegates.yaml` (project-level, higher priority)
   - `~/.claude/skills/sdd-templates/delegates.yaml` (user-level)
   - Stop at the first file found. If neither exists, report:
     > `delegates.yaml` not found. Is light-sdd installed? Run `./install.sh` to install.
   - And stop.

3. **Validate the requested profile**:
   - Accept `"default"` unconditionally (no lookup needed).
   - For any other name: verify `profiles.<name>` exists in the located `delegates.yaml`.
   - If the key is missing, collect all top-level keys under `profiles:` and display:
     > Profile `<name>` not found. Available profiles: default, <list>.
   - And stop.

---

## Core Execution

### Set Mode (a profile name was supplied)

**Step 1 — Write config**:
- Create `.sdd/` in the project root if it does not exist.
- Write (or overwrite) `.sdd/config.yaml`:
  ```yaml
  active_profile: <profile-name>
  ```

**Step 2 — Confirm and summarise**:
Display the confirmation line:
> Active profile set to: `<profile-name>`

Then show a merged delegate summary table. For each SDD action, look up the profile's
primary skill(s) (if the action is overridden) or the base primary skill(s) (if not).
Format one row per action:

| SDD Action        | Framework  | Primary Skill(s)                      |
|-------------------|------------|---------------------------------------|
| sdd-brainstorm    | gstack     | office-hours                          |
| sdd-propose       | gstack     | plan-ceo-review                       |
| sdd-ff            | gstack     | plan-design-review                    |
| sdd-review-spec   | gstack     | plan-design-review                    |
| sdd-plan          | gstack     | autoplan                              |
| sdd-code          | gstack     | design-html, qa                       |
| sdd-review-code   | gstack     | review, cso (phase 2)                 |
| sdd-verify        | gstack     | qa (step 1), benchmark (step 2)       |
| sdd-ship          | gstack     | ship → land-and-deploy (finish phase) |

(For `default` profile, show the existing superpowers / openspec mappings.)

**Step 3 — Fallback reminder** (if profile is not `default`):
> If any gstack skill is not installed, the delegation protocol will fall back
> automatically: gstack → superpowers/openspec → ecc → manual.

---

### List Mode (no argument supplied)

1. Read `.sdd/config.yaml` if it exists; extract `active_profile`. If the file is absent or
   the key is missing, treat the active profile as `default`.

2. Locate `delegates.yaml` (same search path as Pre-check step 2). Extract all keys under
   the `profiles:` top-level key. Combine with `default` (always available).

3. Display:
   > Active profile: `<current>`
   > Available profiles: default, <list from delegates.yaml>

4. If the active profile is not `default`, show one-line framework summary:
   > `<profile>` routes most actions through `<framework>`, with fallback to superpowers/openspec/ecc.

---

## Post-check

1. **Config verification** (Set Mode only): re-read `.sdd/config.yaml` and confirm it
   contains `active_profile: <name>`. If the write failed, report the error and stop.

2. **No artifact**: this action produces no SDD artifact. No provenance stamp is written.

3. **Next-step guidance**:
   > Profile `<name>` activated. All subsequent SDD actions will delegate via this profile.
   > Run `/sdd-status` to review your current change state, or run any `/sdd-*` command to continue.
