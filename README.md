# Ash UI

A resource-driven UI framework for Elixir built on the Ash Framework, enabling dynamic UI generation from database resources through the unified UI rendering ecosystem.

## Overview

Ash UI provides a declarative approach to building user interfaces by defining UI components as Ash resources. This enables:

- **Database-Driven UI** - Define screens and elements as resources
- **Reactive Data Binding** - Connect UI directly to Ash resources
- **Multi-Platform Rendering** - Output to LiveView, static HTML, or desktop via unified renderer packages
- **Type Safety** - Leverage Ash's type system for UI components
- **Authorization-First** - Built-in policy-based access control

## Architecture

```mermaid
flowchart LR
    subgraph Input["Your Resources"]
        Element["UI.Element"]
        Screen["UI.Screen"]
        Binding["UI.Binding"]
    end

    subgraph AshUI["Ash UI Framework"]
        Compiler["Compiler"]
        IUR["Ash IUR"]
        Adapter["IUR Adapter"]
    end

    subgraph Unified["Unified Ecosystem"]
        Canonical["Canonical IUR"]
    end

    subgraph Renderers["Renderer Packages"]
        Live["live_ui"]
        Web["web_ui"]
        Desktop["desktop_ui"]
    end

    subgraph Output["User Interface"]
        LV["LiveView"]
        HTML["Static HTML"]
        Native["Desktop UI"]
    end

    Element --> Compiler
    Screen --> Compiler
    Binding --> Compiler
    Compiler --> IUR
    IUR --> Adapter
    Adapter --> Canonical
    Canonical --> Live
    Canonical --> Web
    Canonical --> Desktop
    Live --> LV
    Web --> HTML
    Desktop --> Native
```

## Quick Start

### Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ash_ui, "~> 0.1"},
    {:unified_iur, "~> 0.1"},  # Canonical IUR format
    {:live_ui, "~> 0.1"},      # LiveView renderer (or web_ui, desktop_ui)
    {:ash, "~> 3.0"},
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

### Define Your First Screen

```elixir
defmodule MyApp.UI.Dashboard do
  use Ash.Resource,
    domain: MyApp.UI,
    data_layer: AshPostgres.DataLayer

  ui_screen do
    layout :dashboard
    route "/dashboard"
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end
end
```

### Mount in LiveView

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  def mount(params, _session, socket) do
    {:ok, mount_ui_screen(socket, :dashboard, params)}
  end
end
```

The `mount_ui_screen/3` helper handles compilation, IUR conversion, and rendering.

## Documentation

### User Guides

- **[Getting Started](guides/user/UG-0001-getting-started.md)** - Introduction to Ash UI
- **[Resources](guides/user/README.md)** - UI resources overview
- **[Data Binding](guides/user/README.md)** - Reactive data binding

### Developer Guides

- **[Architecture Overview](guides/developer/DG-0001-architecture-overview.md)** - System architecture
- **[Contributing](guides/developer/README.md)** - Contribution guide

### Specifications

- **[Top-Level Specs](specs/README.md)** - Technical specifications
- **[Contracts](specs/contracts/)** - Normative requirements
- **[ADRs](specs/adr/)** - Architecture decision records
- **[Conformance](specs/conformance/)** - Test scenarios

### RFCs

- **[RFC System](rfcs/README.md)** - Proposal process
- **[RFC Index](rfcs/index.md)** - All RFCs

## Project Status

**Phase**: 1 - Foundation

This project is in early development. The governance system and core architecture are being established.

### Current Status

| Component | Status |
|---|---|
| Governance System | ✅ Implemented |
| Resource Definitions | 🚧 In Progress |
| Compilation Pipeline | 🚧 In Progress |
| IUR Adapter | 🚧 Planned |
| Renderer Integration | 🚧 Planned (via unified packages) |

## Governance

Ash UI follows a formal governance process:

1. **RFCs** - Propose significant changes
2. **Specifications** - Define normative requirements (REQ-*)
3. **ADRs** - Document architecture decisions
4. **Scenarios** - Test acceptance criteria (SCN-*)
5. **Guides** - User and developer documentation

See [RFC-0001](rfcs/RFC-0001-ash-ui-governance-system.md) for details on the governance system.

## Control Planes

| Control Plane | Scope | Module |
|---|---|---|
| Framework | Resource definitions, type system | `AshUI.Framework` |
| Compilation | Resource → canonical IUR pipeline | `AshUI.Compilation` |
| Rendering | IUR adaptation, renderer delegation | `AshUI.Rendering` |
| Runtime | Session lifecycle | `AshUI.Runtime` |
| Extension | Widgets, plugins | `AshUI.Extension` |

**External Renderer Packages** (unified ecosystem):
- `live_ui` - Phoenix LiveView rendering
- `web_ui` - Static HTML + Elm rendering
- `desktop_ui` - Native desktop rendering

See [Control Plane Ownership](specs/contracts/control_plane_ownership_matrix.md) for details.

## Contributing

We welcome contributions! Please:

1. Read the [Contributing Guide](CONTRIBUTING.md) (to be added)
2. Check existing [RFCs](rfcs/) and [Issues](../../issues)
3. Follow the [Code of Conduct](CODE_OF_CONDUCT.md) (to be added)
4. Create an RFC for significant changes

## License

[License to be determined]

## Related Projects

- [Ash Framework](https://ash-hq.org/) - The declarative foundation
- [Unified UI Ecosystem](https://github.com/your-org/unified) - Renderer packages:
  - [unified_iur](https://github.com/your-org/unified/tree/main/packages/unified_iur) - Canonical IUR format
  - [live_ui](https://github.com/your-org/unified/tree/main/packages/live_ui) - LiveView renderer
  - [web_ui](https://github.com/your-org/unified/tree/main/packages/web_ui) - Static HTML renderer
  - [desktop_ui](https://github.com/your-org/unified/tree/main/packages/desktop_ui) - Desktop renderer
- [Phoenix](https://www.phoenixframework.org/) - The web framework
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) - Real-time UI

---

**Ash UI** - Resource-Driven UI Architecture for Elixir
