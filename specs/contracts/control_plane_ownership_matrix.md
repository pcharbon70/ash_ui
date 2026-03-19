# Control Plane Ownership Matrix

This document defines the ownership boundaries and authority delegation across all Ash UI control planes.

## Control Plane Definitions

| Control Plane | Module | Owner | Description |
|---|---|---|---|
| Framework | `AshUI.Framework` | Framework Team | Core resource definitions and type system |
| Compilation | `AshUI.Compilation` | Compiler Team | Resource → IUR transformation |
| Rendering | `AshUI.Rendering` | Rendering Team | Output generation for all platforms |
| Runtime | `AshUI.Runtime` | Runtime Team | Session lifecycle and event handling |
| Extension | `AshUI.Extension` | Extension Team | Widget and plugin system |

## Component Ownership

### Framework Control Plane

| Component | Module | Owner | Dependencies |
|---|---|---|---|
| UI.Element | `AshUI.Element` | Framework | Ash.Resource |
| UI.Screen | `AshUI.Screen` | Framework | Ash.Resource, AshUI.Element |
| UI.Binding | `AshUI.Binding` | Framework | Ash.Resource, AshUI.Screen |
| Resource DSL | `AshUI.DSL` | Framework | Ash.DSL.Extension |
| Type System | `AshUI.Types` | Framework | Ash.Type |

### Compilation Control Plane

| Component | Module | Owner | Dependencies |
|---|---|---|---|
| Resource Compiler | `AshUI.Compiler.Resource` | Compilation | Ash Resources |
| IUR Generator | `AshUI.Compiler.IUR` | Compilation | Validator |
| Schema Validator | `AshUI.Compiler.Validator` | Compilation | Ash.Resource.Info |
| Normalizer | `AshUI.Compiler.Normalizer` | Compilation | IUR Schema |
| Compiler Cache | `AshUI.Compiler.Cache` | Compilation | - |

### Rendering Control Plane

| Component | Module | Owner | Dependencies |
|---|---|---|---|
| IUR Adapter | `AshUI.Rendering.IURAdapter` | Rendering | unified_iur |
| Renderer Registry | `AshUI.Rendering.Registry` | Rendering | live_ui, web_ui, desktop_ui |

**External Renderer Packages** (consumed as dependencies):

| Package | Module | Owner | Dependencies |
|---|---|---|---|
| live_ui | `LiveUI.Renderer` | External | Phoenix.LiveView, unified_iur |
| web_ui | `WebUI.Renderer` | External | Phoenix, Elm, unified_iur |
| desktop_ui | `DesktopUI.Renderer` | External | SDL2, unified_iur |

### Runtime Control Plane

| Component | Module | Owner | Dependencies |
|---|---|---|---|
| Session Manager | `AshUI.Runtime.Session` | Runtime | Phoenix.LiveView |
| Event Dispatcher | `AshUI.Runtime.Event` | Runtime | Ash.Actions |
| Lifecycle Manager | `AshUI.Runtime.Lifecycle` | Runtime | Phoenix.LiveView |
| State Store | `AshUI.Runtime.State` | Runtime | - |

### Extension Control Plane

| Component | Module | Owner | Dependencies |
|---|---|---|---|
| Widget Registry | `AshUI.Extension.Widget` | Extension | IUR Schema |
| Plugin Admission | `AshUI.Extension.Admission` | Extension | Validator |
| Extension Loader | `AshUI.Extension.Loader` | Extension | - |

## Authority Boundaries

### Framework Authority (EXCLUSIVE)

The Framework Control Plane has exclusive authority over:

- **Resource Schema Definitions**: Structure of UI.Element, UI.Screen, UI.Binding
- **Type System**: All UI data types and their semantics
- **Action Contracts**: Create, read, update, destroy behavior
- **Validation Rules**: Core validation logic
- **Change Tracking**: How changes are detected and propagated

**REQ-FRAMEWORK-001**: No other control plane may modify core resource schemas.

**REQ-FRAMEWORK-002**: Type definitions are immutable once released.

### Compilation Authority (EXCLUSIVE)

The Compilation Control Plane has exclusive authority over:

- **Compilation Pipeline**: Order and configuration of compilation stages
- **IUR Schema**: Structure of Intermediate UI Representation
- **Validation Strategy**: How validation errors are reported
- **Compiler Cache**: Cache invalidation rules
- **Normalization Rules**: How representations are standardized

**REQ-COMP-001**: Compilation must produce valid IUR for all valid resources.

**REQ-COMP-002**: Compiler must report all validation errors before IUR generation.

### Rendering Authority (DELEGATED)

The Rendering Control Plane delegates actual rendering to external unified renderer packages:

- **IUR Production**: Compiles Ash Resources to canonical `unified_iur` format
- **Renderer Selection**: Application selects target renderer package (live_ui, web_ui, desktop_ui)
- **Adapter Contract**: Defines interface for IUR conversion and renderer invocation
- **Package Integration**: Manages dependencies on external renderer packages

**REQ-RENDER-001**: Ash UI must produce valid canonical `unified_iur` for external renderers.

**REQ-RENDER-002**: External renderer packages must accept canonical IUR without Ash-specific dependencies.

**Note**: LiveView, Static HTML, and Desktop renderers are owned by the unified ecosystem packages, not Ash UI. Ash UI consumes these packages as dependencies.

### Runtime Authority (EXCLUSIVE)

The Runtime Control Plane has exclusive authority over:

- **Session Lifecycle**: Mount, update, and unmount behavior
- **Event Routing**: How events are dispatched to handlers
- **State Management**: How UI state is stored and synchronized
- **Lifecycle Hooks**: Hook execution order and timing

**REQ-RUNTIME-001**: Sessions must isolate state from other sessions.

**REQ-RUNTIME-002**: Events must be processed in order of receipt.

### Extension Authority (EXCLUSIVE)

The Extension Control Plane has exclusive authority over:

- **Extension Contracts**: Interface for widgets and plugins
- **Admission Policy**: Which extensions are allowed
- **Sandboxing**: Extension isolation and security
- **Extension Registry**: How extensions are discovered and loaded

**REQ-EXT-001**: All extensions must be admitted before use.

**REQ-EXT-002**: Extensions must not violate Framework authority.

## Cross-Cutting Concerns

### Authorization (Shared)

Authorization is a shared concern managed by the Framework Control Plane but enforced by Runtime:

- **REQ-AUTH-001**: All actions must be authorized through Ash Policies.
- **REQ-AUTH-002**: Authorization failures must prevent execution.

### Observability (Shared)

Observability is a shared concern with standardized interfaces:

- **REQ-OBS-001**: All control planes must emit telemetry events.
- **REQ-OBS-002**: Events must follow the telemetry schema.

### Configuration (Shared)

Configuration follows a hierarchical model:

1. **Application Config**: Global settings
2. **Control Plane Config**: Control plane-specific settings
3. **Component Config**: Individual component settings

**REQ-CONFIG-001**: Configuration must be validated at application startup.

## Delegation and Escalation

### Delegation Rules

When a control plane needs functionality outside its authority:

1. **Request via Contract**: Use the defined contract interface
2. **No Direct Access**: Never directly invoke another control plane's internals
3. **Respect Boundaries**: Accept the contract's response without modification

### Escalation Paths

When authority boundaries are unclear:

1. **ADR Creation**: Create an Architecture Decision Record
2. **Cross-Plane Review**: All affected control planes must review
3. **Authority Assignment**: Explicitly assign or reassign authority

## Dispute Resolution

### Control Plane Precedence

When disputes arise between control planes:

1. **Framework > All**: Framework control plane has final say on resource schemas
2. **Runtime > Rendering**: Runtime controls when rendering occurs
3. **Compilation > Extension**: Compilation controls what can be compiled

### Change Approval

Changes affecting multiple control planes require:

1. **RFC Proposal**: Document the change and its impact
2. **Cross-Plane Review**: All affected control planes must approve
3. **ADR Creation**: Document the decision if precedent-setting

## Version Coordination

Control planes may version independently, but:

1. **Framework is Source of Truth**: Framework version drives compatibility
2. **Compilation Matches Framework**: Must support current Framework version
3. **Rendering Adapts**: Must support current IUR version
4. **Runtime Wraps**: Must support current Renderer contracts

**REQ-VERSION-001**: All control planes must declare their Framework dependency version.

## Related Specifications

- [ADR-0001: Control Plane Authority](../adr/ADR-0001-control-plane-authority.md)
- [resource_contract.md](resource_contract.md)
- [compilation_contract.md](compilation_contract.md)
- [rendering_contract.md](rendering_contract.md)
- [screen_contract.md](screen_contract.md)
