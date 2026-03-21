# Binding Contract (REQ-BIND-*)

This contract defines the normative requirements for binding semantics in Ash UI.

## Purpose

Bindings connect persisted UI definitions to Ash-side data, collections, and actions. They are evaluated at runtime and translated into renderer-facing state and events.

## Control Plane

**Owner**: `AshUI.Framework`

## Dependencies

- REQ-RES-*: resource definitions
- REQ-SCREEN-*: screen runtime context
- REQ-COMP-*: compilation and validation

## Requirements

### REQ-BIND-001: Binding Definition

All bindings MUST be persisted as `AshUI.Resources.Binding` records.

```elixir
attributes do
  uuid_primary_key :id
  attribute :source, :map, allow_nil?: false, default: %{}
  attribute :target, :string, allow_nil?: false
  attribute :binding_type, :atom, constraints: [one_of: [:value, :list, :action]]
  attribute :transform, :map, default: %{}
  attribute :metadata, :map, default: %{}
end
```

**Acceptance Criteria**:
- AC-001: Bindings use `Ash.Resource`
- AC-002: Bindings persist structured `source` and `target` values
- AC-003: Bindings declare a supported `binding_type`
- AC-004: Bindings are associated with a screen and optionally an element

### REQ-BIND-002: Binding Types

Bindings MUST support three fundamental types.

1. `:value`
2. `:list`
3. `:action`

**Acceptance Criteria**:
- AC-001: Unknown binding types are rejected
- AC-002: Each type has distinct runtime semantics
- AC-003: Type-specific validation is documented

### REQ-BIND-003: Source Resolution

Bindings MUST resolve a structured `source` map into Ash-side reads, collections, or actions.

**Supported Shapes**:
- value source: `%{"resource" => "User", "field" => "name", "id" => "user-1"}`
- list source: `%{"resource" => "AuditLog", "relationship" => "entries"}`
- action source: `%{"resource" => "Profile", "action" => "save"}`

**Acceptance Criteria**:
- AC-001: Source maps are validated before evaluation
- AC-002: Invalid source shapes produce clear errors
- AC-003: Relationship and nested traversal semantics are defined
- AC-004: Source resolution honors authorization context

### REQ-BIND-004: Target Binding

Bindings MUST bind to renderer-facing targets understood by the runtime and adapters.

**Common Targets**:
- `value`
- `items`
- `submit`
- `content`

**Acceptance Criteria**:
- AC-001: Targets are validated against the bound element or runtime flow
- AC-002: Invalid targets produce descriptive errors
- AC-003: Target coercion rules are documented where allowed
- AC-004: Target names remain stable across renderer adapters

### REQ-BIND-005: Transformation

Bindings MAY include ordered transformation rules.

**Common Transform Types**:
- `format`
- `compute`
- `validate`
- `default`

**Acceptance Criteria**:
- AC-001: Transformations are declared in persisted binding data
- AC-002: Transformations run in a defined order
- AC-003: Transformation failures surface to the runtime
- AC-004: Transformations do not silently violate type expectations

### REQ-BIND-006: Reactivity

Bindings MUST support re-evaluation when their source data changes.

**Acceptance Criteria**:
- AC-001: Source changes trigger binding re-evaluation
- AC-002: Re-evaluation updates screen or element state
- AC-003: Update propagation can be batched
- AC-004: Failed re-evaluations do not permanently stall new updates

### REQ-BIND-007: Bidirectional Updates

`:value` bindings MUST support the UI-to-resource write path.

**Acceptance Criteria**:
- AC-001: User input can write back to the bound resource
- AC-002: Authorization is checked before writes
- AC-003: Validation and conflict failures are surfaced clearly
- AC-004: Successful writes update runtime state

### REQ-BIND-008: Action Execution

`:action` bindings MUST execute Ash-side actions when triggered.

**Acceptance Criteria**:
- AC-001: Event payloads are mapped into action params
- AC-002: Authorization is checked before execution
- AC-003: Action results can update UI state
- AC-004: Action errors are surfaced to the user

### REQ-BIND-009: Validation

Bindings MUST validate persisted configuration and runtime input.

**Acceptance Criteria**:
- AC-001: Required binding attributes are enforced
- AC-002: Source and target shapes are validated
- AC-003: Transformation definitions are validated
- AC-004: Runtime validation errors remain user-friendly

### REQ-BIND-010: Observability

Bindings MUST emit telemetry events for evaluation, update, and error flows.

**Acceptance Criteria**:
- AC-001: Evaluation events include binding identity and target
- AC-002: Update events include result context
- AC-003: Error events include binding context
- AC-004: Events follow the shared telemetry schema

## Implementation Note

The repository currently exposes the binding APIs and telemetry surface described here, but some read, write, list, and action paths are still backed by placeholder implementations. This contract describes the intended real Ash-backed behavior that the reopened Phase 3 and Phase 4 work will complete.

## Traceability

| Requirement | Component Spec | Scenarios |
|---|---|---|
| REQ-BIND-001 | resources/ui_binding.md | SCN-006 |
| REQ-BIND-002 | resources/ui_binding.md | SCN-007, SCN-008, SCN-009 |
| REQ-BIND-003 | resources/ui_binding.md | SCN-010 |
| REQ-BIND-004 | resources/ui_binding.md | SCN-006 |
| REQ-BIND-005 | resources/ui_binding.md | SCN-010 |
| REQ-BIND-006 | phase-03-data-binding-and-signal-mapping.md | SCN-007 |
| REQ-BIND-007 | phase-03-data-binding-and-signal-mapping.md | SCN-007 |
| REQ-BIND-008 | phase-03-data-binding-and-signal-mapping.md | SCN-009 |
| REQ-BIND-009 | compilation_contract.md | SCN-042 |
| REQ-BIND-010 | observability_contract.md | SCN-101 |

## Conformance

See [spec_conformance_matrix.md](../conformance/spec_conformance_matrix.md) for the current scenario coverage baseline.

## Related Specifications

- [resource_contract.md](resource_contract.md)
- [screen_contract.md](screen_contract.md)
- [../resources/ui_binding.md](../resources/ui_binding.md)
- [../planning/phase-03-data-binding-and-signal-mapping.md](../planning/phase-03-data-binding-and-signal-mapping.md)
