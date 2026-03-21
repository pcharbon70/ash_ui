# Screen Contract (REQ-SCREEN-*)

This contract defines the normative requirements for screen records and screen runtime behavior in Ash UI.

## Purpose

Screens are the top-level durable UI records in Ash UI. They store `unified_dsl`, compose child elements and bindings, and act as the boundary mounted into LiveView sessions.

## Control Plane

**Owner**: `AshUI.Runtime`

## Dependencies

- REQ-RES-*: resource definitions
- REQ-COMP-*: compilation contracts
- REQ-BIND-*: binding semantics

## Requirements

### REQ-SCREEN-001: Screen Definition

All screens MUST be represented as persisted `AshUI.Resources.Screen` records.

```elixir
attributes do
  uuid_primary_key :id
  attribute :name, :string, allow_nil?: false
  attribute :unified_dsl, :map, default: %{}
  attribute :layout, :atom, default: :default
  attribute :route, :string
  attribute :metadata, :map, default: %{}
  attribute :active, :boolean, default: true
  attribute :version, :integer, default: 1
end
```

**Acceptance Criteria**:
- AC-001: Screens use `Ash.Resource`
- AC-002: Screens persist `name` and `unified_dsl`
- AC-003: Screens expose layout and route metadata

### REQ-SCREEN-002: Lifecycle Management

Screens MUST implement a runtime lifecycle through LiveView integration and screen state management.

**Lifecycle States**:
1. loaded
2. mounting
3. mounted
4. updating
5. unmounting
6. unmounted

**Acceptance Criteria**:
- AC-001: Screens mount through `AshUI.LiveView.Integration`
- AC-002: Runtime cleanup occurs on disconnect or explicit unmount paths
- AC-003: Invalid lifecycle transitions are handled safely
- AC-004: Lifecycle events emit telemetry

### REQ-SCREEN-003: Element Composition

Screens MUST support both persisted child elements and nested structure in `unified_dsl`.

**Acceptance Criteria**:
- AC-001: Screens expose `has_many :elements`
- AC-002: Elements preserve ordering metadata
- AC-003: Screens expose `has_many :bindings`
- AC-004: `unified_dsl` remains the canonical nested screen tree

### REQ-SCREEN-004: Data Binding Context

Screens MUST provide the runtime context needed for child binding resolution.

**Acceptance Criteria**:
- AC-001: Binding evaluation is scoped to the mounted screen
- AC-002: Binding values are assigned into screen runtime state
- AC-003: Binding failures can be surfaced at screen level
- AC-004: Screen updates can trigger re-render paths

### REQ-SCREEN-005: Routing

Routable screens MUST define a stable route path.

**Acceptance Criteria**:
- AC-001: Routed screens persist `route`
- AC-002: Route identifiers are unique where routing is enabled
- AC-003: Route params are available to mount logic
- AC-004: Missing routes are handled explicitly by the application

### REQ-SCREEN-006: Session Isolation

Mounted screens MUST maintain isolated state per LiveView session.

**Acceptance Criteria**:
- AC-001: Each LiveView session has independent screen state
- AC-002: Session changes do not leak across connections
- AC-003: Disconnect cleanup releases screen-specific state
- AC-004: Concurrent sessions are supported

### REQ-SCREEN-007: Event Handling

Screens MUST route user events through the runtime event handler boundary.

**Acceptance Criteria**:
- AC-001: Event targets can be matched to bindings or runtime handlers
- AC-002: Unknown events fail safely
- AC-003: Event errors do not crash the LiveView session
- AC-004: Successful events can trigger re-render paths

### REQ-SCREEN-008: Authorization

Screens MUST enforce authorization before protected mount and update flows continue.

**Acceptance Criteria**:
- AC-001: Mount checks actor access before compilation
- AC-002: Unauthorized mounts return a safe runtime response
- AC-003: Binding and action authorization integrate with the mounted screen context
- AC-004: Authorization failures are observable

### REQ-SCREEN-009: Validation

Screens MUST validate configuration before use.

**Acceptance Criteria**:
- AC-001: Invalid screen definitions fail fast
- AC-002: Required fields produce descriptive errors
- AC-003: Invalid `unified_dsl` is rejected before compilation
- AC-004: Broken screen/binding relationships surface clear errors

### REQ-SCREEN-010: Observability

Screens MUST emit lifecycle telemetry.

**Acceptance Criteria**:
- AC-001: Mount events include screen identity
- AC-002: Update events include runtime context
- AC-003: Error events include screen context
- AC-004: Events follow the shared telemetry schema

## Implementation Note

The old `ui_screen` DSL direction has been superseded in this repository by persisted screen records plus `unified_dsl`. Lifecycle is currently implemented primarily through LiveView runtime helpers rather than screen resource actions.

## Traceability

| Requirement | Component Spec | Scenarios |
|---|---|---|
| REQ-SCREEN-001 | resources/ui_screen.md | SCN-004 |
| REQ-SCREEN-002 | phase-04-runtime-and-liveview-integration.md | SCN-021, SCN-022, SCN-023 |
| REQ-SCREEN-003 | resources/ui_screen.md | SCN-005 |
| REQ-SCREEN-004 | resources/ui_binding.md | SCN-006, SCN-007 |
| REQ-SCREEN-005 | resources/ui_screen.md | SCN-004 |
| REQ-SCREEN-006 | phase-04-runtime-and-liveview-integration.md | SCN-024, SCN-025 |
| REQ-SCREEN-007 | phase-04-runtime-and-liveview-integration.md | SCN-021 |
| REQ-SCREEN-008 | authorization_contract.md | SCN-081 |
| REQ-SCREEN-009 | compilation_contract.md | SCN-042 |
| REQ-SCREEN-010 | observability_contract.md | SCN-105 |

## Conformance

See [spec_conformance_matrix.md](../conformance/spec_conformance_matrix.md) for the current scenario coverage baseline.

## Related Specifications

- [resource_contract.md](resource_contract.md)
- [binding_contract.md](binding_contract.md)
- [../resources/ui_screen.md](../resources/ui_screen.md)
- [../planning/phase-04-runtime-and-liveview-integration.md](../planning/phase-04-runtime-and-liveview-integration.md)
