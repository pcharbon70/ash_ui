# Ash UI Resources

This directory contains component specs for the persisted Ash UI resource model used in this repository.

## Resource Types

### UI.Screen

**Module**: `AshUI.Resources.Screen`

**Purpose**: top-level durable screen record storing `unified_dsl`, route metadata, and relationships to elements and bindings.

**Key Attributes**:
- `id`
- `name`
- `unified_dsl`
- `layout`
- `route`
- `metadata`
- `active`
- `version`

**Actions**:
- `read`
- `create`
- `update`
- `destroy`

**Relationships**:
- `has_many :elements`
- `has_many :bindings`

**Specification**: [ui_screen.md](./ui_screen.md)

### UI.Element

**Module**: `AshUI.Resources.Element`

**Purpose**: persisted renderer-facing component record for relational querying and incremental composition.

**Key Attributes**:
- `id`
- `type`
- `props`
- `variants`
- `position`
- `metadata`
- `active`
- `version`

**Actions**:
- `read`
- `create`
- `update`
- `destroy`

**Relationships**:
- `belongs_to :screen`
- `has_many :bindings`

**Specification**: [ui_element.md](./ui_element.md)

### UI.Binding

**Module**: `AshUI.Resources.Binding`

**Purpose**: persisted binding record that connects runtime UI targets to Ash-side data, lists, and actions.

**Key Attributes**:
- `id`
- `source`
- `target`
- `binding_type`
- `transform`
- `metadata`
- `active`
- `version`

**Actions**:
- `read`
- `create`
- `update`
- `destroy`
- filtered reads where needed

**Relationships**:
- `belongs_to :element`
- `belongs_to :screen`

**Specification**: [ui_binding.md](./ui_binding.md)

## Related Specifications

- [resource_contract.md](../contracts/resource_contract.md)
- [screen_contract.md](../contracts/screen_contract.md)
- [binding_contract.md](../contracts/binding_contract.md)
