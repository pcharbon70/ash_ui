# UG-0003: Data Binding in Ash UI

---
id: UG-0003
title: Data Binding in Ash UI
audience: Application Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-BIND-001, REQ-BIND-002, REQ-BIND-003, REQ-BIND-007, REQ-BIND-008, REQ-BIND-010]
related_scns: [SCN-006, SCN-007, SCN-009, SCN-010, SCN-021, SCN-101]
related_guides: [UG-0001, UG-0002, UG-0004, DG-0003]
diagram_required: false
---

## Overview

This guide explains how Ash UI bindings work today, how to shape `source` and `target` values, and how runtime helpers read, write, and execute those bindings.

## Prerequisites

Before reading this guide, you should:

- Have read [UG-0001: Getting Started](./UG-0001-getting-started.md)
- Understand the resource model from [UG-0002](./UG-0002-resources.md)
- Be familiar with LiveView events and assigns

## Binding Types

Ash UI supports three binding types:

- `:value`: a single value for display or form state
- `:list`: a collection-oriented binding
- `:action`: an event-to-action binding

These are stored in `AshUI.Resources.Binding.binding_type`.

## Binding Shape

A binding record minimally needs:

```elixir
%{
  screen_id: screen.id,
  element_id: element.id,
  binding_type: :value,
  target: "value",
  source: %{"resource" => "User", "field" => "name", "id" => "user-1"}
}
```

Important rules:

- `source` is a map, not a dot-separated string
- `target` is a short renderer-facing target such as `"value"` or `"submit"`
- `transform` may be a list of transformation maps

## Value Bindings

Use `:value` when a field should be read into UI state and potentially written back.

```elixir
{:ok, _binding} =
  AshUI.Domain.create(AshUI.Resources.Binding,
    attrs: %{
      screen_id: screen.id,
      element_id: name_input.id,
      binding_type: :value,
      target: "value",
      source: %{"resource" => "User", "field" => "name", "id" => "user-1"},
      transform: [
        %{"function" => "trim"},
        %{"function" => "default", "args" => ["Anonymous"]}
      ]
    }
  )
```

Evaluate a value binding:

```elixir
context = %{user_id: "user-1", params: %{}, assigns: %{}}
{:ok, value} = AshUI.Runtime.BindingEvaluator.evaluate(binding, context)
```

## List Bindings

Use `:list` when the element expects a collection.

```elixir
{:ok, _binding} =
  AshUI.Domain.create(AshUI.Resources.Binding,
    attrs: %{
      screen_id: screen.id,
      element_id: audit_list.id,
      binding_type: :list,
      target: "items",
      source: %{"resource" => "AuditLog", "relationship" => "entries"}
    }
  )
```

In the current runtime, list bindings follow the same evaluation path as value bindings. Keep the source map clear enough that renderer and authorization code can reason about it.

## Action Bindings

Use `:action` when the UI should trigger an Ash-side operation.

```elixir
{:ok, _binding} =
  AshUI.Domain.create(AshUI.Resources.Binding,
    attrs: %{
      screen_id: screen.id,
      element_id: save_button.id,
      binding_type: :action,
      target: "submit",
      source: %{"resource" => "Profile", "action" => "save"},
      transform: %{
        "params" => %{
          "display_name" => {"event", "display_name"},
          "actor_id" => {"context", "user_id"}
        }
      }
    }
  )
```

Execute an action binding:

```elixir
context = %{user_id: "user-1", params: %{}, assigns: %{}}
event_data = %{"display_name" => "Pascal"}

{:ok, result} = AshUI.Runtime.ActionBinding.execute_action(binding, event_data, context)
```

## Writing Back to Resources

Bidirectional updates go through `AshUI.Runtime.BidirectionalBinding`.

```elixir
context = %{user_id: "user-1", params: %{}, assigns: %{}}

{:ok, socket, result} =
  AshUI.Runtime.BidirectionalBinding.write_binding(binding, "Updated Name", socket, context)
```

The current implementation returns mock update results, but the call shape is the one LiveView integration already uses.

## Event Handling in LiveView

Event helpers look up bindings in `socket.assigns[:ash_ui_bindings]`.

```elixir
def handle_event("ash_ui_change", params, socket) do
  AshUI.LiveView.EventHandler.handle_value_change(params, socket)
end

def handle_event("ash_ui_action", params, socket) do
  AshUI.LiveView.EventHandler.handle_action_event(params, socket)
end
```

For these handlers to work smoothly:

- keep `target` values stable
- assign `:ash_ui_user` and `:ash_ui_bindings`
- mount through `AshUI.LiveView.Integration`

## Telemetry

Bindings emit canonical telemetry events during evaluation and updates:

- `[:ash_ui, :binding, :evaluate]`
- `[:ash_ui, :binding, :update]`
- `[:ash_ui, :binding, :error]`

You can inspect the aggregated metrics snapshot with:

```elixir
AshUI.Telemetry.snapshot()
```

## Troubleshooting Patterns

### `{:error, {:invalid_source, source}}`

Your `source` is not a map in the expected shape.

### Empty or placeholder values

The runtime currently resolves resource data through placeholder loaders in some paths. Verify the binding shape first before assuming the renderer is broken.

### Writes fail with forbidden errors

Check the current user, active status, and the authorization rules around the binding source.

## See Also

- [UG-0002: Working with Ash UI Resources](./UG-0002-resources.md)
- [UG-0004: Authorization](./UG-0004-authorization.md)
- [binding_contract.md](../../specs/contracts/binding_contract.md)
- [observability_contract.md](../../specs/contracts/observability_contract.md)
