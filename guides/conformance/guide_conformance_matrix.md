# Guide Conformance Matrix

This document tracks conformance of guides against specifications and scenarios.

## Matrix Format

| Guide ID | Title | Requirements | Scenarios | Status | Last Reviewed |
|---|---|---|---|---|---|
| UG-0001 | Getting Started | REQ-RES-001, REQ-SCREEN-001, REQ-COMP-001, REQ-RENDER-001 | SCN-004, SCN-021, SCN-041, SCN-061 | Active | 2026-03-20 |
| UG-0002 | Working with Ash UI Resources | REQ-RES-001, REQ-RES-003, REQ-RES-004, REQ-RES-007 | SCN-001, SCN-003, SCN-004, SCN-005 | Active | 2026-03-20 |
| UG-0003 | Data Binding in Ash UI | REQ-BIND-001, REQ-BIND-002, REQ-BIND-003, REQ-BIND-007, REQ-BIND-008, REQ-BIND-010 | SCN-006, SCN-007, SCN-009, SCN-010, SCN-021, SCN-101 | Active | 2026-03-20 |
| UG-0004 | Authorization in Ash UI | REQ-AUTH-002, REQ-AUTH-003, REQ-AUTH-005, REQ-AUTH-007, REQ-AUTH-009, REQ-AUTH-012 | SCN-021, SCN-081, SCN-082, SCN-084, SCN-085, SCN-101 | Active | 2026-03-20 |
| UG-0005 | Migration Guide from v0 to v1 | REQ-RES-001, REQ-COMP-001, REQ-RENDER-001, REQ-AUTH-002 | SCN-004, SCN-041, SCN-061, SCN-081 | Active | 2026-03-20 |
| DG-0001 | Architecture Overview | REQ-FRAMEWORK-001, REQ-COMP-001, REQ-RENDER-001, REQ-AUTH-002, REQ-OBS-001 | SCN-041, SCN-061, SCN-081, SCN-101 | Active | 2026-03-20 |
| DG-0002 | Contributing to Ash UI | REQ-FRAMEWORK-001, REQ-COMP-001, REQ-OBS-001 | SCN-041, SCN-061, SCN-101 | Active | 2026-03-20 |
| DG-0003 | Testing Guide | REQ-COMP-001, REQ-BIND-010, REQ-RENDER-012, REQ-AUTH-012, REQ-OBS-001 | SCN-041, SCN-061, SCN-081, SCN-101 | Active | 2026-03-20 |
| DG-0004 | Release Process | REQ-COMP-001, REQ-RENDER-001, REQ-AUTH-012, REQ-OBS-001 | SCN-041, SCN-061, SCN-081, SCN-101 | Active | 2026-03-20 |

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
| UG-0001 | Getting Started | 4 | 4 | Active |
| UG-0002 | Working with Ash UI Resources | 4 | 4 | Active |
| UG-0003 | Data Binding in Ash UI | 6 | 6 | Active |
| UG-0004 | Authorization in Ash UI | 6 | 6 | Active |
| UG-0005 | Migration Guide from v0 to v1 | 4 | 4 | Active |

### Developer Guides (DG-*)

| Guide ID | Title | REQ Coverage | SCN Coverage | Status |
|---|---|---|---|---|
| DG-0001 | Architecture Overview | 5 | 4 | Active |
| DG-0002 | Contributing to Ash UI | 3 | 3 | Active |
| DG-0003 | Testing Guide | 5 | 4 | Active |
| DG-0004 | Release Process | 4 | 4 | Active |

## Coverage by Requirement Family

### REQ-RES-*: Resource Contract

| REQ | Guides | Status |
|---|---|---|
| REQ-RES-001 | UG-0001, UG-0002, UG-0005 | Covered |
| REQ-RES-002 | UG-0002 | Partially Covered |
| REQ-RES-003 | UG-0002 | Covered |
| REQ-RES-004 | UG-0002 | Covered |
| REQ-RES-005 | UG-0002 | Partially Covered |
| REQ-RES-006 | UG-0004 | Covered |
| REQ-RES-007 | UG-0002 | Covered |
| REQ-RES-008 | - | Needs Guide |

### REQ-SCREEN-*: Screen Contract

| REQ | Guides | Status |
|---|---|---|
| REQ-SCREEN-001 | UG-0001 | Covered |
| REQ-SCREEN-002 | UG-0001, UG-0004 | Covered |
| REQ-SCREEN-003 | UG-0002 | Covered |
| REQ-SCREEN-004 | UG-0003 | Covered |
| REQ-SCREEN-005 | UG-0001 | Covered |
| REQ-SCREEN-006 | UG-0004 | Partially Covered |
| REQ-SCREEN-007 | UG-0003 | Partially Covered |
| REQ-SCREEN-008 | UG-0004 | Covered |
| REQ-SCREEN-009 | UG-0001 | Partially Covered |
| REQ-SCREEN-010 | UG-0001 | Partially Covered |

## Needed Guides

### High Priority

1. **DG-0005**: Compiler Internals (REQ-COMP-002 through REQ-COMP-010)
2. **DG-0006**: Renderer Adapter Internals (REQ-RENDER-002 through REQ-RENDER-012)
3. **UG-0006**: Forms and Validation (REQ-BIND-007, REQ-SCREEN-007)

### Medium Priority

4. **UG-0007**: Lists and collections
5. **DG-0007**: Extension development
6. **UG-0008**: Performance and observability

### Low Priority

7. **UG-0009**: Advanced renderer integration
8. **DG-0008**: Internal caching strategy
9. **DG-0009**: Governance maintenance

## Related Documents

- [../contracts/guide_contract.md](../contracts/guide_contract.md)
- [../contracts/guide_traceability_contract.md](../contracts/guide_traceability_contract.md)
- [../../specs/conformance/spec_conformance_matrix.md](../../specs/conformance/spec_conformance_matrix.md)
