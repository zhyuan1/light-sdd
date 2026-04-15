---
generated_by: "{skill}"
sdd_action: sdd-ff
timestamp: "{timestamp}"
---

# Tasks: {change-name}

## Task List

<!-- Each task references a spec capability. -->

### Batch 1

- [ ] Task title | spec: `capability` | size: S
- [ ] Task title | spec: `capability` | size: M

### Batch 2

- [ ] Task title | spec: `capability` | size: M

### Verification

- [ ] Run verification against all specs | size: S

## Dependency Order

<!-- Batch 1 must complete before Batch 2, etc. -->

Batch 1 -> Batch 2 -> ... -> Verification

## Verification Task

<!-- Final task(s) for running verification against specs. -->

- [ ] Run verification against all specs | size: S
