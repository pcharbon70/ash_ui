# Resource Contract (REQ-RES-*)

This contract defines the normative requirements for Ash UI resource definitions.

## Purpose

Ash UI stores durable UI state as Ash resources. This contract covers the resource-backed model implemented in this repository: `AshUI.Resources.Screen`, `AshUI.Resources.Element`, and `AshUI.Resources.Binding`.

## Control Plane

**Owner**: `AshUI.Framework`

## Dependencies

- Ash Framework
- AshPostgres
- Phoenix LiveView

## Requirements

### REQ-RES-001: Resource Definition

All core UI resources MUST be defined using `Ash.Resource`, registered in `AshUI.Domain`, and backed by a persistent data layer.

**Acceptance Criteria**:
- AC-001: Resources use `use Ash.Resource`
- AC-002: Resources specify `domain: AshUI.Domain`
- AC-003: Resources specify a persistent data layer

### REQ-RES-002: Type Safety

All persisted attributes MUST have explicit Ash types and constraints where needed.

**Acceptance Criteria**:
- AC-001: Every persisted attribute declares a type
- AC-002: Enum-like fields use constraints or documented value sets
- AC-003: Complex fields such as `props`, `metadata`, and `unified_dsl` use structured map types

### REQ-RES-003: Relationship Definition

Resource relationships MUST use standard Ash relationship DSL and reflect the screen/element/binding hierarchy.

**Acceptance Criteria**:
- AC-001: `Screen` has relationships to `Element` and `Binding`
- AC-002: `Element` belongs to `Screen` and has relationships to `Binding`
- AC-003: Foreign-key ownership is explicit in the resource definitions

### REQ-RES-004: Action Definition

Resources MUST expose baseline CRUD actions appropriate to their role in the system.

**Acceptance Criteria**:
- AC-001: `Screen`, `Element`, and `Binding` expose `:read`
- AC-002: Mutable resources expose primary `:create` and `:update`
- AC-003: Destructive operations are explicit and documented
- AC-004: Supplemental read actions and filtered reads are allowed

### REQ-RES-005: Validation

Resources MUST validate required attributes and structural invariants before persistence.

**Acceptance Criteria**:
- AC-001: Required attributes use `allow_nil?: false`
- AC-002: Resource-specific invariants are enforced through changes or validation helpers
- AC-003: Invalid data returns descriptive Ash errors

### REQ-RES-006: Authorization Boundary

Resources MUST participate in the authorization model, either through resource-level Ash policies or an explicit runtime authorization boundary.

**Acceptance Criteria**:
- AC-001: Access to screens, elements, and bindings is not implicitly unrestricted in production flows
- AC-002: The active authorization path is documented
- AC-003: Policy or runtime authorization failures are surfaced clearly

**Implementation Note**:
The current repository primarily enforces authorization through runtime helpers. Full resource-level `Ash.Policy.Authorizer` wiring is still being completed.

### REQ-RES-007: Metadata and Versioning

Resources MUST include timestamps and version metadata needed for cache invalidation and rollout safety.

**Acceptance Criteria**:
- AC-001: Resources have created and updated timestamps
- AC-002: Resources expose a `version` attribute
- AC-003: Version changes are available to compilation and rollout logic

### REQ-RES-008: Extensions

Resources MAY expose extension points or companion helpers so the compiler and runtime can layer behavior on top of persisted records.

**Acceptance Criteria**:
- AC-001: Extension behavior is documented when present
- AC-002: Extension hooks do not break the core resource schema
- AC-003: Custom behavior respects the same validation and authorization boundaries

## Resource Types

### UI.Element

Atomic renderer-facing component or layout node stored as a record.

**Attributes**:
- `id`: UUID primary key
- `type`: atom component identifier
- `props`: renderer-facing properties map
- `variants`: list of atoms
- `position`: integer ordering value
- `metadata`: map
- `active`: boolean
- `version`: integer

**Actions**:
- `read`
- `create`
- `update`
- `destroy`

**Relationships**:
- `belongs_to :screen`
- `has_many :bindings`

### UI.Screen

Top-level screen record that stores the durable `unified_dsl` tree and screen metadata.

**Attributes**:
- `id`: UUID primary key
- `name`: unique screen identifier
- `unified_dsl`: persisted screen tree
- `layout`: layout hint
- `route`: optional route
- `metadata`: map
- `active`: boolean
- `version`: integer

**Actions**:
- `read`
- `create`
- `update`
- `destroy`

**Relationships**:
- `has_many :elements`
- `has_many :bindings`

### UI.Binding

Binding record connecting runtime UI targets to Ash-side data or actions.

**Attributes**:
- `id`: UUID primary key
- `source`: structured map describing resource, field, relationship, or action
- `target`: renderer-facing target string such as `value`, `items`, or `submit`
- `binding_type`: atom in `[:value, :list, :action]`
- `transform`: map or ordered transform configuration
- `metadata`: map
- `active`: boolean
- `version`: integer

**Actions**:
- `read`
- `create`
- `update`
- `destroy`
- filtered read actions are allowed

**Relationships**:
- `belongs_to :element`
- `belongs_to :screen`

## Traceability

| Requirement | ADR | Component Spec | Scenarios |
|---|---|---|---|
| REQ-RES-001 | ADR-0001 | resources/ui_element.md, resources/ui_screen.md, resources/ui_binding.md | SCN-001, SCN-004, SCN-006 |
| REQ-RES-002 | ADR-0001 | resources/ui_element.md, resources/ui_screen.md, resources/ui_binding.md | SCN-002 |
| REQ-RES-003 | ADR-0001 | resources/ui_element.md, resources/ui_screen.md, resources/ui_binding.md | SCN-003, SCN-005 |
| REQ-RES-004 | ADR-0001 | resources/ui_screen.md, resources/ui_binding.md | SCN-004, SCN-006 |
| REQ-RES-005 | - | compilation/validator.md | SCN-007 |
| REQ-RES-006 | ADR-0001 | authorization_contract.md | SCN-081, SCN-084 |
| REQ-RES-007 | ADR-0001 | resources/ui_screen.md, resources/ui_element.md, resources/ui_binding.md | SCN-010 |
| REQ-RES-008 | - | - | - |

## Conformance

See [spec_conformance_matrix.md](../conformance/spec_conformance_matrix.md) for the current coverage baseline.

## Related Specifications

- [topology.md](../topology.md)
- [screen_contract.md](screen_contract.md)
- [binding_contract.md](binding_contract.md)
- [../resources/README.md](../resources/README.md)
