# UG-0005: Migration Guide from v0 to v1

---
id: UG-0005
title: Migration Guide from v0 to v1
audience: Application Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-RES-001, REQ-COMP-001, REQ-RENDER-001, REQ-AUTH-002]
related_scns: [SCN-004, SCN-041, SCN-061, SCN-081]
related_guides: [UG-0001, UG-0002, UG-0003, DG-0004]
diagram_required: false
---

## Overview

This guide helps teams move from the earlier Ash UI direction, where examples centered on standalone `ui_screen` and `ui_element` resource DSL definitions, to the current v1 shape implemented in this repository.

## Prerequisites

Before reading this guide, you should:

- Know which Ash UI examples or prototypes your app copied from
- Be comfortable updating Elixir modules and persisted records
- Have read [UG-0001: Getting Started](./UG-0001-getting-started.md)

## What Changed in v1

The biggest changes are:

- screens are now stored in `AshUI.Resources.Screen`
- screen structure is centered on `Screen.unified_dsl`
- the main compiler entry point is `AshUI.Compiler`
- LiveView integration goes through `AshUI.LiveView.Integration`
- authorization and telemetry are now first-class runtime concerns

## Old to New Mapping

| v0 style | v1 style |
|---|---|
| ad-hoc `ui_screen` examples in app resources | persisted `AshUI.Resources.Screen` records |
| string-based binding examples | map-based `source` values |
| direct rendering assumptions | compile to Ash IUR, then convert to canonical IUR |
| implicit test/dev auth bypass | explicit `:runtime_authorization_bypass` config |

## Step 1: Move Screen Definitions into Records

If you previously modeled screens as custom resources in your app, migrate the useful parts into `AshUI.Resources.Screen` rows.

```elixir
alias AshUI.DSL.Builder
alias AshUI.Data, as: Domain
alias AshUI.Resources.Screen

{:ok, _screen} =
  Domain.create(Screen,
    attrs: %{
      name: "dashboard",
      route: "/dashboard",
      layout: :column,
      unified_dsl:
        Builder.column(
          children: [
            Builder.text("Dashboard"),
            Builder.button("Refresh", on_click: "refresh-dashboard")
          ]
        )
        |> Builder.to_store()
    }
  )
```

## Step 2: Normalize Binding Sources

Replace older source strings like `"User.name"` or `"MyApp.User.create"` with explicit source maps.

Before:

```elixir
%{source: "User.name"}
```

After:

```elixir
%{source: %{"resource" => "User", "field" => "name"}}
```

Action example:

```elixir
%{source: %{"resource" => "User", "action" => "save"}}
```

## Step 3: Update LiveView Mounts

Replace placeholder helpers like `mount_ui_screen/3` from older docs with the real integration module.

```elixir
alias AshUI.LiveView.Integration

def mount(_params, _session, socket) do
  socket = assign(socket, :current_user, %{id: "admin-1", role: :admin, active: true})
  Integration.mount_ui_screen(socket, :dashboard, %{})
end
```

## Step 4: Expect Canonical IUR at the Boundary

In v1, the stable renderer boundary is canonical IUR. If you had custom rendering hooks that expected raw resource structs, move them to consume:

- `AshUI.Compilation.IUR` internally
- canonical maps produced by `AshUI.Rendering.IURAdapter`

## Step 5: Revisit Authorization Assumptions

If earlier prototypes relied on tests or development mode implicitly allowing access, switch to explicit user data and explicit bypass configuration when needed.

```elixir
config :ash_ui, :runtime_authorization_bypass, false
```

## Step 6: Validate the Migration

Run focused verification after moving each screen:

```bash
mix test test/ash_ui/compiler_test.exs
mix test test/ash_ui/liveview/liveview_integration_test.exs
mix test test/ash_ui/authorization/runtime_test.exs
```

## Migration Checklist

- move screen definitions into `AshUI.Resources.Screen`
- convert binding sources to maps
- use `AshUI.DSL.Builder` for stored `unified_dsl`
- mount via `AshUI.LiveView.Integration`
- verify `:current_user` is assigned
- confirm telemetry and authorization behavior in the target environment

## See Also

- [UG-0001: Getting Started](./UG-0001-getting-started.md)
- [UG-0003: Data Binding](./UG-0003-data-binding.md)
- [DG-0004: Release Process](../developer/DG-0004-release-process.md)
- [phase-08-governance-gates-and-release-readiness.md](../../specs/planning/phase-08-governance-gates-and-release-readiness.md)
