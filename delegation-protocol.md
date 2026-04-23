# Delegation Protocol

Shared algorithm for resolving skill delegates in SDD. All delegating SDD skills reference this protocol instead of inlining the resolution logic.

## Overview

SDD skills delegate core work to external framework skills (Superpowers, OpenSpec, ECC, gstack, ai_native_kit). This protocol defines how to find, select, and fall back between delegates, using `delegates.yaml` as the single source of truth.

---

## Prerequisites: Locate delegates.yaml

**Every SDD skill must run this step first, before any other section of this protocol.**

Search for `delegates.yaml` in the following locations, in order. Stop at the first file found.

1. `.claude/skills/sdd-templates/delegates.yaml` — project-level install
2. `.claude-internal/skills/sdd-templates/delegates.yaml` — project-level private install
3. `~/.claude/skills/sdd-templates/delegates.yaml` — user-level install
4. `~/.claude-internal/skills/sdd-templates/delegates.yaml` — user-level private install

**If found**: load it and proceed to Section 0.

**If not found at any location**: stop immediately and report:
> `delegates.yaml` not found. Is light-sdd installed?
> Checked: `.claude/skills/sdd-templates/`, `.claude-internal/skills/sdd-templates/`, `~/.claude/skills/sdd-templates/`, `~/.claude-internal/skills/sdd-templates/`
> Run `./install.sh` (from the light-sdd repo) to install.

**Do not enter inline/manual mode as a substitute for a missing `delegates.yaml`.**
Inline mode is only valid when `delegates.yaml` is present but no matching delegate skill is found (see Section 2 step 3).

---

## 0. Profile Resolution

Before resolving any delegate skill, determine the active profile:

1. Look for `.sdd/config.yaml` in the project root.
   - If the file exists and contains `active_profile: <name>`, the active profile is `<name>`.
   - Otherwise, the active profile is `default`.

2. If the active profile is `default`, or the `profiles:` key is absent from `delegates.yaml`, there are no overrides — proceed directly to Section 1 with the base configuration.

3. Load the profile's override map from `delegates.yaml → profiles.<profile_name>`.

4. **Merge**: for each SDD action listed in the profile, replace that action's entire base block — `primary`, `fallback`, `manual_message`, `transition_suppression`, and `partial_availability` — with the profile's values.
   - Actions **not** listed in the profile keep their base values unchanged.
   - Merge is at the **action level** (replaces whole blocks), not the key level (does not patch individual keys within a block).

5. Proceed to Section 1 (Search Path Resolution) using the merged configuration.

> **Switching profiles**: run `/sdd-use <profile>` to write `.sdd/config.yaml`.
> Run `/sdd-use` (no argument) to list available profiles and the current active one.

---

## 1. Search Path Resolution

When searching for a delegate skill, check these locations in order:

1. `~/.claude/skills/` (user-level install)
2. `~/.claude-internal/skills/` (user-level private install)
3. `.claude/skills/` (project-level install)
4. `.claude-internal/skills/` (project-level private install)
5. Any project-configured skill paths (from `.claude/settings.json` or MCP configuration)

For each search path, attempt to locate the skill using **two name strategies** in order:

1. **Namespaced path**: `{search-path}/{framework}/{skill}/SKILL.md` — used when skills are organized by framework subdirectory (e.g., `~/.claude/skills/superpowers/brainstorming/SKILL.md`).
2. **Flat path**: `{search-path}/{skill}/SKILL.md` — used when skills are installed in a flat namespace regardless of framework (e.g., `~/.claude-internal/skills/brainstorming/SKILL.md`).

A skill is "found" if its `SKILL.md` exists at **either** path in **any** search location. Stop at the first match.

---

## 2. Single-Delegate Resolution

For actions with a flat `primary` / `fallback` structure in `delegates.yaml`:

```
1. For each entry in `primary` (in order):
   - Search for {framework}/{skill} in the search paths.
   - If found → log one line, then use it. Stop searching.
       > Delegating to {framework} `{skill}`.

2. If no primary found, for each entry in `fallback` (in order):
   - Search for {framework}/{skill} in the search paths.
   - If found → log one line, then use it. Stop searching.
       > {Primary framework} `{primary skill}` not found. Delegating to {fallback framework} `{fallback skill}` (fallback).

3. If nothing found → enter manual mode:
   - Display the `manual_message` from delegates.yaml.
   - SDD performs the action using templates and context directly.
```

---

## 3. Multi-Skill Partial Availability

When `partial_availability: true` is set (e.g., `sdd-code`), the action uses multiple primary skills that serve different roles:

```
1. Search for ALL entries in `primary`.
2. For each found skill, record it as available and log one line:
     > Delegating to {framework} `{skill}`.
3. For each missing skill, warn the user:
     > {framework} `{skill}` not found. This capability will be reduced.
4. If ALL primaries are missing, fall through to `fallback` chain (step 2 above).
5. If at least one primary is found, proceed with the available subset.
```

---

## 4. Multi-Phase Independent Resolution

When the action has a `phases` key (e.g., `sdd-review-code`, `sdd-verify`, `sdd-ship`), each phase resolves independently:

```
For each phase:
  1. If `delegate: self` → SDD handles this phase directly (no external search).
  2. If the phase has its own `primary` / `fallback` → resolve using Single-Delegate Resolution
     (including the one-line log on selection).
  3. If the phase has `inline_fallback` → use that SDD-native logic when the primary is missing.
  4. If the phase has no fallback of its own, use the action-level `fallback` list.

Any phase's resolution is independent: Phase 1 using a fallback does not affect Phase 2's resolution.
```

---

## 5. User Notification Format

- **Primary selected**: `> Delegating to {framework} \`{skill}\`.`
- **Fallback selected**: `> {Primary framework} \`{primary skill}\` not found. Delegating to {fallback framework} \`{fallback skill}\` (fallback).`
- **Manual mode**: Display the `manual_message` verbatim from `delegates.yaml`.
- **Partial availability (missing)**: `> {framework} \`{skill}\` not found. Proceeding with available skills; {missing capability} will be handled by SDD directly.`

---

## 6. Provenance Recording

After resolution, record which framework and skill were actually used. This information:

- Feeds into the **Provenance stamp** in each skill's Post-check section.
- Is written to the artifact's YAML frontmatter as `generated_by.framework` and `generated_by.skill`.
- For multi-phase actions, record each phase's resolved delegate separately.

---

## 7. Transition Suppression

Some delegates have built-in auto-transition behavior that conflicts with SDD's workflow control. When `transition_suppression` is defined in `delegates.yaml`:

1. Read the `override_text` for the resolved delegate skill.
2. Append it to the delegation context when invoking the delegate.
3. If the delegate attempts to transition anyway, intercept and stop.
4. Inform the user which SDD command to run next.

Transition suppression directives are action-specific and stay inline in each SKILL.md's "Core Execution" section. The `delegates.yaml` records the data (which skills to suppress, what override text to use); the SKILL.md describes the behavioral response to suppression violations.

---

## 8. Skill Tool Invocation

**Delegation means calling the Skill tool** — not narrating what the delegate "would do", not performing the work inline, and not entering manual mode while a delegate is available.

### How to invoke a resolved delegate

Once a delegate skill name has been resolved (Section 2, 3, or 4), invoke it using the Skill tool with the resolved skill name as the `skill` parameter:

```
Skill({ skill: "<resolved-skill-name>", args: "<context string>" })
```

- `skill`: the resolved skill name from `delegates.yaml` (e.g. `brainstorming`, `writing-plans`, `executing-plans`, `requesting-code-review`, `openspec-ff-change`, `openspec-verify-change`, `verification-before-completion`, `finishing-a-development-branch`).
- `args`: a context string summarizing the task, relevant file contents, and any SDD OVERRIDE directives from `transition_suppression`.

### What to pass as args

Construct the args string to include:
1. The action goal (e.g. "Brainstorm approaches for: remove-ckv-dependency").
2. Key context already gathered in Pre-check (change name, spec summaries, KB content, template format).
3. Any `transition_suppression.override_text` from `delegates.yaml` for this delegate — prepend it so the delegate sees the SDD OVERRIDE before any other instruction.

### Skill tool is mandatory when a delegate is found

Do **not** skip the Skill tool call and perform the work yourself, even if you believe you could produce the same result. The purpose of delegation is to invoke the specialized skill exactly as configured. If the skill is available, call it.

### Manual mode is the fallback, not the default

Manual mode (performing the work directly using the template) is only entered when:
- All entries in `primary` were searched and not found, AND
- All entries in `fallback` were searched and not found.

If any delegate was found in Section 2 / 3 / 4, call it via the Skill tool. Never silently fall through to manual mode when a delegate is available.
