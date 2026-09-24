# Contract: Architecture Audit Record

## Purpose

Define the evidence required to classify every production source area and to make an architecture refactor reviewable without inferring intent from a diff.

## Required record

Each reviewed source area must have one of these statuses:

- `compliant`: no actionable violation found.
- `refactorable`: one or more findings are approved for this feature.
- `deferred`: a finding exists but needs a later slice, broader design, or missing coverage.

Each finding must record:

```text
location
category
current responsibility
expected boundary
dependency direction
user impact
maintenance impact
priority
disposition
verification evidence
```

## Boundary rules

- `domain/` must not import Flutter, Drift, Supabase, or presentation state-management packages.
- `presentation/` may render and coordinate state, but must not own reusable business calculations, repository implementations, or external SDK exception classification.
- Feature code must not import another feature's presentation internals.
- `core/` may contain infrastructure and presentation primitives used by at least two features; feature-specific entities and rules remain in the owning feature.
- Composition/DI may assemble concrete implementations, but screens and feature widgets must depend on contracts.

## Completion criteria

A finding is `completed` only when the changed boundary has focused automated coverage and the full analysis/test checks pass. A `deferred` finding must include the reason, affected paths, risk, and the next intended boundary.
