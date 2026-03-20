# UG-0002: Working with Ash UI Resources

---
id: UG-0002
title: Working with Ash UI Resources
audience: Application Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-RES-001, REQ-RES-003, REQ-RES-004, REQ-RES-007]
related_scns: [SCN-001, SCN-003, SCN-004, SCN-005]
related_guides: [UG-0001, UG-0003, UG-0004]
diagram_required: false
---

## Overview

This guide explains the three Ash UI resources you work with directly: screens, elements, and bindings. It focuses on the current data model implemented in `AshUI.Domain`.

## Prerequisites

Before reading this guide, you should:

- Know how to create and query Ash resources
- Have read [UG-0001: Getting Started](./UG-0001-getting-started.md)
- Be able to run migrations for your application database

## The Core Resources

Ash UI stores UI state as regular Ash records:

- `AshUI.Resources.Screen`
- `AshUI.Resources.Element`
- `AshUI.Resources.Binding`

The shared domain is `AshUI.Domain`, so reads and writes typically go through that module.

## Screen Records

`AshUI.Resources.Screen` is the top-level container.

Important fields:

- `name`: unique identifier used by LiveView integration
- `unified_dsl`: stored screen tree for compiler-driven screens
- `layout`: layout hint such as `:column` or `:row`
- `route`: optional route string
- `metadata`: free-form metadata
- `active`: soft enablement flag
- `version`: incremented on update

Create a screen:

```elixir
alias AshUI.Data, as: Domain
alias AshUI.Resources.Screen

{:ok, screen} =
  Domain.create(Screen,
    attrs: %{
      name: "settings",
      route: "/settings",
      layout: :column,
      unified_dsl: %{"type" => "column", "children" => []},
      metadata: %{"title" => "Settings"}
    }
  )
```

Read a screen by name:

```elixir
{:ok, screen} = Domain.read_one(Screen, filter: [name: "settings"])
```

## Element Records

`AshUI.Resources.Element` holds atomic UI pieces associated with a screen.

Important fields:

- `type`: widget or layout type such as `:text`, `:button`, or `:textinput`
- `props`: renderer-facing properties
- `variants`: style or behavior variants
- `position`: ordering value inside a screen
- `screen_id`: parent screen relationship

Create two elements for a screen:

```elixir
alias AshUI.Resources.Element

{:ok, header} =
  Domain.create(Element,
    attrs: %{
      screen_id: screen.id,
      type: :text,
      props: %{"content" => "Settings", "size" => 24},
      position: 0
    }
  )

{:ok, save_button} =
  Domain.create(Element,
    attrs: %{
      screen_id: screen.id,
      type: :button,
      props: %{"label" => "Save"},
      variants: [:primary],
      position: 1
    }
  )
```

## Binding Records

`AshUI.Resources.Binding` connects resources and UI targets.

Important fields:

- `source`: map describing the backing resource field or action
- `target`: target property or event name
- `binding_type`: one of `:value`, `:list`, or `:action`
- `transform`: optional transformation rules
- `element_id`: optional link to an element
- `screen_id`: parent screen

Create a value binding and an action binding:

```elixir
alias AshUI.Resources.Binding

{:ok, _name_binding} =
  Domain.create(Binding,
    attrs: %{
      screen_id: screen.id,
      element_id: header.id,
      binding_type: :value,
      target: "content",
      source: %{"resource" => "User", "field" => "name", "id" => "user-1"}
    }
  )

{:ok, _save_binding} =
  Domain.create(Binding,
    attrs: %{
      screen_id: screen.id,
      element_id: save_button.id,
      binding_type: :action,
      target: "submit",
      source: %{"resource" => "User", "action" => "save"}
    }
  )
```

## Relationship Patterns

The current resource relationships are:

- Screen `has_many :elements`
- Screen `has_many :bindings`
- Element `belongs_to :screen`
- Element `has_many :bindings`
- Binding `belongs_to :screen`
- Binding `belongs_to :element`

This gives you two workable patterns:

1. Put all structure in `Screen.unified_dsl` and use bindings for dynamic behavior.
2. Keep explicit `Element` and `Binding` records for relational querying and incremental composition.

Many current flows use both.

## Versioning and Updates

All three resources increment `version` on update. That matters for:

- compiler cache invalidation
- change tracking
- release-readiness checks

Example update:

```elixir
{:ok, updated_screen} =
  Domain.update(screen,
    attrs: %{
      metadata: Map.put(screen.metadata, "title", "Settings and Profile")
    }
  )
```

## Querying Active Records

Bindings include a `read_with_filter` action that only returns active records. For simple application code, using the domain with a filter keeps intent explicit:

```elixir
active_bindings = Domain.read!(AshUI.Resources.Binding, filter: [screen_id: screen.id, active: true])
```

## Practical Modeling Advice

- Use `name` as the stable human-facing screen identifier.
- Use `unified_dsl` for nested layout structure that would be awkward to model only with rows in SQL.
- Keep `props` renderer-neutral where possible.
- Treat `metadata` as optional annotations, not core behavior.
- Keep binding `source` maps explicit so authorization and runtime code can inspect them safely.

## See Also

- [UG-0001: Getting Started](./UG-0001-getting-started.md)
- [UG-0003: Data Binding](./UG-0003-data-binding.md)
- [UG-0004: Authorization](./UG-0004-authorization.md)
- [resource_contract.md](../../specs/contracts/resource_contract.md)
