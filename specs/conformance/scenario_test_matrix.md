# Scenario Test Matrix

This document maps each conformance scenario (`SCN-*`) to the executable test files that validate it in the conformance harness.

## Matrix

| SCN | Scenario | Verified By |
|---|---|---|
| SCN-001 | Basic Element Resource Creation | test/ash_ui/resources/element_test.exs |
| SCN-002 | Element Type Validation | test/ash_ui/resources/element_test.exs |
| SCN-003 | Element Relationship Definition | test/ash_ui/relationship_integration_test.exs |
| SCN-004 | Screen Resource Creation | test/ash_ui/resources/screen_test.exs |
| SCN-005 | Screen Element Composition | test/ash_ui/relationship_integration_test.exs |
| SCN-006 | Binding Resource Creation | test/ash_ui/resources/binding_test.exs |
| SCN-007 | Binding Value Type | test/ash_ui/runtime/binding_evaluator_test.exs, test/ash_ui/runtime/bidirectional_binding_test.exs |
| SCN-008 | Binding List Type | test/ash_ui/runtime/list_binding_test.exs |
| SCN-009 | Binding Action Type | test/ash_ui/runtime/action_binding_test.exs, test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-010 | Source Resolution | test/ash_ui/runtime/binding_evaluator_test.exs |
| SCN-011 | Binding Transformation | test/ash_ui/runtime/binding_evaluator_test.exs, test/ash_ui/runtime/bidirectional_binding_test.exs |
| SCN-021 | Screen Mount | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-022 | Screen Unmount | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-023 | Screen Update | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-024 | Session Isolation | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-025 | Concurrent Sessions | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-026 | Screen Data Binding | test/ash_ui/liveview/phase_4_integration_test.exs, test/ash_ui/runtime/bidirectional_binding_test.exs |
| SCN-027 | Screen Event Handling | test/ash_ui/liveview/phase_4_integration_test.exs, test/ash_ui/runtime/action_binding_test.exs |
| SCN-041 | Resource Compilation | test/ash_ui/compiler/phase_6_integration_test.exs |
| SCN-042 | Schema Validation | test/ash_ui/compiler_test.exs, test/ash_ui/compiler/phase_6_integration_test.exs |
| SCN-043 | IUR Generation | test/ash_ui/compiler_test.exs |
| SCN-044 | Resource Resolution | test/ash_ui/compiler_test.exs |
| SCN-045 | Normalization | test/ash_ui/compiler_test.exs |
| SCN-046 | Compiler Cache | test/ash_ui/compiler_test.exs, test/ash_ui/compiler/phase_6_integration_test.exs |
| SCN-047 | Cache Invalidation | test/ash_ui/compiler_test.exs |
| SCN-048 | Compilation Error Reporting | test/ash_ui/compiler/phase_6_integration_test.exs |
| SCN-049 | Incremental Compilation | test/ash_ui/compiler/phase_6_integration_test.exs |
| SCN-061 | LiveView Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-062 | Static HTML Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-063 | Component Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-064 | Binding Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-065 | Layout Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-066 | Error Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-067 | Desktop Rendering | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-068 | Renderer Selection | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-069 | Renderer Fallback | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-070 | Asset Management | test/ash_ui/rendering/phase_7_integration_test.exs |
| SCN-081 | Screen Mount Authorization | test/ash_ui/authorization/resource_authorizer_test.exs, test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-082 | Action Authorization | test/ash_ui/authorization/phase_5_integration_test.exs, test/ash_ui/runtime/action_binding_test.exs |
| SCN-083 | Field-Level Authorization | test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-084 | Binding Authorization | test/ash_ui/authorization/resource_authorizer_test.exs, test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-085 | Role-Based Access | test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-086 | Resource Ownership Enforcement | test/ash_ui/authorization/resource_authorizer_test.exs |
| SCN-087 | Authorization Context | test/ash_ui/authorization/resource_authorizer_test.exs, test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-088 | Authorization Error Handling | test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-089 | Authorization Caching | test/ash_ui/authorization/phase_5_integration_test.exs |
| SCN-101 | Event Emission | test/ash_ui/telemetry_test.exs |
| SCN-102 | Span Context | test/ash_ui/telemetry_test.exs |
| SCN-103 | Error Tracking | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-104 | Performance Monitoring | test/ash_ui/telemetry_test.exs |
| SCN-105 | Session Observability | test/ash_ui/liveview/phase_4_integration_test.exs |
| SCN-106 | Data Privacy Redaction | test/ash_ui/telemetry_test.exs |
| SCN-121 | Extension Registration | test/ash_ui/compiler/phase_6_integration_test.exs |
| SCN-122 | Extension Compilation | test/ash_ui/compiler/phase_6_integration_test.exs |

## Notes

- Only files tagged with `@moduletag :conformance` should appear in this matrix.
- Scenario-to-test mappings are enforced by `test/ash_ui/conformance_traceability_test.exs`.
- The conformance report consumes this matrix to summarize executable scenario coverage.
