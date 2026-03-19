# Ash UI Topology

This document defines the canonical topology of the Ash UI framework, including supervision boundaries, service ownership, and control plane authority.

## System Overview

Ash UI is a resource-driven UI framework built on the Ash Framework for Elixir, providing dynamic UI generation from database resources through Phoenix LiveView and static web rendering.

```mermaid
flowchart TB
    subgraph Clients["Client Layer"]
        Browser["Web Browser"]
    end

    subgraph Endpoint["Phoenix Endpoint"]
        LiveView["Phoenix LiveView"]
        StaticController["Static HTML Controller"]
    end

    subgraph Runtime["Runtime Control Plane"]
        LVSession["LiveView Session"]
        EventHandler["Event Handler"]
        LifecycleMgr["Lifecycle Manager"]
    end

    subgraph Compilation["Compilation Control Plane"]
        ResourceCompiler["Resource Compiler"]
        IURGenerator["IUR Generator"]
        Validator["Validator"]
        Normalizer["Normalizer"]
    end

    subgraph Framework["Framework Control Plane"]
        UIElement["UI.Element Resource"]
        UIScreen["UI.Screen Resource"]
        UIBinding["UI.Binding Resource"]
        AshAPI["Ash API Actions"]
    end

    subgraph Data["Data Layer"]
        AshResources["Ash Resources"]
        Database[(Database)]
    end

    subgraph Rendering["Rendering Control Plane"]
        LiveRenderer["live_ui Package<br/>(LiveView Renderer)"]
        WebRenderer["web_ui Package<br/>(Static HTML Renderer)"]
        DesktopRenderer["desktop_ui Package<br/>(Desktop Renderer)"]
        ExternalRegistry["External Renderer Registry"]
    end

    subgraph Extension["Extension Control Plane"]
        WidgetRegistry["Widget Registry"]
        PluginAdmission["Plugin Admission"]
    end

    Browser -->|WebSocket| LiveView
    Browser -->|HTTP GET| StaticController

    LiveView --> LVSession
    StaticController --> WebRenderer

    LVSession --> EventHandler
    LVSession --> LifecycleMgr

    EventHandler --> ResourceCompiler
    EventHandler --> AshAPI

    ResourceCompiler --> IURGenerator
    ResourceCompiler --> Validator
    IURGenerator --> Normalizer

    Validator --> UIElement
    Validator --> UIScreen
    Validator --> UIBinding

    Normalizer -->|"Canonical IUR"| LiveRenderer
    Normalizer -->|"Canonical IUR"| WebRenderer
    Normalizer -->|"Canonical IUR"| DesktopRenderer

    AshAPI --> UIElement
    AshAPI --> UIScreen
    AshAPI --> UIBinding

    UIElement --> AshResources
    UIScreen --> AshResources
    UIBinding --> AshResources

    AshResources --> Database

    LiveRenderer -->|"Native Widgets"| WidgetRegistry
    WebRenderer -->|"Native Widgets"| WidgetRegistry
    DesktopRenderer -->|"Native Widgets"| WidgetRegistry

    Normalizer -->|"IUR Format"| WidgetRegistry

    WidgetRegistry --> PluginAdmission

    classDef framework fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef compilation fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef rendering fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef runtime fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef extension fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef data fill:#eceff1,stroke:#37474f,stroke-width:2px

    class UIElement,UIScreen,UIBinding,AshAPI framework
    class ResourceCompiler,IURGenerator,Validator,Normalizer compilation
    class LiveRenderer,WebRenderer,DesktopRenderer,ExternalRegistry rendering
    class LVSession,EventHandler,LifecycleMgr runtime
    class WidgetRegistry,PluginAdmission extension
    class AshResources,Database data
```

## Supervision Tree

```mermaid
flowchart TB
    subgraph Application["AshUI.Application"]
        subgraph EndpointSup["AshUI.Endpoint"]
            PhoenixEndpoint["Phoenix.Endpoint"]
        end

        subgraph RuntimeSup["AshUI.Runtime.Supervisor"]
            SessionRegistry["Session Registry"]
            SessionSup["Session Supervisor"]
            EventDispatcher["Event Dispatcher"]
        end

        subgraph CompilationSup["AshUI.Compilation.Supervisor"]
            CompilerCache["Compiler Cache"]
            IURGenerator["IUR Generator"]
            ValidatorPool["Validator Pool"]
        end

        subgraph RenderingSup["AshUI.Rendering.Supervisor"]
            RendererRegistry["Renderer Registry"]
            PresenterSup["Presenter Supervisor"]
        end

        subgraph ExtensionSup["AshUI.Extension.Supervisor"]
            WidgetRegistry["Widget Registry"]
            PluginLoader["Plugin Loader"]
        end
    end

    PhoenixEndpoint --> SessionRegistry
    SessionRegistry --> SessionSup
    SessionSup --> EventDispatcher

    EventDispatcher --> CompilerCache
    CompilerCache --> IURGenerator

    IURGenerator --> RendererRegistry
    RendererRegistry --> PresenterSup

    PresenterSup --> WidgetRegistry
    WidgetRegistry --> PluginLoader
```

## Control Plane Authority

### Framework Control Plane

**Owner**: `AshUI.Framework`

**Scope**: Core Ash Resource definitions, type system, action semantics

**Components**:
- `Ash.UI.Element` - Atomic UI component definitions
- `Ash.UI.Screen` - Screen/page composition and lifecycle
- `Ash.UI.Binding` - Data binding and event wiring

**Authority**:
- Defines resource schemas and attributes
- Establishes Ash action contracts (create, read, update, destroy)
- Controls validation rules and change tracking
- Owns the type system for UI components

### Compilation Control Plane

**Owner**: `AshUI.Compilation`

**Scope**: Resource → IUR transformation pipeline

**Components**:
- Resource Compiler - Validates and compiles Ash resources
- IUR Generator - Produces Intermediate UI Representation
- Validator - Schema and constraint validation
- Normalizer - Standardizes representation

**Authority**:
- Defines compilation stages and their ordering
- Controls validation rules and error reporting
- Manages compiler cache and invalidation
- Owns the IUR schema

### Rendering Control Plane

**Owner**: `AshUI.Rendering`

**Scope**: Output generation for target platforms via external renderer packages

**Components**:
- **live_ui** - External package providing LiveView-compatible rendering via `LiveUI.Renderer.render/2`
- **web_ui** - External package providing static HTML rendering via `WebUI.Renderer.render/2`
- **desktop_ui** - External package providing desktop rendering via `DesktopUI.Renderer.render/2`
- **Renderer Registry** - Manages renderer package selection and adapter registration

**Authority**:
- Compiles Ash Resources to canonical unified_iur format
- Delegates rendering to external unified renderer packages
- Manages renderer package selection and routing
- Validates IUR compatibility with target renderers

**External Dependencies**:
- `unified_iur` - Canonical intermediate representation format
- Renderer packages are consumed as dependencies, not owned by Ash UI

### Runtime Control Plane

**Owner**: `AshUI.Runtime`

**Scope**: Session lifecycle and event handling

**Components**:
- LiveView Session Management
- Event Handler - User interaction processing
- Lifecycle Manager - Mount/unmount/hooks

**Authority**:
- Defines session lifecycle contracts
- Controls event routing and handling
- Manages state synchronization
- Owns the LiveView integration points

### Extension Control Plane

**Owner**: `AshUI.Extension`

**Scope**: Custom widgets, plugins, and third-party extensions

**Components**:
- Widget Registry - Custom component registration
- Plugin Admission - Extension validation and loading

**Authority**:
- Defines extension contracts and interfaces
- Controls plugin admission and sandboxing
- Manages widget lifecycle and dependencies
- Owns the extension API

## Data Flow

### Request Flow (LiveView)

```mermaid
sequenceDiagram
    participant B as Browser
    participant LV as LiveView
    participant EH as Event Handler
    participant RC as Resource Compiler
    participant IUR as IUR Generator
    participant UI as unified_iur
    participant LR as LiveUI.Renderer
    participant AR as Ash Resources

    B->>LV: WebSocket Connect
    LV->>LV: Mount Screen
    LV->>EH: Request Screen UI
    EH->>RC: Compile UI.Screen
    RC->>IUR: Generate Ash IUR
    IUR->>UI: Convert to Canonical IUR
    UI->>LR: LiveUI.Renderer.render(iur)
    LR->>LV: HEEx Template
    LV->>B: Initial HTML

    B->>LV: User Event
    LV->>EH: Handle Event
    EH->>AR: Execute Action
    AR-->>EH: Result
    EH->>RC: Recompute UI
    RC->>IUR: Generate Updated IUR
    IUR->>UI: Convert to Canonical IUR
    UI->>LV: Updated HEEx
    LV->>B: Patch Update
```

### Request Flow (Static)

```mermaid
sequenceDiagram
    participant C as Client
    participant SC as Static Controller
    participant EH as Event Handler
    participant RC as Resource Compiler
    participant IUR as IUR Generator
    participant UI as unified_iur
    participant WR as WebUI.Renderer
    participant AR as Ash Resources

    C->>SC: HTTP GET /screen
    SC->>EH: Build Screen Request
    EH->>RC: Compile UI.Screen
    RC->>IUR: Generate Ash IUR
    IUR->>UI: Convert to Canonical IUR
    UI->>WR: WebUI.Renderer.render(iur)
    WR->>SC: Static HTML
    SC->>C: HTML Response
```

## Module Namespace Hierarchy

```
AshUI                               # Application root
├── Application                     # OTP Application
├── Framework                       # Framework Control Plane
│   ├── Element                     # UI.Element Resource
│   ├── Screen                      # UI.Screen Resource
│   └── Binding                     # UI.Binding Resource
├── Compilation                     # Compilation Control Plane
│   ├── Compiler                    # Resource → IUR Compiler
│   ├── IUR                         # Intermediate UI Representation
│   ├── Validator                   # Schema Validator
│   └── Normalizer                  # Representation Normalizer
├── Rendering                       # Rendering Control Plane
│   ├── IURAdapter                  # Ash IUR → unified_iur adapter
│   └── RendererRegistry            # External renderer package management
├── Runtime                         # Runtime Control Plane
│   ├── Session                     # Session Management
│   ├── EventHandler                # Event Processing
│   └── Lifecycle                   # Lifecycle Hooks
└── Extension                       # Extension Control Plane
    ├── WidgetRegistry              # Widget Registration
    └── PluginAdmission             # Plugin Admission
```

## Service Dependencies

### Framework Dependencies
- Ash Framework (Core, API, JsonApi)
- Phoenix LiveView
- Ecto

### Compilation Dependencies
- Ash (Resource DSL)
- Phoenix.Template (for HEEx)

### Rendering Dependencies
- `unified_iur` - Canonical intermediate representation
- `live_ui` - LiveView rendering (optional, application-provided)
- `web_ui` - Static HTML rendering (optional, application-provided)
- `desktop_ui` - Desktop rendering (optional, application-provided)

### Runtime Dependencies
- Phoenix.LiveView
- Phoenix.PubSub

## Ownership Matrix

See [contracts/control_plane_ownership_matrix.md](contracts/control_plane_ownership_matrix.md) for detailed ownership of all components.

## Versioning

The topology version is tracked in the Application module:

```elixir
defmodule AshUI.Application do
  @moduledoc """
  AshUI Application v0.1.0
  Topology Version: 1.0.0
  """
end
```

## Related Specifications

- [Framework Control Plane: resource_contract.md](contracts/resource_contract.md)
- [Compilation Control Plane: compilation_contract.md](contracts/compilation_contract.md)
- [Rendering Control Plane: rendering_contract.md](contracts/rendering_contract.md)
- [Runtime Control Plane: screen_contract.md](contracts/screen_contract.md)
