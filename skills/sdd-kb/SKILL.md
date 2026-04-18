---
name: sdd-kb
description: Manage the project knowledge base registry for SDD context injection
metadata:
  version: "0.1.0"
  sdd_action: kb
  delegates_to: []
  overridable: false
---

# sdd-kb

Manage the knowledge base registry that injects project-specific or organisation-wide
context — architecture docs, coding standards, domain models, security guidelines —
into SDD skills at the right workflow stage.

Two registry layers:
- **Global** (`~/.sdd/kb.yaml`): set once, applies to every project.
- **Project** (`.sdd/kb.yaml`): per-project overrides and additions.

Usage:
```
/sdd-kb init [--global]            -- create empty kb.yaml scaffold
/sdd-kb add [--global] <path-or-url>  -- register a local file, directory, or URL
/sdd-kb update [--global] [id]     -- re-fetch and refresh cached URL sources
/sdd-kb status [--global|--all]    -- show which sources each action will load
```

---

## Pre-check

1. **Parse sub-command and flags**: extract the first word of `$ARGUMENTS` as the sub-command, and check for `--global` flag anywhere in the remaining arguments.
   Valid sub-commands: `init`, `add`, `update`, `status`.
   - If sub-command is missing or unrecognised, display the usage block above and stop.

2. **Resolve target registry**:
   - With `--global`: target is `~/.sdd/kb.yaml`; cache dir is `~/.sdd/kb-cache/`.
   - Without `--global`: target is `.sdd/kb.yaml`; cache dir is `.sdd/kb-cache/`.
   - For `status --all`: load both registries.

3. **Locate project root** (only for project-level operations, i.e. without `--global`): find the directory containing `.sdd/`. If not found, report:
   > No `.sdd/` directory found. Run `/sdd-propose` first to initialise an SDD change, then `/sdd-kb init`.
   And stop.

4. **For `add` and `update`**: verify the target `kb.yaml` exists.
   - If missing for `add`: auto-run the `init` flow first (at the same level), then continue with `add`.
   - If missing for `update`: report "No kb.yaml found. Run `/sdd-kb init [--global]` first." and stop.

---

## Core Execution

---

### Sub-command: `init`

**Purpose**: create an empty `kb.yaml` scaffold at the target level (global or project).

**Step 1 — Existence check**:
- If the target `kb.yaml` already exists, display:
  > `kb.yaml` already exists at `<target-path>`. Use `/sdd-kb add [--global]` to register sources, or edit it directly.
- Stop without overwriting.

**Step 2 — Write scaffold**:
Create the target `kb.yaml` (either `~/.sdd/kb.yaml` for `--global` or `.sdd/kb.yaml` for project) with:

```yaml
# .sdd/kb.yaml -- Knowledge base registry for SDD context injection
#
# Each source declares a knowledge document and which SDD actions should
# load it as context. Use /sdd-kb add <path-or-url> to register sources.
#
# `scope` is required for every source entry (must be a non-empty list).
# scope values (use one or more):
#   sdd-brainstorm   sdd-propose     sdd-ff        sdd-plan
#   sdd-code         sdd-review-spec sdd-review-code
#   sdd-verify       sdd-ship
#
# stale_after (URL sources only): duration before /sdd-kb status warns of
# outdated cache. Format: Nd (days). Default: 7d.

sources: []
```

**Step 3 — Confirm**:
> `kb.yaml` created at `<target-path>`.
> Next: run `/sdd-kb add [--global] <path-or-url>` to register your first knowledge source.

---

### Sub-command: `add`

**Purpose**: register one or more knowledge sources (file, directory, or URL),
infer scope automatically, let the engineer confirm before writing.

**Input**: the path or URL following `add [--global]` in `$ARGUMENTS`. The `--global` flag writes to `~/.sdd/kb.yaml`; omitting it writes to `.sdd/kb.yaml`.

#### Step 1 — Classify input

| Input type | Detection |
|---|---|
| Local file | path exists and is a file |
| Local directory | path exists and is a directory |
| URL | starts with `http://` or `https://` |

If input is missing, display: "Usage: `/sdd-kb add <path-or-url>`" and stop.
If a local path does not exist, report: "Path not found: `<path>`." and stop.

#### Step 2 — Collect documents

- **Local file**: use the single file.
- **Local directory**: walk recursively, collect all `.md` and `.mdx` files.
  Report total found: "Found N documents under `<dir>`."
- **URL**:
  - Fetch the URL content.
  - Inspect returned content type and body:
    - If the page contains multiple document links (directory index / nav page): follow each link and collect individual `.md`-equivalent documents.
    - If the page is a single document: use it directly.
  - Report total found: "Found N documents at `<url>`."

If no documents are found, report and stop.

#### Step 3 — Infer scope per document

For each collected document, read:
- File name (without extension)
- First `# Heading` found in the content
- First 200 characters of body text

Apply keyword mapping to infer scope:

| Keywords in name/heading/body | Inferred scope |
|---|---|
| architecture, system, component, design, overview | sdd-brainstorm, sdd-propose, sdd-ff, sdd-review-spec |
| coding, standard, convention, style, guideline | sdd-code, sdd-review-code, sdd-ff |
| domain, model, entity, business, glossary | sdd-brainstorm, sdd-propose, sdd-ff |
| security, auth, permission, owasp, vulnerability | sdd-review-code, sdd-verify |
| api, interface, endpoint, contract, sdk | sdd-code, sdd-review-code |
| test, qa, quality, coverage, acceptance | sdd-verify, sdd-review-code |
| plan, task, roadmap, sprint | sdd-plan, sdd-ff |

- A document may match multiple rows — union all matched scope values.
- If no keywords match, set scope to `[NEEDS_REVIEW]`.

#### Step 4 — Present inference table for confirmation

Display a table of all collected documents and their inferred scopes:

```
Found 4 documents under ~/company-kb/backend/

  File                    Inferred scope
  ─────────────────────────────────────────────────────────────────────────
  architecture.md         sdd-brainstorm, sdd-propose, sdd-ff, sdd-review-spec
  coding-standards.md     sdd-code, sdd-review-code, sdd-ff
  auth-patterns.md        sdd-review-code, sdd-verify
  onboarding.md           [NEEDS_REVIEW]
  ─────────────────────────────────────────────────────────────────────────

Adjust any scope before confirming, then say "confirm" to write to kb.yaml.
For [NEEDS_REVIEW] items, provide the correct scope or say "skip" to exclude.
```

Wait for the engineer's confirmation or corrections before proceeding to Step 5.

#### Step 5 — Write to `kb.yaml`

For each confirmed document, append a source entry. Derive a unique `id` from
the file name (lowercase, hyphens for spaces, no extension).

For **local file/directory** sources:
```yaml
  - id: architecture
    path: docs/architecture.md
    scope: [sdd-brainstorm, sdd-propose, sdd-ff, sdd-review-spec]
```

For **URL** sources:
```yaml
  - id: domain-guidelines
    url: https://company.com/domain-guidelines.md
    cache: <cache-dir>/domain-guidelines.md
    fetched_at: <ISO-8601-timestamp>
    stale_after: 7d
    scope: [sdd-brainstorm, sdd-propose]
```

- For URL sources: create the cache dir (`~/.sdd/kb-cache/` for global, `.sdd/kb-cache/` for project) if it does not exist, write fetched content to `<cache-dir>/<id>.md`.
- Do not overwrite existing entries with the same `id`. If a conflict is found:
  > Source `<id>` already exists. Use `/sdd-kb update [--global] <id>` to refresh it, or edit `kb.yaml` directly.

**Step 6 — Confirm**:
Report each written entry:
> Added: `<id>` → scope: [<list>]

---

### Sub-command: `update`

**Purpose**: re-fetch URL sources and refresh the local cache.

**Input** (optional): a source `id`. If omitted, update all URL sources in the target registry.
The `--global` flag targets `~/.sdd/kb.yaml`; omitting it targets `.sdd/kb.yaml`.

**Step 1 — Load target `kb.yaml`**: parse all entries that have a `url` field.
If `id` is provided, filter to that entry. If not found, report:
> Source `<id>` not found in `kb.yaml`. Run `/sdd-kb status [--global]` to list sources.

**Step 2 — Re-fetch each matched source**:
- Fetch the URL content (same collection logic as `add` Step 2).
- Write to `cache` path, overwriting the previous file.
- Update `fetched_at` in `kb.yaml` to the current ISO 8601 timestamp.
- Report: `Updated: <id> (fetched_at: <timestamp>)`

**Step 3 — Handle fetch errors**:
If a URL is unreachable:
> Failed to update `<id>`: <error>. Cache from `<fetched_at>` will continue to be used.
Continue with remaining sources without stopping.

---

### Sub-command: `status`

**Purpose**: show exactly which knowledge sources each SDD action will load,
and flag any issues.

**Flags**:
- No flag → show project KB only (`.sdd/kb.yaml`).
- `--global` → show global KB only (`~/.sdd/kb.yaml`).
- `--all` → show both layers merged, with `[global]` / `[project]` labels; deduplicated by `path`/`url` (project wins).

**Step 1 — Load target registry/registries**: parse all source entries from the selected layer(s).

**Step 2 — For each source, check health**:

| Check | Status label |
|---|---|
| `path` exists and non-empty | `ok` |
| `path` missing or empty | `not found` |
| `url` source, cache exists, not stale | `ok (cached <date>)` |
| `url` source, cache exists, stale | `stale (<N> days old)` |
| `url` source, cache missing | `not cached` |

**Step 3 — Display action → source mapping**:

```
KB Status  (--all: global + project)

  sdd-brainstorm
    architecture.md          ok            [global]
    domain-model.md          ok            [project]

  sdd-propose
    architecture.md          ok            [global]
    domain-model.md          ok            [project]

  sdd-ff
    architecture.md          ok            [global]
    coding-standards.md      ok            [global]
    domain-model.md          ok            [project]

  sdd-code
    coding-standards.md      ok            [global]
    internal-api             stale (8 days old) [project] -- run /sdd-kb update internal-api

  sdd-review-code
    coding-standards.md      ok            [global]
    auth-patterns.md         ok            [project]
    internal-api             stale (8 days old) [project]

  sdd-review-spec
    architecture.md          ok            [global]

  sdd-verify
    auth-patterns.md         ok            [project]

  sdd-plan, sdd-ship         (no KB sources registered)
```

**Step 4 — Summary line**:
> N sources registered. M ok, K stale, J not found.

If any source is stale:
> Run `/sdd-kb update` to refresh all stale sources.

If any source is `not found`:
> Fix the paths above in `.sdd/kb.yaml`, or remove the entries if the files no longer exist.

---

## Post-check

1. **No SDD artifact**: this action produces no change artifact (no brainstorm.md,
   proposal.md, etc.). No provenance stamp is written.

2. **No delegation**: all logic is SDD self-logic. No external skill is invoked.

3. **Next-step guidance** (sub-command dependent):
   - After `init`: "Run `/sdd-kb add [--global] <path-or-url>` to register your first source."
   - After `add`: "Run `/sdd-kb status [--all]` to verify all sources are reachable."
   - After `update`: "Run `/sdd-kb status [--all]` to confirm all caches are current."
   - After `status`: if all ok — "KB is ready. SDD will inject context automatically during skill Pre-checks."
