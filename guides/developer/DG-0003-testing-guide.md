# DG-0003: Testing Guide

---
id: DG-0003
title: Testing Guide
audience: Framework Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-COMP-001, REQ-BIND-010, REQ-RENDER-012, REQ-AUTH-012, REQ-OBS-001]
related_scns: [SCN-041, SCN-061, SCN-081, SCN-101]
related_guides: [DG-0001, DG-0002, DG-0004, UG-0003]
diagram_required: false
---

## Overview

This guide explains how to validate Ash UI changes locally. It covers the current test layout, focused commands, and when to run governance validation scripts in addition to `mix test`.

## Prerequisites

Before reading this guide, you should:

- Have a working local Postgres-backed test setup for Ash UI
- Know which part of the system you are changing
- Have read [DG-0001](./DG-0001-architecture-overview.md)

## Test Layers

The current test suite is organized by subsystem:

- `test/ash_ui/resources/` for resource behavior
- `test/ash_ui/compiler*` and `test/ash_ui/dsl*` for compilation and DSL
- `test/ash_ui/liveview/` for mount, hooks, event, and update flows
- `test/ash_ui/runtime/` for bindings and actions
- `test/ash_ui/rendering/` for canonical conversion and renderer adapters
- `test/ash_ui/authorization/` for policies and runtime enforcement
- `test/ash_ui/telemetry_test.exs` for observability

## Focused Test Commands

Run the smallest useful slice first.

Compiler work:

```bash
mix test test/ash_ui/compiler_test.exs test/ash_ui/dsl/builder_test.exs
```

LiveView work:

```bash
mix test test/ash_ui/liveview/liveview_integration_test.exs test/ash_ui/liveview/lifecycle_test.exs
```

Authorization work:

```bash
mix test test/ash_ui/authorization/runtime_test.exs test/ash_ui/authorization/resource_policies_test.exs
```

Rendering work:

```bash
mix test test/ash_ui/rendering/iur_adapter_test.exs test/ash_ui/rendering/live_ui_adapter_test.exs
```

Telemetry work:

```bash
mix test test/ash_ui/telemetry_test.exs
```

## Governance Validation

Documentation and governance changes should also run the shell validators:

```bash
./scripts/validate_specs_governance.sh
./scripts/validate_rfc_governance.sh
./scripts/validate_guides_governance.sh
```

Use these when you touch:

- `specs/`
- `rfcs/`
- `guides/`

## What to Verify by Change Type

### Resource model changes

Verify create, update, relationship loading, and version increments.

### Compiler changes

Verify:

- compile success
- compile failure shape
- cache behavior
- canonical conversion compatibility

### LiveView and runtime changes

Verify:

- mount success and denial cases
- binding evaluation
- event handling
- lifecycle hook behavior

### Authorization changes

Verify:

- unauthenticated flow
- inactive user flow
- authorized admin or owner flow
- binding read and write access

### Telemetry changes

Verify event names, metadata shape, and snapshot metrics.

## Common Testing Pitfalls

### Shared ETS state

Compiler and authorization caches use ETS. If a test manipulates global cache state, avoid `async: true` for that module and clear or initialize the cache explicitly.

### Placeholder runtime behavior

Some resource loading and action execution paths are currently stubbed or fallback-based. Test the contract the module promises, not assumptions about a future integration.

### Database-backed screen loading

If an integration test mounts by name, create a real `Screen` record in setup instead of using only in-memory structs.

## Release-Oriented Checks

Before marking a release-related phase section complete, also confirm:

- the relevant plan file is updated
- guide indexes reference new guides
- conformance or governance documents are still internally consistent

## See Also

- [DG-0002: Contributing](./DG-0002-contributing.md)
- [DG-0004: Release Process](./DG-0004-release-process.md)
- [UG-0003: Data Binding](../user/UG-0003-data-binding.md)
- [spec_conformance_matrix.md](../../specs/conformance/spec_conformance_matrix.md)
