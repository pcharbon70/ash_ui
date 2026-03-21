# Spec Conformance Matrix

This document maps all requirements (REQ-*) to contracts, component specifications, and conformance scenarios (SCN-*).

## Matrix Format

The matrix provides complete traceability from:
- **Requirements** (REQ-*) - Normative statements in contracts
- **Contracts** - Documents containing requirements
- **Component Specs** - Detailed component specifications
- **Scenarios** (SCN-*) - Acceptance criteria tests

## Framework Control Plane

### REQ-RES-*: Resource Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-RES-001 | Resource Definition | resources/ui_element.md, resources/ui_screen.md, resources/ui_binding.md | SCN-001, SCN-004, SCN-006 |
| REQ-RES-002 | Type Safety | resources/ui_element.md, resources/ui_binding.md | SCN-002 |
| REQ-RES-003 | Relationship Definition | resources/ui_element.md, resources/ui_screen.md, resources/ui_binding.md | SCN-003, SCN-005 |
| REQ-RES-004 | Action Definition | resources/ui_screen.md, resources/ui_binding.md | SCN-004, SCN-006 |
| REQ-RES-005 | Validation | compilation/README.md | SCN-042 |
| REQ-RES-006 | Authorization | contracts/authorization_contract.md | SCN-081, SCN-084 |
| REQ-RES-007 | Metadata | resources/ui_screen.md, resources/ui_element.md, resources/ui_binding.md | SCN-004, SCN-006, SCN-010 |
| REQ-RES-008 | Extensions | extension_contract.md | - |

### REQ-BIND-*: Binding Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-BIND-001 | Binding Definition | resources/ui_binding.md | SCN-006 |
| REQ-BIND-002 | Binding Types | resources/ui_binding.md | SCN-007, SCN-008, SCN-009 |
| REQ-BIND-003 | Source Resolution | resources/ui_binding.md, compilation/README.md | SCN-010 |
| REQ-BIND-004 | Target Binding | resources/ui_binding.md | SCN-006 |
| REQ-BIND-005 | Transformation | planning/phase-03-data-binding-and-signal-mapping.md | SCN-011 |
| REQ-BIND-006 | Reactivity | planning/phase-04-runtime-and-liveview-integration.md | SCN-026 |
| REQ-BIND-007 | Bidirectional Updates | planning/phase-03-data-binding-and-signal-mapping.md | SCN-026 |
| REQ-BIND-008 | Action Execution | planning/phase-03-data-binding-and-signal-mapping.md, planning/phase-04-runtime-and-liveview-integration.md | SCN-009, SCN-027 |
| REQ-BIND-009 | Validation | compilation/README.md | SCN-042 |
| REQ-BIND-010 | Observability | contracts/observability_contract.md | SCN-101 |

### REQ-AUTH-*: Authorization Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-AUTH-001 | Policy Definition | planning/phase-05-authorization-and-policy-enforcement.md | SCN-081, SCN-085, SCN-086 |
| REQ-AUTH-002 | Screen Authorization | planning/phase-05-authorization-and-policy-enforcement.md | SCN-081 |
| REQ-AUTH-003 | Action Authorization | planning/phase-05-authorization-and-policy-enforcement.md | SCN-082 |
| REQ-AUTH-004 | Field-Level Authorization | planning/phase-05-authorization-and-policy-enforcement.md | SCN-083 |
| REQ-AUTH-005 | Binding Authorization | planning/phase-05-authorization-and-policy-enforcement.md | SCN-084 |
| REQ-AUTH-006 | Resource Ownership | planning/phase-05-authorization-and-policy-enforcement.md | SCN-086 |
| REQ-AUTH-007 | Role-Based Access | planning/phase-05-authorization-and-policy-enforcement.md | SCN-085 |
| REQ-AUTH-008 | Authorization Context | planning/phase-05-authorization-and-policy-enforcement.md | SCN-087 |
| REQ-AUTH-009 | Error Handling | planning/phase-05-authorization-and-policy-enforcement.md | SCN-088 |
| REQ-AUTH-010 | Authorization Caching | planning/phase-05-authorization-and-policy-enforcement.md | SCN-089 |
| REQ-AUTH-011 | Audit Logging | framework/audit.md | - |
| REQ-AUTH-012 | Observability | contracts/observability_contract.md | - |

## Compilation Control Plane

### REQ-COMP-*: Compilation Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-COMP-001 | Compilation Pipeline | compilation/README.md, planning/phase-06-compiler-and-dsl-integration.md | SCN-041 |
| REQ-COMP-002 | Schema Validation | compilation/README.md, planning/phase-06-compiler-and-dsl-integration.md | SCN-042 |
| REQ-COMP-003 | IUR Schema | compilation/README.md | SCN-043 |
| REQ-COMP-004 | Resource Resolution | compilation/README.md | SCN-044 |
| REQ-COMP-005 | Normalization | compilation/README.md | SCN-045 |
| REQ-COMP-006 | Optimization | compilation/optimizer.md | - |
| REQ-COMP-007 | Caching | compilation/README.md, planning/phase-06-compiler-and-dsl-integration.md | SCN-046, SCN-047 |
| REQ-COMP-008 | Error Reporting | compilation/README.md, planning/phase-06-compiler-and-dsl-integration.md | SCN-048 |
| REQ-COMP-009 | Incremental Compilation | planning/phase-06-compiler-and-dsl-integration.md | SCN-049 |
| REQ-COMP-010 | Observability | contracts/observability_contract.md | SCN-101 |

## Rendering Control Plane

### REQ-RENDER-*: Rendering Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-RENDER-001 | Renderer Contract | rendering/README.md, planning/phase-07-renderer-package-integration.md | SCN-068 |
| REQ-RENDER-002 | LiveView Rendering | rendering/README.md, planning/phase-07-renderer-package-integration.md | SCN-061 |
| REQ-RENDER-003 | Static HTML Rendering | rendering/README.md, planning/phase-07-renderer-package-integration.md | SCN-062 |
| REQ-RENDER-003B | Desktop Rendering | rendering/README.md, planning/phase-07-renderer-package-integration.md | SCN-067 |
| REQ-RENDER-004 | Component Rendering | rendering/README.md | SCN-063 |
| REQ-RENDER-005 | Data Binding Rendering | rendering/README.md | SCN-064 |
| REQ-RENDER-006 | Error Handling | rendering/README.md, planning/phase-07-renderer-package-integration.md | SCN-066, SCN-069 |
| REQ-RENDER-007 | Layout Support | rendering/README.md | SCN-065 |
| REQ-RENDER-008 | Asset Management | rendering/README.md, planning/phase-07-renderer-package-integration.md | SCN-070 |
| REQ-RENDER-009 | Accessibility | rendering/a11y.md | - |
| REQ-RENDER-010 | Performance | rendering/performance.md | - |
| REQ-RENDER-011 | Extensibility | rendering/extensibility.md | - |
| REQ-RENDER-012 | Observability | contracts/observability_contract.md | SCN-101 |

## Runtime Control Plane

### REQ-SCREEN-*: Screen Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-SCREEN-001 | Screen Definition | resources/ui_screen.md | SCN-004 |
| REQ-SCREEN-002 | Lifecycle Management | planning/phase-04-runtime-and-liveview-integration.md | SCN-021, SCN-022, SCN-023 |
| REQ-SCREEN-003 | Element Composition | resources/ui_screen.md | SCN-005 |
| REQ-SCREEN-004 | Data Binding | resources/ui_binding.md, planning/phase-04-runtime-and-liveview-integration.md | SCN-026 |
| REQ-SCREEN-005 | Routing | resources/ui_screen.md | SCN-004 |
| REQ-SCREEN-006 | Session Isolation | planning/phase-04-runtime-and-liveview-integration.md | SCN-024, SCN-025 |
| REQ-SCREEN-007 | Event Handling | planning/phase-04-runtime-and-liveview-integration.md | SCN-027 |
| REQ-SCREEN-008 | Authorization | contracts/authorization_contract.md | SCN-081 |
| REQ-SCREEN-009 | Validation | compilation/README.md | SCN-042 |
| REQ-SCREEN-010 | Observability | contracts/observability_contract.md | SCN-105 |

## Extension Control Plane

### REQ-EXT-*: Extension Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-EXT-001 | Extension Definition | planning/phase-06-compiler-and-dsl-integration.md | SCN-121 |
| REQ-EXT-002 | Extension Admission | planning/phase-06-compiler-and-dsl-integration.md | SCN-122 |
| REQ-EXT-003 | Extension Lifecycle | planning/phase-06-compiler-and-dsl-integration.md | SCN-122 |
| REQ-EXT-004 | Extension Isolation | extension/sandbox.md | - |
| REQ-EXT-005 | Extension Registry | planning/phase-06-compiler-and-dsl-integration.md | SCN-121 |
| REQ-EXT-006 | Extension Observability | observability_contract.md | - |

## Observability (Cross-Cutting)

### REQ-OBS-*: Observability Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-OBS-001 | Event Schema | contracts/observability_contract.md | SCN-101 |
| REQ-OBS-002 | Event Categories | contracts/observability_contract.md | SCN-101 |
| REQ-OBS-003 | Span Context | contracts/observability_contract.md | SCN-102 |
| REQ-OBS-004 | Metrics | contracts/observability_contract.md | SCN-104 |
| REQ-OBS-005 | Logging | observability/logging.md | - |
| REQ-OBS-006 | Error Tracking | contracts/observability_contract.md | SCN-103 |
| REQ-OBS-007 | Performance Monitoring | contracts/observability_contract.md | SCN-104 |
| REQ-OBS-008 | Session Observability | contracts/observability_contract.md | SCN-105 |
| REQ-OBS-009 | Custom Events | observability/custom.md | - |
| REQ-OBS-010 | Event Handlers | contracts/observability_contract.md | SCN-101 |
| REQ-OBS-011 | Sampling | observability/sampling.md | - |
| REQ-OBS-012 | Data Privacy | contracts/observability_contract.md | SCN-106 |

## Coverage Summary

| Control Plane | Total REQ | With Spec | With SCN | Coverage |
|---|---|---|---|---|
| Framework | 30 | 28 | 25 | 83% |
| Compilation | 10 | 9 | 9 | 90% |
| Rendering | 12 | 9 | 9 | 75% |
| Runtime | 10 | 10 | 10 | 100% |
| Extension | 6 | 4 | 4 | 67% |
| Observability | 12 | 9 | 8 | 67% |
| **TOTAL** | **80** | **69** | **65** | **81%** |

## Coverage Milestones

### Foundation Baseline
- Target: 40% coverage
- Status: surpassed
- Focus delivered: core resources, compilation, LiveView rendering

### Complete Framework Target
- Target: 70% coverage
- Status: surpassed
- Focus delivered: real runtime bindings, authorization, renderer selection and fallback

### Production Target
- Target: 90% coverage
- Remaining work: accessibility, audit logging, extension isolation, custom events, sampling

## Related Specifications

- [scenario_catalog.md](scenario_catalog.md) - Full scenario definitions
- [scenario_test_matrix.md](scenario_test_matrix.md) - Executable scenario-to-test traceability
- [../contracts/*.md](../contracts/) - All contract documents

## Notes

- Coverage reflects explicit traceability from requirement -> scenario -> conformance-tagged test file
- Rows marked with `-` indicate intentionally uncovered or still-undocumented areas
- The scenario test matrix is enforced by `test/ash_ui/conformance_traceability_test.exs`
- Coverage percentages should be updated whenever scenarios or conformance-tagged tests change
