---
name: sdd-verify
description: Verify implementation against all specs with coverage stats
metadata:
  version: "0.1.0"
  sdd_action: verify
  delegates_to:
    - "verify-change"
    - "verification-before-completion"
  overridable: true
---

# sdd-verify

Verify the implementation satisfies all spec acceptance criteria. Delegates to OpenSpec `verify-change` and Superpowers `verification-before-completion`, then produces coverage statistics.

---

## Pre-check

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

4. **Delegation**: Resolve delegates per `delegates.yaml → sdd-verify`,
   following `delegation-protocol.md` (multi-phase independent resolution). Record resolved frameworks/skills for provenance.

---

## Core Execution

### Step 1: Spec verification

**Delegate to**: OpenSpec `verify-change`.

Provide to the delegate:
- All specs from `specs/`.
- The implementation file mapping (which files implement which capability).
- The collected acceptance criteria checklist.

Expect from the delegate:
- Per-spec verification results: which acceptance criteria pass, which fail, which are untestable.

### Step 2: Evidence verification

**Delegate to**: Superpowers `verification-before-completion`.

Provide to the delegate:
- The verification results from Step 1.
- Instruction: for every "pass" claim, verify there is concrete evidence (a passing test, a successful command output, observable behavior). No "should work" or "probably fine" -- evidence only.

Expect from the delegate:
- An evidence-backed assessment: each AC is either verified-with-evidence, failed, or unverifiable.

### Override

| Alternative | When to prefer |
|---|---|
| ECC `check` / `verification-loop` | When OpenSpec or Superpowers is not installed |
| Manual verification | User wants to verify manually |

---

## Post-check

0. **Provenance stamp**: set the YAML frontmatter in the generated verification review:
   - `generated_by.framework`: `openspec` + `superpowers` (or override frameworks)
   - `generated_by.skill`: `verify-change` + `verification-before-completion` (or override skills)
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
