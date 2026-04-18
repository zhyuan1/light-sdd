# Delegation Protocol

Shared algorithm for resolving skill delegates in SDD. All delegating SDD skills reference this protocol instead of inlining the resolution logic.

## Overview

SDD skills delegate core work to external framework skills (Superpowers, OpenSpec, ECC). This protocol defines how to find, select, and fall back between delegates, using `delegates.yaml` as the single source of truth.

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
2. `.claude/skills/` (project-level install)
3. Any project-configured skill paths (from `.claude/settings.json` or MCP configuration)

A skill is "found" if its `SKILL.md` file exists at any search path location.

---

## 2. Single-Delegate Resolution

For actions with a flat `primary` / `fallback` structure in `delegates.yaml`:

```
1. For each entry in `primary` (in order):
   - Search for {framework}/{skill} in the search paths.
   - If found → use it. Stop searching.

2. If no primary found, for each entry in `fallback` (in order):
   - Search for {framework}/{skill} in the search paths.
   - If found → inform the user:
       > {Primary framework} `{primary skill}` not found.
       > Using {fallback framework} `{fallback skill}` as fallback.
   - Use it. Stop searching.

3. If nothing found → enter manual mode:
   - Display the `manual_message` from delegates.yaml.
   - SDD performs the action using templates and context directly.
```

---

## 3. Multi-Skill Partial Availability

When `partial_availability: true` is set (e.g., `sdd-code`), the action uses multiple primary skills that serve different roles:

```
1. Search for ALL entries in `primary`.
2. For each found skill, record it as available.
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
  2. If the phase has its own `primary` / `fallback` → resolve using Single-Delegate Resolution.
  3. If the phase has `inline_fallback` → use that SDD-native logic when the primary is missing.
  4. If the phase has no fallback of its own, use the action-level `fallback` list.

Any phase's resolution is independent: Phase 1 using a fallback does not affect Phase 2's resolution.
```

---

## 5. User Notification Format

When a fallback or manual mode is activated, notify the user with a blockquote:

- **Fallback**: `> {Primary framework} \`{primary skill}\` not found. Using {fallback framework} \`{fallback skill}\` as fallback.`
- **Manual mode**: Display the `manual_message` verbatim from `delegates.yaml`.
- **Partial availability**: `> {framework} \`{skill}\` not found. Proceeding with available skills; {missing capability} will be handled by SDD directly.`

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
