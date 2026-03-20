# DG-0004: Release Process

---
id: DG-0004
title: Release Process
audience: Framework Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-COMP-001, REQ-RENDER-001, REQ-AUTH-012, REQ-OBS-001]
related_scns: [SCN-041, SCN-061, SCN-081, SCN-101]
related_guides: [DG-0002, DG-0003, UG-0005]
diagram_required: false
---

## Overview

This guide documents the current Ash UI release flow. It is intended to be used alongside the Phase 8 release-readiness checklist and focuses on what must be true before a release candidate is cut.

## Prerequisites

Before reading this guide, you should:

- Have contributor access to the repository and release tooling
- Understand the architecture and test layout
- Have read [DG-0003: Testing Guide](./DG-0003-testing-guide.md)

## Release Inputs

A release candidate is only meaningful when these are aligned:

- implementation status in `specs/planning/`
- conformance and governance checks
- README and guide accuracy
- telemetry/dashboard readiness
- the operational assets in `release/`

## Standard Release Flow

1. Confirm the relevant phase checklist items are complete.
2. Run focused test suites for changed subsystems.
3. Run governance validation scripts for specs, RFCs, and guides.
4. Review telemetry dashboards and error rates.
5. Update version numbers and release notes.
6. Tag and publish the release artifact.

## Pre-Release Validation Commands

```bash
./scripts/validate_release_readiness.sh
./scripts/generate_changelog.sh vX.Y.Z
./scripts/test_rollback_procedure.sh
```

If the full suite is noisy or temporarily blocked, record the exact focused suites that passed and the specific remaining gaps before cutting anything intended for external use.

## Documentation Expectations

Before release:

- root `README.md` must match the implemented architecture
- user and developer guide indexes must be current
- migration guidance must exist for any breaking change
- release notes must call out fallback renderer behavior if external packages are still optional

## Operational Readiness

Review:

- authorization failure rates
- screen mount and render timings
- binding error counts
- renderer usage split by environment

These metrics are exposed through `AshUI.Telemetry.snapshot/0` and the dashboard JSON definitions under `priv/monitoring/dashboards/`.

## Versioning Notes

Ash UI is currently versioned in `mix.exs`. When preparing a release:

- update the library version
- verify docs and examples refer to the same version family
- make sure migration guidance is updated if behavior changed

## Tagging and Publication

The mechanical publication step depends on repository policy and package destination, but the expected order is:

1. merge the release-ready branch
2. create the git tag for the release version
3. publish the package if distribution is enabled
4. announce any known follow-up work or rollback caveats

## Rollback Readiness

Every release candidate should have:

- a documented rollback trigger
- a short rollback procedure
- a communication template for reverting or pausing rollout

These are formalized further in the Phase 8 release checklist documents.

## See Also

- [DG-0002: Contributing](./DG-0002-contributing.md)
- [DG-0003: Testing Guide](./DG-0003-testing-guide.md)
- [UG-0005: Migration Guide from v0 to v1](../user/UG-0005-migration-v0-to-v1.md)
- [release/README.md](../../release/README.md)
- [phase-08-governance-gates-and-release-readiness.md](../../specs/planning/phase-08-governance-gates-and-release-readiness.md)
