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
| REQ-RES-001 | Resource Definition | resources/ui_element.md | SCN-001, SCN-002, SCN-004 |
| REQ-RES-002 | Type Safety | resources/ui_element.md | SCN-002 |
| REQ-RES-003 | Relationship Definition | resources/ui_element.md, resources/ui_screen.md | SCN-003 |
| REQ-RES-004 | Action Definition | resources/ui_element.md, resources/ui_screen.md | - |
| REQ-RES-005 | Validation | compilation/validator.md | SCN-042 |
| REQ-RES-006 | Authorization | authorization_contract.md | SCN-081, SCN-082 |
| REQ-RES-007 | Metadata | resources/ui_element.md | SCN-010 |
| REQ-RES-008 | Extensions | extension_contract.md | - |

### REQ-BIND-*: Binding Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-BIND-001 | Binding Definition | resources/ui_binding.md | SCN-006 |
| REQ-BIND-002 | Binding Types | resources/ui_binding.md | SCN-007, SCN-008, SCN-009 |
| REQ-BIND-003 | Source Resolution | compilation/resolver.md | SCN-010 |
| REQ-BIND-004 | Target Binding | resources/ui_binding.md | - |
| REQ-BIND-005 | Transformation | compilation/transform.md | - |
| REQ-BIND-006 | Reactivity | runtime/reactive.md | - |
| REQ-BIND-007 | Bidirectional Updates | runtime/reactive.md | - |
| REQ-BIND-008 | Action Execution | runtime/actions.md | SCN-009 |
| REQ-BIND-009 | Validation | compilation/validator.md | - |
| REQ-BIND-010 | Observability | observability_contract.md | - |

### REQ-AUTH-*: Authorization Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-AUTH-001 | Policy Definition | framework/policies.md | - |
| REQ-AUTH-002 | Screen Authorization | runtime/session.md | SCN-081 |
| REQ-AUTH-003 | Action Authorization | framework/actions.md | SCN-082 |
| REQ-AUTH-004 | Field-Level Authorization | framework/field_policies.md | SCN-083 |
| REQ-AUTH-005 | Binding Authorization | runtime/binding.md | SCN-084 |
| REQ-AUTH-006 | Resource Ownership | framework/ownership.md | - |
| REQ-AUTH-007 | Role-Based Access | framework/roles.md | SCN-085 |
| REQ-AUTH-008 | Authorization Context | runtime/context.md | - |
| REQ-AUTH-009 | Error Handling | runtime/errors.md | - |
| REQ-AUTH-010 | Authorization Caching | framework/auth_cache.md | - |
| REQ-AUTH-011 | Audit Logging | framework/audit.md | - |
| REQ-AUTH-012 | Observability | observability_contract.md | - |

## Compilation Control Plane

### REQ-COMP-*: Compilation Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-COMP-001 | Compilation Pipeline | compilation/compiler.md | SCN-041 |
| REQ-COMP-002 | Schema Validation | compilation/validator.md | SCN-042 |
| REQ-COMP-003 | IUR Schema | compilation/iur.md | SCN-043 |
| REQ-COMP-004 | Resource Resolution | compilation/resolver.md | SCN-044 |
| REQ-COMP-005 | Normalization | compilation/normalizer.md | SCN-045 |
| REQ-COMP-006 | Optimization | compilation/optimizer.md | - |
| REQ-COMP-007 | Caching | compilation/cache.md | SCN-046, SCN-047 |
| REQ-COMP-008 | Error Reporting | compilation/errors.md | - |
| REQ-COMP-009 | Incremental Compilation | compilation/incremental.md | - |
| REQ-COMP-010 | Observability | observability_contract.md | - |

## Rendering Control Plane

### REQ-RENDER-*: Rendering Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-RENDER-001 | Renderer Contract | rendering/registry.md | - |
| REQ-RENDER-002 | LiveView Rendering | rendering/liveview.md | SCN-061 |
| REQ-RENDER-003 | Static HTML Rendering | rendering/static.md | SCN-062 |
| REQ-RENDER-003B | Desktop Rendering | rendering/desktop.md | - |
| REQ-RENDER-004 | Component Rendering | rendering/component.md | SCN-063 |
| REQ-RENDER-005 | Data Binding Rendering | rendering/binding.md | SCN-064 |
| REQ-RENDER-006 | Error Handling | rendering/errors.md | SCN-066 |
| REQ-RENDER-007 | Layout Support | rendering/layout.md | SCN-065 |
| REQ-RENDER-008 | Asset Management | rendering/assets.md | - |
| REQ-RENDER-009 | Accessibility | rendering/a11y.md | - |
| REQ-RENDER-010 | Performance | rendering/performance.md | - |
| REQ-RENDER-011 | Extensibility | rendering/extensibility.md | - |
| REQ-RENDER-012 | Observability | observability_contract.md | - |

## Runtime Control Plane

### REQ-SCREEN-*: Screen Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-SCREEN-001 | Screen Definition | resources/ui_screen.md | SCN-004 |
| REQ-SCREEN-002 | Lifecycle Management | runtime/lifecycle.md | SCN-021, SCN-022, SCN-023 |
| REQ-SCREEN-003 | Element Composition | resources/ui_screen.md | SCN-005 |
| REQ-SCREEN-004 | Data Binding | resources/ui_binding.md | - |
| REQ-SCREEN-005 | Routing | runtime/routing.md | - |
| REQ-SCREEN-006 | Session Isolation | runtime/session.md | SCN-024, SCN-025 |
| REQ-SCREEN-007 | Event Handling | runtime/events.md | - |
| REQ-SCREEN-008 | Authorization | authorization_contract.md | SCN-081 |
| REQ-SCREEN-009 | Validation | compilation/validator.md | - |
| REQ-SCREEN-010 | Observability | observability_contract.md | SCN-105 |

## Extension Control Plane

### REQ-EXT-*: Extension Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-EXT-001 | Extension Definition | extension/widget.md | - |
| REQ-EXT-002 | Extension Admission | extension/admission.md | - |
| REQ-EXT-003 | Extension Lifecycle | extension/lifecycle.md | - |
| REQ-EXT-004 | Extension Isolation | extension/sandbox.md | - |
| REQ-EXT-005 | Extension Registry | extension/registry.md | - |
| REQ-EXT-006 | Extension Observability | observability_contract.md | - |

## Observability (Cross-Cutting)

### REQ-OBS-*: Observability Contract

| REQ | Description | Component Specs | Scenarios |
|---|---|---|---|
| REQ-OBS-001 | Event Schema | observability/schema.md | SCN-101 |
| REQ-OBS-002 | Event Categories | observability/events.md | SCN-101 |
| REQ-OBS-003 | Span Context | observability/tracing.md | SCN-102 |
| REQ-OBS-004 | Metrics | observability/metrics.md | SCN-104 |
| REQ-OBS-005 | Logging | observability/logging.md | - |
| REQ-OBS-006 | Error Tracking | observability/errors.md | SCN-103 |
| REQ-OBS-007 | Performance Monitoring | observability/performance.md | SCN-104 |
| REQ-OBS-008 | Session Observability | observability/session.md | SCN-105 |
| REQ-OBS-009 | Custom Events | observability/custom.md | - |
| REQ-OBS-010 | Event Handlers | observability/handlers.md | - |
| REQ-OBS-011 | Sampling | observability/sampling.md | - |
| REQ-OBS-012 | Data Privacy | observability/privacy.md | - |

## Coverage Summary

| Control Plane | Total REQ | With Spec | With SCN | Coverage |
|---|---|---|---|---|
| Framework | 28 | 8 | 10 | 36% |
| Compilation | 10 | 5 | 7 | 50% |
| Rendering | 12 | 6 | 6 | 50% |
| Runtime | 10 | 4 | 6 | 40% |
| Extension | 6 | 3 | 0 | 0% |
| Observability | 12 | 6 | 5 | 42% |
| **TOTAL** | **78** | **32** | **34** | **41%** |

## Coverage Milestones

### Foundation Baseline
- Target: 40% coverage
- Focus: core resource types, basic compilation, LiveView rendering

### Complete Framework Target
- Target: 70% coverage
- Add: full authorization, advanced compilation, all renderers

### Production Target
- Target: 90% coverage
- Add: extension system, comprehensive observability

## Related Specifications

- [scenario_catalog.md](scenario_catalog.md) - Full scenario definitions
- [../contracts/*.md](../contracts/) - All contract documents

## Notes

- Coverage reflects documented traceability, not proof that every requirement is fully production-backed
- Component specs marked with `-` are planned but not yet written
- Scenarios are added incrementally as features are implemented
- Coverage percentages are updated monthly
