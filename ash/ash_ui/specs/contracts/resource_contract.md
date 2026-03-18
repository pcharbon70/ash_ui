# Resource Contract (REQ-RES-*)

This contract defines the normative requirements for Ash Resource definitions in the Ash UI framework.

## Purpose

Defines the requirements for UI resource definitions (UI.Element, UI.Screen, UI.Binding) within the Ash Framework, ensuring consistent structure, validation, and behavior across all UI components.

## Control Plane

**Owner**: `AshUI.Framework` (Framework Control Plane)

## Dependencies

- Ash Framework (Core, API, JsonApi)
- Ecto
- Phoenix LiveView

## Requirements

### REQ-RES-001: Resource Definition

All UI resources MUST be defined using Ash DSL extensions.

```elixir
defmodule AshUI.Resources.Element do
  use Ash.Resource,
    domain: AshUI.Domain,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :type, :atom, constraints: [one_of: [:button, :input, :text, ...]]
    attribute :props, :map, default: %{}
  end
end
```

**Acceptance Criteria**:
- AC-001: All resources use `use Ash.Resource`
- AC-002: All resources specify a domain
- AC-003: All resources specify a data layer

### REQ-RES-002: Type Safety

All resource attributes MUST have explicitly defined types.

**Rationale**: Type safety prevents runtime errors and enables compile-time validation.

**Acceptance Criteria**:
- AC-001: Every attribute has a defined type
- AC-002: Complex types use Ash.Type modules
- AC-003: Constraints are specified where applicable

### REQ-RES-003: Relationship Definition

Resource relationships MUST use standard Ash relationship DSL.

**Acceptance Criteria**:
- AC-001: Relationships use `has_one`, `has_many`, or `belongs_to`
- AC-002: Relationship names are plural for collections
- AC-003: Foreign key attributes are explicitly defined

### REQ-RES-004: Action Definition

Resources MUST define standard Ash actions.

**Acceptance Criteria**:
- AC-001: Primary read action is named `:read`
- AC-002: Primary create action is named `:create`
- AC-003: Primary update action is named `:update`
- AC-004: Primary destroy action is named `:destroy`

### REQ-RES-005: Validation

Resources MUST define validation rules using Ash validations.

**Acceptance Criteria**:
- AC-001: Required attributes have `allow_nil?: false`
- AC-002: Custom validations use `validate` or `change`
- AC-003: Validation errors include user-friendly messages

### REQ-RES-006: Authorization

All resource actions MUST be authorizable through Ash Policies.

**Acceptance Criteria**:
- AC-001: Resources define `authorizers: [Ash.Policy.Authorizer]`
- AC-002: Policies exist for all actions
- AC-003: Policy failures result in clear error messages

### REQ-RES-007: Metadata

Resources MUST include standard metadata attributes.

**Acceptance Criteria**:
- AC-001: Resources have `created_at` timestamp
- AC-002: Resources have `updated_at` timestamp
- AC-003: Resources have `version` attribute for optimistic locking

### REQ-RES-008: Extensions

Resources MAY include extensions for additional behavior.

**Acceptance Criteria**:
- AC-001: Extensions are declared in the resource DSL
- AC-002: Extension behavior is documented
- AC-003: Extensions don't violate core resource contracts

## Resource Types

### UI.Element (REQ-RES-ELEMENT)

Atomic UI component with no children.

**Attributes**:
- `id`: UUID primary key
- `type`: Atom (component type identifier)
- `props`: Map (component properties)
- `variants`: List of atom (variant identifiers)
- `metadata`: Map (additional metadata)

**Actions**:
- `read`: Query elements
- `create`: Create new element
- `update`: Update element properties
- `destroy`: Remove element

**Relationships**:
- `belongs_to :screen` - Parent screen
- `has_many :bindings` - Associated bindings

### UI.Screen (REQ-RES-SCREEN)

Composable UI container representing a page or view.

**Attributes**:
- `id`: UUID primary key
- `name`: String (screen identifier)
- `layout`: Atom (layout type)
- `metadata`: Map (screen metadata)
- `lifecycle_state`: Atom (state tracking)

**Actions**:
- `read`: Query screens
- `create`: Create new screen
- `update`: Update screen definition
- `destroy`: Remove screen
- `mount`: Lifecycle action for screen initialization
- `unmount`: Lifecycle action for screen cleanup

**Relationships**:
- `has_many :elements` - Child elements
- `has_many :bindings` - Associated bindings

### UI.Binding (REQ-RES-BINDING)

Data binding connecting UI elements to Ash resources.

**Attributes**:
- `id`: UUID primary key
- `source`: String (resource path)
- `target`: String (element property)
- `binding_type`: Atom (:value, :list, :action)
- `transform`: Map (transformation rules)

**Actions**:
- `read`: Query bindings
- `create`: Create new binding
- `update`: Update binding configuration
- `destroy`: Remove binding
- `evaluate`: Evaluate binding against resource data

**Relationships**:
- `belongs_to :element` - Associated element
- `belongs_to :screen` - Parent screen

## Traceability

| Requirement | ADR | Component Spec | Scenarios |
|---|---|---|---|
| REQ-RES-001 | ADR-0001 | resources/ui_element.md | SCN-001, SCN-002 |
| REQ-RES-002 | ADR-0001 | resources/ui_element.md | SCN-003 |
| REQ-RES-003 | ADR-0002 | resources/ui_screen.md | SCN-004, SCN-005 |
| REQ-RES-004 | - | resources/ui_binding.md | SCN-006 |
| REQ-RES-005 | - | compilation/validator.md | SCN-007 |
| REQ-RES-006 | ADR-0003 | authorization_contract.md | SCN-008, SCN-009 |
| REQ-RES-007 | - | - | SCN-010 |
| REQ-RES-008 | ADR-0004 | extension_contract.md | SCN-011 |

## Conformance

See [conformance/spec_conformance_matrix.md](../conformance/spec_conformance_matrix.md) for complete scenario mappings.

## Related Specifications

- [topology.md](../topology.md)
- [screen_contract.md](screen_contract.md)
- [binding_contract.md](binding_contract.md)
- [compilation_contract.md](compilation_contract.md)
