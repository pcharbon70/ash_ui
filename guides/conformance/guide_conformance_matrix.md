# Guide Conformance Matrix

This document tracks conformance of guides against specifications and scenarios.

## Matrix Format

| Guide ID | Title | Requirements | Scenarios | Status | Last Reviewed |
|---|---|---|---|---|---|
| UG-0001 | Getting Started | REQ-RES-001, REQ-SCREEN-001 | SCN-001, SCN-004 | Active | 2026-03-18 |
| DG-0001 | Architecture Overview | REQ-FRAMEWORK-* | SCN-101 | Active | 2026-03-18 |

## Status Definitions

| Status | Description |
|---|---|
| Draft | Guide being written |
| Review | Guide under review |
| Active | Guide published and current |
| Deprecated | Guide outdated but kept for reference |
| Retired | Guide removed |

## Coverage by Guide Type

### User Guides (UG-*)

| Guide ID | Title | REQ Coverage | SCN Coverage | Status |
|---|---|---|---|---|
| UG-0001 | Getting Started | 2 | 2 | Active |

### Developer Guides (DG-*)

| Guide ID | Title | REQ Coverage | SCN Coverage | Status |
|---|---|---|---|---|
| DG-0001 | Architecture Overview | 8 | 1 | Active |

## Coverage by Requirement Family

### REQ-RES-*: Resource Contract

| REQ | Guides | Status |
|---|---|---|
| REQ-RES-001 | UG-0001 | Covered |
| REQ-RES-002 | - | Needs Guide |
| REQ-RES-003 | - | Needs Guide |
| REQ-RES-004 | - | Needs Guide |
| REQ-RES-005 | - | Needs Guide |
| REQ-RES-006 | - | Needs Guide |
| REQ-RES-007 | - | Needs Guide |
| REQ-RES-008 | - | Needs Guide |

### REQ-SCREEN-*: Screen Contract

| REQ | Guides | Status |
|---|---|---|
| REQ-SCREEN-001 | UG-0001 | Covered |
| REQ-SCREEN-002 | - | Needs Guide |
| REQ-SCREEN-003 | - | Needs Guide |
| REQ-SCREEN-004 | - | Needs Guide |
| REQ-SCREEN-005 | - | Needs Guide |
| REQ-SCREEN-006 | - | Needs Guide |
| REQ-SCREEN-007 | - | Needs Guide |
| REQ-SCREEN-008 | - | Needs Guide |
| REQ-SCREEN-009 | - | Needs Guide |
| REQ-SCREEN-010 | - | Needs Guide |

## Needed Guides

### High Priority

1. **UG-0002**: Screen Lifecycle (REQ-SCREEN-002)
2. **UG-0003**: Data Binding (REQ-BIND-001 through REQ-BIND-008)
3. **DG-0002**: Compilation Pipeline (REQ-COMP-001 through REQ-COMP-010)

### Medium Priority

4. **UG-0004**: Authorization (REQ-AUTH-001 through REQ-AUTH-012)
5. **DG-0003**: Rendering Architecture (REQ-RENDER-001 through REQ-RENDER-012)
6. **UG-0005**: Common UI Patterns

### Low Priority

7. **DG-0004**: Extension Development
8. **UG-0006**: Performance Tuning
9. **DG-0005**: Testing Strategies

## Related Documents

- [../contracts/guide_contract.md](../contracts/guide_contract.md)
- [../contracts/guide_traceability_contract.md](../contracts/guide_traceability_contract.md)
- [../../specs/conformance/spec_conformance_matrix.md](../../specs/conformance/spec_conformance_matrix.md)
