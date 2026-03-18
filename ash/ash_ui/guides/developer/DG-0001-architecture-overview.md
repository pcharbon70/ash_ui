# DG-0001: Ash UI Architecture Overview

---
id: DG-0001
title: Ash UI Architecture Overview
audience: Framework Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-18
next_review: 2026-09-18
related_reqs: [REQ-FRAMEWORK-001, REQ-COMP-001, REQ-RENDER-001]
related_scns: [SCN-101]
related_guides: [UG-0001]
diagram_required: true
---

## Overview

This guide provides a comprehensive overview of the Ash UI architecture for framework contributors. It covers control planes, the compilation pipeline, rendering system, and extension points.

## Prerequisites

Before reading this guide, you should:

- Have strong knowledge of Elixir and OTP
- Understand Ash Framework resources and DSL
- Have read [UG-0001: Getting Started](../user/UG-0001-getting-started.md)

## System Architecture

### High-Level Architecture

```mermaid
flowchart TB
    subgraph Application["Application Layer"]
        LiveView["Phoenix LiveView"]
        Static["Static Controller"]
    end

    subgraph Runtime["Runtime Control Plane"]
        Session["Session Manager"]
        Event["Event Dispatcher"]
        Lifecycle["Lifecycle Manager"]
    end

    subgraph Compilation["Compilation Control Plane"]
        Compiler["Resource Compiler"]
        IUR["IUR Generator"]
        Validator["Validator"]
        Normalizer["Normalizer"]
    end

    subgraph Framework["Framework Control Plane"]
        Element["UI.Element"]
        Screen["UI.Screen"]
        Binding["UI.Binding"]
    end

    subgraph Data["Data Layer"]
        Resources["Ash Resources"]
        DB[(Database)]
    end

    subgraph Rendering["Rendering Control Plane"]
        LiveRenderer["LiveView Renderer"]
        WebRenderer["Static Renderer"]
    end

    LiveView --> Session
    Static --> WebRenderer

    Session --> Event
    Session --> Lifecycle

    Event --> Compiler
    Compiler --> IUR
    IUR --> Validator
    Validator --> Normalizer

    Normalizer --> LiveRenderer
    Normalizer --> WebRenderer

    Validator --> Element
    Validator --> Screen
    Validator --> Binding

    Element --> Resources
    Screen --> Resources
    Binding --> Resources

    Resources --> DB

    classDef framework fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef compilation fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef rendering fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef runtime fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef data fill:#eceff1,stroke:#37474f,stroke-width:2px

    class Element,Screen,Binding framework
    class Compiler,IUR,Validator,Normalizer compilation
    class LiveRenderer,WebRenderer rendering
    class Session,Event,Lifecycle runtime
    class Resources,DB data
```

## Control Planes

Ash UI is organized into five control planes, each with distinct authority and responsibility.

### Framework Control Plane

**Module**: `AshUI.Framework`

**Authority**: Core resource definitions, type system, action semantics

**Components**:
- `AshUI.Resources.Element` - UI element definitions
- `AshUI.Resources.Screen` - Screen definitions
- `AshUI.Resources.Binding` - Data binding definitions
- `AshUI.DSL` - DSL extensions for resources
- `AshUI.Types` - Custom Ash types

**Key Contract**: [resource_contract.md](../../specs/contracts/resource_contract.md)

### Compilation Control Plane

**Module**: `AshUI.Compilation`

**Authority**: Resource → IUR transformation pipeline

**Components**:
- `AshUI.Compiler.Resource` - Main compiler
- `AshUI.Compiler.IUR` - IUR schema and generation
- `AshUI.Compiler.Validator` - Schema validation
- `AshUI.Compiler.Normalizer` - Representation normalization
- `AshUI.Compiler.Cache` - Compilation caching

**Key Contract**: [compilation_contract.md](../../specs/contracts/compilation_contract.md)

### Rendering Control Plane

**Module**: `AshUI.Rendering`

**Authority**: Output generation for target platforms

**Components**:
- `AshUI.Renderer.LiveView` - LiveView rendering
- `AshUI.Renderer.Static` - Static HTML rendering
- `AshUI.Renderer.Registry` - Renderer registry
- `AshUI.Renderer.Presenter` - Presentation logic

**Key Contract**: [rendering_contract.md](../../specs/contracts/rendering_contract.md)

### Runtime Control Plane

**Module**: `AshUI.Runtime`

**Authority**: Session lifecycle and event handling

**Components**:
- `AshUI.Runtime.Session` - Session management
- `AshUI.Runtime.Event` - Event handling
- `AshUI.Runtime.Lifecycle` - Lifecycle hooks

**Key Contract**: [screen_contract.md](../../specs/contracts/screen_contract.md)

### Extension Control Plane

**Module**: `AshUI.Extension`

**Authority**: Widget and plugin system

**Components**:
- `AshUI.Extension.Widget` - Widget registry
- `AshUI.Extension.Admission` - Plugin admission
- `AshUI.Extension.Loader` - Plugin loading

## Compilation Pipeline

### Pipeline Stages

```mermaid
flowchart LR
    Resource["Ash Resource"] --> Parse["Parse"]
    Parse --> Validate["Validate"]
    Validate -->|Pass| Normalize["Normalize"]
    Validate -->|Fail| Error["Error"]
    Normalize --> Generate["Generate IUR"]
    Generate --> Optimize["Optimize"]
    Optimize --> Cache["Cache"]
    Cache --> IUR["IUR Output"]
```

### Stage Details

1. **Parse** - Extract resource definitions using Ash.Info
2. **Validate** - Verify schema, constraints, and relationships
3. **Normalize** - Standardize attribute order, apply defaults
4. **Generate IUR** - Create Intermediate UI Representation
5. **Optimize** - Apply optimizations (dead code elimination, etc.)
6. **Cache** - Store result for reuse

## Intermediate UI Representation (IUR)

### IUR Schema

```elixir
%AshUI.Compilation.IUR{
  id: UUID.t(),
  type: :screen | :element,
  name: String.t(),
  attributes: map(),
  children: [%AshUI.Compilation.IUR{}],
  bindings: [%AshUI.Compilation.BindingRef{}],
  metadata: map(),
  version: "1.0.0"
}
```

### IUR Properties

- **Serializable** - Can be encoded to JSON/binary
- **Immutable** - IUR instances are never modified
- **Self-contained** - All information needed for rendering
- **Versioned** - Schema version for compatibility

## Module Namespace

```elixir
AshUI                                   # Application root
├── Application                         # OTP Application
├── Framework                           # Framework Control Plane
│   ├── DSL
│   ├── Types
│   └── Resources
│       ├── Element
│       ├── Screen
│       └── Binding
├── Compilation                         # Compilation Control Plane
│   ├── Compiler
│   ├── IUR
│   ├── Validator
│   ├── Normalizer
│   └── Cache
├── Rendering                           # Rendering Control Plane
│   ├── LiveView
│   ├── Static
│   ├── Registry
│   └── Presenter
├── Runtime                             # Runtime Control Plane
│   ├── Session
│   ├── Event
│   └── Lifecycle
└── Extension                           # Extension Control Plane
    ├── Widget
    ├── Admission
    └── Loader
```

## Extension Points

### Custom Element Types

Register custom element types:

```elixir
defmodule MyApp.CustomElement do
  use AshUI.Extension.Widget

  def type, do: :my_custom
  def render(iur, context) do
    # Custom rendering logic
  end
end

AshUI.Extension.Widget.register(:my_custom, MyApp.CustomElement)
```

### Custom Renderers

Implement the renderer behaviour:

```elixir
defmodule MyApp.CustomRenderer do
  @behaviour AshUI.Renderer

  def render(iur, opts) do
    # Custom rendering logic
  end

  def can_render?(iur), do: true
  def format, do: :custom
end
```

## Data Flow

### LiveView Request Flow

```mermaid
sequenceDiagram
    participant B as Browser
    participant LV as LiveView
    participant RT as Runtime
    participant CC as Compiler
    participant RD as Renderer

    B->>LV: WebSocket Connect
    LV->>RT: Mount Screen
    RT->>CC: Compile Screen
    CC->>RT: IUR
    RT->>RD: Render IUR
    RD->>LV: HEEx
    LV->>B: Initial HTML

    B->>LV: User Event
    LV->>RT: Handle Event
    RT->>CC: Recompile
    CC->>RD: Render Update
    RD->>LV: Patch
    LV->>B: Update
```

## Contributing

### Adding New Element Types

1. Define type in `AshUI.Types`
2. Add validation rules
3. Implement rendering in both renderers
4. Write conformance scenarios
5. Update documentation

### Adding New Control Plane Components

1. Check ownership matrix for authority
2. Create ADR if setting precedent
3. Define requirements (REQ-*)
4. Write scenarios (SCN-*)
5. Implement and document

## See Also

- [Topology](../../specs/topology.md) - Complete system topology
- [Control Plane Ownership](../../specs/contracts/control_plane_ownership_matrix.md) - Ownership details
- [ADR-0001](../../specs/adr/ADR-0001-control-plane-authority.md) - Control plane authority
