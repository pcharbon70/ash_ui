# UG-0001: Getting Started with Ash UI

---
id: UG-0001
title: Getting Started with Ash UI
audience: Application Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-RES-001, REQ-SCREEN-001, REQ-COMP-001, REQ-RENDER-001]
related_scns: [SCN-004, SCN-021, SCN-041, SCN-061]
related_guides: [UG-0002, UG-0003, UG-0004, DG-0001]
diagram_required: true
---

## Overview

This guide shows the shortest realistic path to getting Ash UI running in an application today. The current system centers on three Ash resources, a stored `unified_dsl` screen definition, a compiler that produces Ash UI IUR, and adapters that convert that IUR into canonical renderer input.

## Prerequisites

Before reading this guide, you should:

- Be comfortable with Elixir and Mix
- Have a Phoenix application with LiveView enabled
- Understand basic Ash resource and domain concepts
- Have read your app's database and repo setup docs

## How Ash UI Flows

The most important thing to understand is that Ash UI stores screen definitions as Ash data, then compiles and adapts them at runtime.

```mermaid
flowchart LR
    Screen["AshUI.Resources.Screen"]
    DSL["stored unified_dsl"]
    Compiler["AshUI.Compiler"]
    IUR["Ash UI IUR"]
    Canonical["canonical IUR"]
    Runtime["AshUI.LiveView.Integration"]

    Screen --> DSL
    DSL --> Compiler
    Compiler --> IUR
    IUR --> Canonical
    Canonical --> Runtime
```

## Install Dependencies

Add Ash UI and the runtime dependencies it uses today:

```elixir
# mix.exs
defp deps do
  [
    {:ash_ui, "~> 0.1.0"},
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},
    {:phoenix_live_view, "~> 1.0"},
    {:telemetry, "~> 1.0"}
  ]
end
```

Fetch dependencies:

```bash
mix deps.get
```

## Create a First Screen

Ash UI ships the core resources for you:

- `AshUI.Resources.Screen`
- `AshUI.Resources.Element`
- `AshUI.Resources.Binding`

For a simple screen, the lowest-friction path is to create a `Screen` record with a `unified_dsl` map built by `AshUI.DSL.Builder`.

```elixir
alias AshUI.DSL.Builder
alias AshUI.Data, as: Domain
alias AshUI.Resources.Screen

dashboard_dsl =
  Builder.column(
    spacing: 16,
    children: [
      Builder.text("Team dashboard", size: 24, weight: :bold),
      Builder.text("Everything below is compiled from stored Ash data."),
      Builder.button("Refresh", on_click: "refresh-dashboard")
    ]
  )
  |> Builder.to_store()

{:ok, screen} =
  Domain.create(Screen,
    attrs: %{
      name: "dashboard",
      route: "/dashboard",
      layout: :column,
      unified_dsl: dashboard_dsl,
      metadata: %{"title" => "Dashboard"}
    }
  )
```

## Mount the Screen in LiveView

`AshUI.LiveView.Integration.mount_ui_screen/3` loads the screen, authorizes it, compiles it, evaluates its bindings, and assigns the result onto the socket.

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  alias AshUI.LiveView.Integration

  def mount(_params, _session, socket) do
    socket = assign(socket, :current_user, %{id: "admin-1", role: :admin, active: true})

    case Integration.mount_ui_screen(socket, :dashboard, %{}) do
      {:ok, socket} -> {:ok, socket}
      {:error, reason} -> {:ok, assign(socket, :ash_ui_error, reason)}
    end
  end
end
```

After mount, these assigns are available:

- `:ash_ui_screen`
- `:ash_ui_iur`
- `:ash_ui_bindings`
- `:ash_ui_user`
- `:ash_ui_loaded_at`

## Inspect or Render the Result

Today Ash UI reliably gives you canonical screen data and fallback renderer adapters. A practical first step is to inspect the assigned IUR while wiring your UI.

```elixir
~H"""
<section>
  <h1>{@ash_ui_screen.name}</h1>
  <pre><%= inspect(@ash_ui_iur, pretty: true) %></pre>
</section>
"""
```

If you want fallback HEEx or HTML output, you can render the compiled structure directly:

```elixir
alias AshUI.Rendering.LiveUIAdapter

{:ok, heex} = LiveUIAdapter.render(@ash_ui_iur)
```

## Add Reactive Bindings

Bindings are separate records. They connect a UI target such as `"value"` or `"submit"` to a source map that identifies a resource field or action.

```elixir
alias AshUI.Data, as: Domain
alias AshUI.Resources.Binding
alias AshUI.Resources.Element

{:ok, input} =
  Domain.create(Element,
    attrs: %{
      screen_id: screen.id,
      type: :textinput,
      props: %{"label" => "Display name"},
      position: 0
    }
  )

{:ok, _binding} =
  Domain.create(Binding,
    attrs: %{
      screen_id: screen.id,
      element_id: input.id,
      binding_type: :value,
      target: "value",
      source: %{"resource" => "User", "field" => "name", "id" => "user-1"},
      transform: [%{"function" => "trim"}]
    }
  )
```

## Handle LiveView Events

Ash UI includes helper modules for value changes and action dispatch:

```elixir
def handle_event("ash_ui_change", params, socket) do
  AshUI.LiveView.EventHandler.handle_value_change(params, socket)
end

def handle_event("ash_ui_action", params, socket) do
  AshUI.LiveView.EventHandler.handle_action_event(params, socket)
end
```

## Common First Checks

### Screen fails to mount

Confirm the socket includes `:current_user`, the user is active, and the screen exists under the requested name or ID.

### Bindings stay empty

Check that:

- The binding belongs to the same `screen_id`
- `binding_type` is one of `:value`, `:list`, or `:action`
- `source` is a map with at least `"resource"` plus `"field"` or `"action"`

### Rendering looks incomplete

That is expected if external renderer packages are not installed. Ash UI currently falls back to adapter-provided output until `live_ui`, `web_ui`, or `desktop_ui` are available.

## See Also

- [UG-0002: Working with Resources](./UG-0002-resources.md)
- [UG-0003: Data Binding](./UG-0003-data-binding.md)
- [UG-0004: Authorization](./UG-0004-authorization.md)
- [DG-0001: Architecture Overview](../developer/DG-0001-architecture-overview.md)
- [README](/Users/Pascal/code/ash/ash_ui/README.md)
