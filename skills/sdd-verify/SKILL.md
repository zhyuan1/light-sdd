---
name: sdd-verify
description: Verify implementation against all specs with coverage stats
metadata:
  version: "0.1.0"
  sdd_action: verify
  delegates_to: delegates.yaml
  overridable: true
---

# sdd-verify

Verify the implementation satisfies all spec acceptance criteria. Delegates to the skills configured in `delegates.yaml`, then produces coverage statistics.

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

2. **Tasks progress check**:
   - Read `tasks.md` and count completion ratio.
   - If all tasks complete: proceed normally.
   - If some tasks incomplete: warn "N tasks still incomplete. Verification may be partial. Continue anyway? (y/n)". Proceed only with user confirmation.

3. **Collect acceptance criteria**:
   - Read every `specs/<capability>/spec.md`.
   - Extract all Acceptance Criteria into a flat checklist:
     ```
     [ ] cap:auth AC-1: User can log in with email/password
     [ ] cap:auth AC-2: Invalid credentials return 401
     [ ] cap:storage AC-1: Files upload successfully
     ...
     ```
   - Report total AC count to the user.

4. **KB context loading**:
   - Load global KB: read `~/.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-verify`.
   - Load project KB: read `.sdd/kb.yaml` if it exists; filter sources where `scope` includes `sdd-verify`.
   - Merge: concatenate global + project sources. Deduplicate by `path`/`url` (project entry wins if identical).
   - For each merged source:
     - `path` source → read the file directly.
     - `url` source → global sources read from `~/.sdd/kb-cache/<id>.md`; project sources read from `.sdd/kb-cache/<id>.md`; if cache missing, warn and skip; if `fetched_at` is older than `stale_after`, warn but continue.
   - Pass loaded KB content to the delegate as additional context (e.g. security guidelines inform the evidence verification step).
   - If neither kb.yaml exists: skip silently.
   - Report: "KB loaded: auth-patterns.md [global], test-guidelines.md [project]" (or "No KB sources for this action.")

5. **Delegation**: Resolve delegates per `delegates.yaml → sdd-verify`,
   following `delegation-protocol.md` (multi-phase independent resolution). Record resolved frameworks/skills for provenance.

---

## Core Execution

### Step 1: Spec verification

**Use the Skill tool** to invoke the Step 1 delegate resolved in Pre-check step 5. This is a mandatory tool call — do not perform the spec verification inline.

```
Skill({ skill: "<resolved-step1-skill-name>", args: "<context>" })
```

Pass as args:
- All specs from `specs/`.
- The implementation file mapping (which files implement which capability).
- The collected acceptance criteria checklist.

Expect from the delegate:
- Per-spec verification results: which acceptance criteria pass, which fail, which are untestable.

### Step 2: Evidence verification

**Use the Skill tool** to invoke the Step 2 delegate resolved in Pre-check step 5. This is a mandatory tool call — do not perform the evidence check inline.

```
Skill({ skill: "<resolved-step2-skill-name>", args: "<context>" })
```

Pass as args:
- The verification results from Step 1.
- Instruction: for every "pass" claim, verify there is concrete evidence (a passing test, a successful command output, observable behavior). No "should work" or "probably fine" -- evidence only.

Expect from the delegate:
- An evidence-backed assessment: each AC is either verified-with-evidence, failed, or unverifiable.

> Fallback chain and alternative delegates are defined in `delegates.yaml → sdd-verify`.
> Use `/sdd-use <profile>` to switch framework stacks.

---

## Post-check

0. **Provenance stamp**: set the YAML frontmatter in the generated verification review:
   - `generated_by.framework`: the resolved frameworks for each step
   - `generated_by.skill`: the resolved skills for each step
   - `sdd_action`: `sdd-verify`
   - `timestamp`: current ISO 8601 timestamp

1. **Scenario coverage statistics** (SDD self-logic):
   For each capability, calculate:
   ```
   Coverage = verified AC / total AC
   ```

   Produce a coverage table:
   ```
   Capability   Verified  Total  Coverage
   auth         3         4      75%
   storage      2         2      100%
   ----------------------------------------
   Overall      5         6      83%
   ```

2. **Generate review artifact**:
   Create `reviews/verification-<timestamp>.md` using the review template with:
   - **Review Type**: verification
   - **Scope**: all capabilities verified
   - **Findings**: list each unverified or failed AC with reason
   - **Verdict**:
     - `pass` -- 100% coverage, all AC verified with evidence
     - `pass-with-notes` -- 100% coverage but some AC had weak evidence
     - `fail` -- any AC failed or coverage < 100%

3. **Verdict routing**:
   - If `fail`:
     > Verification incomplete. These acceptance criteria are unverified:
     > - cap:auth AC-2: Invalid credentials return 401
     > Fix the gaps and re-run `/sdd-verify`.
   - If `pass-with-notes`:
     > Verification passed with notes. Consider strengthening evidence for the flagged items.
     > Next: run `/sdd-ship` to finalize.
   - If `pass`:
     > All specs verified with evidence. Run `/sdd-ship` to finalize the change.
