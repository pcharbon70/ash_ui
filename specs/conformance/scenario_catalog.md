# Scenario Catalog (SCN-*)

This document catalogs all conformance scenarios used to validate Ash UI specifications.

## Purpose

Provides a comprehensive set of scenarios that validate the requirements defined in the specification contracts. Each scenario maps to one or more requirements and serves as acceptance criteria for implementation.

## Scenario Format

Each scenario includes:

- **SCN-ID**: Unique scenario identifier
- **Name**: Human-readable name
- **Requirements**: Linked REQ-* entries
- **Preconditions**: State before scenario execution
- **Steps**: Test execution steps
- **Expected Outcome**: What success looks like
- **Component**: Component being tested

## Scenarios

### Resource Definition Scenarios (SCN-001 to SCN-020)

#### SCN-001: Basic Element Resource Creation

**Requirements**: REQ-RES-001, REQ-RES-002

**Preconditions**:
- Ash UI application is running
- Database is migrated

**Steps**:
1. Define a UI.Element resource with required attributes
2. Execute Ash create action
3. Query the created element

**Expected Outcome**:
- Element is created with valid UUID
- All attributes are persisted correctly
- Element can be queried

#### SCN-002: Element Type Validation

**Requirements**: REQ-RES-002

**Preconditions**:
- UI.Element resource is defined

**Steps**:
1. Attempt to create element with invalid type
2. Attempt to create element with valid type

**Expected Outcome**:
- Invalid type returns validation error
- Valid type creates element successfully

#### SCN-003: Element Relationship Definition

**Requirements**: REQ-RES-003

**Preconditions**:
- UI.Element and UI.Screen resources exist

**Steps**:
1. Create a screen
2. Create elements belonging to screen
3. Query screen with associated elements

**Expected Outcome**:
- Elements load via relationship
- Foreign keys are correct
- Cascade delete works

#### SCN-004: Screen Resource Creation

**Requirements**: REQ-RES-001, REQ-SCREEN-001

**Preconditions**:
- Ash UI application is running

**Steps**:
1. Define a UI.Screen resource with ui_screen DSL
2. Create screen instance
3. Query the screen

**Expected Outcome**:
- Screen is created with valid UUID
- Layout attribute is set
- Screen is queryable

#### SCN-005: Screen Element Composition

**Requirements**: REQ-SCREEN-003

**Preconditions**:
- Screen and element resources exist

**Steps**:
1. Create a screen
2. Add multiple elements to screen
3. Query screen with elements in order

**Expected Outcome**:
- Elements load in correct order
- All elements are present
- Position is maintained

#### SCN-006: Binding Resource Creation

**Requirements**: REQ-BIND-001

**Preconditions**:
- UI.Binding resource is defined

**Steps**:
1. Create a binding with source and target
2. Query the binding
3. Verify binding type

**Expected Outcome**:
- Binding is created with valid UUID
- Source and target are stored
- Binding type is correct

#### SCN-007: Binding Value Type

**Requirements**: REQ-BIND-002

**Preconditions**:
- Element and binding resources exist

**Steps**:
1. Create a value binding
2. Bind to Ash resource attribute
3. Evaluate binding

**Expected Outcome**:
- Binding evaluates to source value
- Changes propagate to element
- Type is preserved

#### SCN-008: Binding List Type

**Requirements**: REQ-BIND-002

**Preconditions**:
- Element and binding resources exist

**Steps**:
1. Create a list binding
2. Bind to Ash resource collection
3. Evaluate binding

**Expected Outcome**:
- Binding evaluates to list
- Multiple items are rendered
- Empty list is handled

#### SCN-009: Binding Action Type

**Requirements**: REQ-BIND-002, REQ-BIND-008

**Preconditions**:
- Element and binding resources exist

**Steps**:
1. Create an action binding
2. Trigger element event
3. Verify action execution

**Expected Outcome**:
- Action is executed on trigger
- Action receives event data
- Result updates UI

#### SCN-010: Source Resolution

**Requirements**: REQ-BIND-003

**Preconditions**:
- Binding resource exists

**Steps**:
1. Create binding with valid source path
2. Create binding with invalid source path
3. Compile both

**Expected Outcome**:
- Valid source compiles successfully
- Invalid source produces error

### Lifecycle Scenarios (SCN-021 to SCN-040)

#### SCN-021: Screen Mount

**Requirements**: REQ-SCREEN-002

**Preconditions**:
- Screen resource exists
- User is authenticated

**Steps**:
1. Navigate to screen route
2. LiveView mounts screen
3. Verify mount action executes

**Expected Outcome**:
- Mount action is called
- Screen transitions to mounted state
- Initial HTML is rendered

#### SCN-022: Screen Unmount

**Requirements**: REQ-SCREEN-002

**Preconditions**:
- Screen is mounted

**Steps**:
1. Navigate away from screen
2. LiveView unmounts screen
3. Verify unmount action executes

**Expected Outcome**:
- Unmount action is called
- Screen transitions to unmounted state
- Resources are cleaned up

#### SCN-023: Screen Update

**Requirements**: REQ-SCREEN-002

**Preconditions**:
- Screen is mounted

**Steps**:
1. Trigger event on screen
2. Handle event
3. Verify state update

**Expected Outcome**:
- Event is processed
- Screen transitions to updating state
- Screen returns to mounted state

#### SCN-024: Session Isolation

**Requirements**: REQ-SCREEN-006

**Preconditions**:
- Two users are logged in

**Steps**:
1. User A mounts screen
2. User B mounts same screen
3. User A modifies state
4. Verify User B state is unchanged

**Expected Outcome**:
- Sessions are isolated
- Changes don't leak between sessions

#### SCN-025: Concurrent Sessions

**Requirements**: REQ-SCREEN-006

**Preconditions**:
- Multiple users access system

**Steps**:
1. Mount 10 concurrent sessions
2. Perform actions in each
3. Verify all sessions work correctly

**Expected Outcome**:
- All sessions operate independently
- No session interference

### Compilation Scenarios (SCN-041 to SCN-060)

#### SCN-041: Resource Compilation

**Requirements**: REQ-COMP-001

**Preconditions**:
- UI resource is defined

**Steps**:
1. Compile resource to IUR
2. Verify pipeline stages execute
3. Verify IUR is generated

**Expected Outcome**:
- All pipeline stages execute
- Valid IUR is produced
- Compilation completes successfully

#### SCN-042: Schema Validation

**Requirements**: REQ-COMP-002

**Preconditions**:
- Resource with invalid schema exists

**Steps**:
1. Attempt to compile invalid resource
2. Verify validation error

**Expected Outcome**:
- Compilation fails
- Error message is descriptive
- Error includes resource location

#### SCN-043: IUR Generation

**Requirements**: REQ-COMP-003

**Preconditions**:
- Valid resource exists

**Steps**:
1. Compile resource to IUR
2. Verify IUR structure
3. Verify IUR serialization

**Expected Outcome**:
- IUR has valid structure
- IUR can be serialized
- IUR contains all required data

#### SCN-044: Resource Resolution

**Requirements**: REQ-COMP-004

**Preconditions**:
- Resource with references exists

**Steps**:
1. Compile resource with references
2. Verify all references are resolved
3. Test with circular reference

**Expected Outcome**:
- Valid references are resolved
- Circular references are detected
- Unresolved references produce errors

#### SCN-045: Normalization

**Requirements**: REQ-COMP-005

**Preconditions**:
- Two equivalent resources with different formats

**Steps**:
1. Compile both resources
2. Compare generated IUR

**Expected Outcome**:
- IURs are identical
- Normalization is deterministic

#### SCN-046: Compiler Cache

**Requirements**: REQ-COMP-007

**Preconditions**:
- Compiler cache is enabled

**Steps**:
1. Compile resource
2. Compile same resource again
3. Verify cache hit

**Expected Outcome**:
- First compile misses cache
- Second compile hits cache
- Cached IUR is identical

#### SCN-047: Cache Invalidation

**Requirements**: REQ-COMP-007

**Preconditions**:
- Resource is compiled and cached

**Steps**:
1. Modify resource
2. Compile resource again
3. Verify cache miss and recompile

**Expected Outcome**:
- Cache is invalidated
- Resource is recompiled
- New IUR is cached

### Rendering Scenarios (SCN-061 to SCN-080)

#### SCN-061: LiveView Rendering

**Requirements**: REQ-RENDER-002

**Preconditions**:
- IUR is compiled

**Steps**:
1. Render IUR with LiveView renderer
2. Verify output is valid HEEx
3. Verify event bindings

**Expected Outcome**:
- Output is valid HEEx
- Events are bound
- HTML is properly escaped

#### SCN-062: Static HTML Rendering

**Requirements**: REQ-RENDER-003

**Preconditions**:
- IUR is compiled

**Steps**:
1. Render IUR with static renderer
2. Verify output is valid HTML
3. Verify document structure

**Expected Outcome**:
- Output is valid HTML5
- Document has DOCTYPE
- No interpolation remains

#### SCN-063: Component Rendering

**Requirements**: REQ-RENDER-004

**Preconditions**:
- IUR with multiple elements exists

**Steps**:
1. Render individual component
2. Verify component output

**Expected Outcome**:
- Component renders independently
- Output includes component only

#### SCN-064: Binding Rendering

**Requirements**: REQ-RENDER-005

**Preconditions**:
- IUR with bindings exists

**Steps**:
1. Render IUR with bindings
2. Verify bindings are translated

**Expected Outcome**:
- Value bindings use LiveView assigns
- Action bindings create event handlers

#### SCN-065: Layout Rendering

**Requirements**: REQ-RENDER-007

**Preconditions**:
- Screen with layout exists

**Steps**:
1. Render screen with layout
2. Verify layout wraps content

**Expected Outcome**:
- Layout wraps screen content
- Layout elements are present

#### SCN-066: Error Rendering

**Requirements**: REQ-RENDER-006

**Preconditions**:
- Invalid IUR exists

**Steps**:
1. Attempt to render invalid IUR
2. Verify error output

**Expected Outcome**:
- Error output is produced
- Error details are included
- Renderer doesn't crash

### Authorization Scenarios (SCN-081 to SCN-100)

#### SCN-081: Screen Mount Authorization

**Requirements**: REQ-AUTH-002

**Preconditions**:
- Screen with authorization policy exists

**Steps**:
1. Unauthorized user attempts to mount screen
2. Authorized user mounts screen

**Expected Outcome**:
- Unauthorized user is redirected
- Authorized user mounts successfully

#### SCN-082: Action Authorization

**Requirements**: REQ-AUTH-003

**Preconditions**:
- Action with authorization policy exists

**Steps**:
1. Unauthorized user attempts action
2. Authorized user executes action

**Expected Outcome**:
- Unauthorized action is forbidden
- Authorized action executes

#### SCN-083: Field-Level Authorization

**Requirements**: REQ-AUTH-004

**Preconditions**:
- Resource with field policies exists

**Steps**:
1. Query resource with restricted fields
2. Verify authorized fields are present
3. Verify unauthorized fields are absent

**Expected Outcome**:
- Authorized fields are included
- Unauthorized fields are excluded

#### SCN-084: Binding Authorization

**Requirements**: REQ-AUTH-005

**Preconditions**:
- Binding to authorized resource exists

**Steps**:
1. Evaluate binding for authorized user
2. Evaluate binding for unauthorized user

**Expected Outcome**:
- Authorized user sees bound data
- Unauthorized user sees empty/filtered data

#### SCN-085: Role-Based Access

**Requirements**: REQ-AUTH-007

**Preconditions**:
- User with multiple roles exists

**Steps**:
1. User performs action requiring one role
2. User performs action requiring another role

**Expected Outcome**:
- Both actions succeed
- Roles are combined correctly

### Observability Scenarios (SCN-101 to SCN-120)

#### SCN-101: Event Emission

**Requirements**: REQ-OBS-001, REQ-OBS-002

**Preconditions**:
- Telemetry handler is attached

**Steps**:
1. Execute operation
2. Verify event is emitted
3. Verify event schema

**Expected Outcome**:
- Event with correct name is emitted
- Measurements are present
- Metadata is correct

#### SCN-102: Span Context

**Requirements**: REQ-OBS-003

**Preconditions**:
- Distributed tracing is enabled

**Steps**:
1. Start operation with span
2. Create child operation
3. Verify span relationship

**Expected Outcome**:
- Parent span ID is set
- Trace ID propagates
- Span context is complete

#### SCN-103: Error Tracking

**Requirements**: REQ-OBS-006

**Preconditions**:
- Error monitoring is enabled

**Steps**:
1. Trigger error condition
2. Verify error event is emitted
3. Verify error context

**Expected Outcome**:
- Error event is emitted
- Error details are included
- Stack trace is present (dev)

#### SCN-104: Performance Monitoring

**Requirements**: REQ-OBS-007

**Preconditions**:
- Metrics collection is enabled

**Steps**:
1. Execute operation
2. Measure duration
3. Verify metric is recorded

**Expected Outcome**:
- Duration metric is present
- Metric is aggregatable
- Units are correct

#### SCN-105: Session Observability

**Requirements**: REQ-OBS-008

**Preconditions**:
- LiveView session is active

**Steps**:
1. Mount session
2. Perform actions
3. Unmount session
4. Verify lifecycle events

**Expected Outcome**:
- Mount event is emitted
- Action events are emitted
- Unmount event is emitted

## Scenario Index

| SCN ID | Name | Requirements | Component |
|---|---|---|---|
| SCN-001 | Basic Element Resource Creation | REQ-RES-001, REQ-RES-002 | UI.Element |
| SCN-002 | Element Type Validation | REQ-RES-002 | UI.Element |
| SCN-003 | Element Relationship Definition | REQ-RES-003 | UI.Element |
| SCN-004 | Screen Resource Creation | REQ-RES-001, REQ-SCREEN-001 | UI.Screen |
| SCN-005 | Screen Element Composition | REQ-SCREEN-003 | UI.Screen |
| SCN-006 | Binding Resource Creation | REQ-BIND-001 | UI.Binding |
| SCN-007 | Binding Value Type | REQ-BIND-002 | UI.Binding |
| SCN-008 | Binding List Type | REQ-BIND-002 | UI.Binding |
| SCN-009 | Binding Action Type | REQ-BIND-002, REQ-BIND-008 | UI.Binding |
| SCN-010 | Source Resolution | REQ-BIND-003 | UI.Binding |
| SCN-021 | Screen Mount | REQ-SCREEN-002 | Runtime |
| SCN-022 | Screen Unmount | REQ-SCREEN-002 | Runtime |
| SCN-023 | Screen Update | REQ-SCREEN-002 | Runtime |
| SCN-024 | Session Isolation | REQ-SCREEN-006 | Runtime |
| SCN-025 | Concurrent Sessions | REQ-SCREEN-006 | Runtime |
| SCN-041 | Resource Compilation | REQ-COMP-001 | Compiler |
| SCN-042 | Schema Validation | REQ-COMP-002 | Validator |
| SCN-043 | IUR Generation | REQ-COMP-003 | IUR Generator |
| SCN-044 | Resource Resolution | REQ-COMP-004 | Resolver |
| SCN-045 | Normalization | REQ-COMP-005 | Normalizer |
| SCN-046 | Compiler Cache | REQ-COMP-007 | Cache |
| SCN-047 | Cache Invalidation | REQ-COMP-007 | Cache |
| SCN-061 | LiveView Rendering | REQ-RENDER-002 | LiveView Renderer |
| SCN-062 | Static HTML Rendering | REQ-RENDER-003 | Static Renderer |
| SCN-063 | Component Rendering | REQ-RENDER-004 | Renderer |
| SCN-064 | Binding Rendering | REQ-RENDER-005 | Renderer |
| SCN-065 | Layout Rendering | REQ-RENDER-007 | Renderer |
| SCN-066 | Error Rendering | REQ-RENDER-006 | Renderer |
| SCN-081 | Screen Mount Authorization | REQ-AUTH-002 | Authorization |
| SCN-082 | Action Authorization | REQ-AUTH-003 | Authorization |
| SCN-083 | Field-Level Authorization | REQ-AUTH-004 | Authorization |
| SCN-084 | Binding Authorization | REQ-AUTH-005 | Authorization |
| SCN-085 | Role-Based Access | REQ-AUTH-007 | Authorization |
| SCN-101 | Event Emission | REQ-OBS-001, REQ-OBS-002 | Telemetry |
| SCN-102 | Span Context | REQ-OBS-003 | Telemetry |
| SCN-103 | Error Tracking | REQ-OBS-006 | Telemetry |
| SCN-104 | Performance Monitoring | REQ-OBS-007 | Telemetry |
| SCN-105 | Session Observability | REQ-OBS-008 | Telemetry |

## Related Specifications

- [spec_conformance_matrix.md](spec_conformance_matrix.md)
- All contract files (../contracts/*.md)
