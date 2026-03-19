# Ash UI Architecture Execution Plan Index

This directory contains a phased implementation plan for executing the Ash UI architecture baseline aligned with the unified-ui ecosystem.

The plan aligns to:
- `rfcs/RFC-0002-ash-ui-unified-integration.md`
- `specs/topology.md`
- `specs/contracts/*`
- `specs/conformance/*`

## Phase Files
1. [Phase 1 - Core Ash Resource Integration](./phase-01-core-ash-resource-integration.md): implement Ash Resources for storing unified-ui DSL definitions with Ash actions and policies.
2. [Phase 2 - IUR Adapter and Canonical Conversion](./phase-02-iur-adapter-and-canonical-conversion.md): implement Ash IUR to canonical unified_iur conversion.
3. [Phase 3 - Data Binding and Signal Mapping](./phase-03-data-binding-and-signal-mapping.md): implement Ash resource data binding to unified-ui signals.
4. [Phase 4 - Runtime and LiveView Integration](./phase-04-runtime-and-liveview-integration.md): implement LiveView mount/unmount and screen lifecycle.
5. [Phase 5 - Authorization and Policy Enforcement](./phase-05-authorization-and-policy-enforcement.md): implement Ash policy integration for UI access control.
6. [Phase 6 - Compiler and DSL Integration](./phase-06-compiler-and-dsl-integration.md): integrate unified-ui compiler with Ash Resource loading.
7. [Phase 7 - Renderer Package Integration](./phase-07-renderer-package-integration.md): implement live_ui/web_ui/desktop_ui package integration.
8. [Phase 8 - Governance Gates and Release Readiness](./phase-08-governance-gates-and-release-readiness.md): finalize CI gates, conformance tests, and rollout readiness.

## Shared Conventions
- Numbering:
  - Phases: `N`
  - Sections: `N.M`
  - Tasks: `N.M.K`
  - Subtasks: `N.M.K.L`
- Tracking:
  - Every phase, section, task, and subtask uses Markdown checkboxes (`[ ]`).
- Description requirement:
  - Every phase, section, and task starts with a short description paragraph.
- Integration-test requirement:
  - Each phase ends with a final integration-testing section.

## Shared Assumptions and Defaults
- Ash UI remains an Ash Framework integration layer for unified-ui
- UI definitions are stored as Ash Resources in the database
- unified-ui packages provide widgets, layouts, compilation, and rendering
- Ash policies control access to UI resources
- Data flows from Ash resources → Ash IUR → canonical IUR → renderer output
