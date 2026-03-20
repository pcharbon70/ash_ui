# DG-0002: Contributing to Ash UI

---
id: DG-0002
title: Contributing to Ash UI
audience: Framework Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-FRAMEWORK-001, REQ-COMP-001, REQ-OBS-001]
related_scns: [SCN-041, SCN-061, SCN-101]
related_guides: [DG-0001, DG-0003, DG-0004]
diagram_required: false
---

## Overview

This guide explains the expected contribution workflow for Ash UI. It is written for contributors making code, spec, test, or governance changes inside this repository.

## Prerequisites

Before reading this guide, you should:

- Be able to run Elixir and Mix locally
- Understand the architecture in [DG-0001](./DG-0001-architecture-overview.md)
- Be familiar with the phase plans in `specs/planning/`

## Start from the Specs

Ash UI is governed by specs, ADRs, RFCs, conformance scenarios, and guides. Before making a non-trivial change:

- read the relevant contract under `specs/contracts/`
- check the phase plan under `specs/planning/`
- confirm whether an ADR or RFC already set the boundary

In practice, code changes that alter behavior usually also need:

- test updates
- plan status updates
- guide or README updates

## Local Workflow

The usual contribution loop is:

1. inspect the relevant modules and tests
2. make the smallest coherent change
3. run focused verification
4. update related specs or guides
5. commit one logical section at a time

Useful commands:

```bash
mix test test/ash_ui/compiler_test.exs
mix test test/ash_ui/liveview/liveview_integration_test.exs
mix test test/ash_ui/authorization/runtime_test.exs
./scripts/validate_specs_governance.sh
./scripts/validate_guides_governance.sh
```

## Change Categories

### Runtime or compiler changes

Prefer adding or updating tests near the affected modules first.

### Documentation changes

Follow the guide contract:

- metadata front matter
- `Overview`, `Prerequisites`, and `See Also` sections
- valid `REQ-*` and `SCN-*` traceability

### Governance changes

If you update plans, conformance, or release criteria, keep status documents aligned with what the code actually does.

## Pull Request Shape

Ash UI changes review best when they are grouped by one clear purpose:

- one phase section
- one architectural fix
- one guide or governance pass

A strong PR description should include:

- user-visible or contributor-visible impact
- affected modules
- verification commands
- remaining gaps or intentional follow-up work

## Commit Expectations

- use one commit per coherent unit of work
- avoid mixing generated noise with hand-written changes
- keep `_build/` and temporary reports out of staged changes unless explicitly needed

## Updating Plans and Guides

When a phase section is actually complete:

- mark the checklist items in the relevant plan
- update README or guide indexes if user-facing behavior changed
- refresh `guides/conformance/guide_conformance_matrix.md` when adding guides

## Review Checklist

- does the change match the current architecture rather than an older placeholder?
- are tests added or updated where behavior changed?
- do docs describe current behavior honestly, including fallbacks?
- are telemetry and authorization implications covered where relevant?

## See Also

- [DG-0001: Architecture Overview](./DG-0001-architecture-overview.md)
- [DG-0003: Testing Guide](./DG-0003-testing-guide.md)
- [DG-0004: Release Process](./DG-0004-release-process.md)
- [phase-08-governance-gates-and-release-readiness.md](../../specs/planning/phase-08-governance-gates-and-release-readiness.md)
