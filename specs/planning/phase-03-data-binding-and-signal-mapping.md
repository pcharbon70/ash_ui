# Phase 3 - Data Binding and Signal Mapping

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `AshUI.Binding`
- `AshUI.Signal`
- `AshUI.Runtime.BindingEvaluator`
- `UnifiedIUR.Signal`
- Ash Resource actions (`read`, `create`, `update`, `destroy`)

## Relevant Assumptions / Defaults
- Bindings connect UI elements to Ash resource data
- Signals use Jido.Signal format per unified-ui signal transport spec
- Bidirectional bindings support read and write operations
- Action bindings trigger Ash actions on UI events

[X] 3 Phase 3 - Data Binding and Signal Mapping
  Implement reactive data binding from Ash resources to UI elements through unified-ui signal format.

  Status note: runtime bindings now resolve reads, writes, list loading, and actions through real Ash-backed helpers with authorization-aware access and end-to-end coverage.

  [X] 3.1 Section - Binding Evaluation
    Implement runtime evaluation of bindings against Ash resource data.

    [X] 3.1.1 Task - Implement binding evaluator
      Create the evaluator that resolves bindings to actual values.

      [X] 3.1.1.1 Subtask - Implement `AshUI.Runtime.BindingEvaluator.evaluate/3`
      [X] 3.1.1.2 Subtask - Accept binding, context (user_id, params), and socket assigns
      [X] 3.1.1.3 Subtask - Return `{:ok, value}` or `{:error, reason}`
      [X] 3.1.1.4 Subtask - Cache evaluated values for performance

    [X] 3.1.2 Task - Implement source resolution against real Ash resources
      Resolve structured binding sources to Ash resource attributes and relationships.

      [X] 3.1.2.1 Subtask - Parse structured binding sources
      [X] 3.1.2.2 Subtask - Load resource using real Ash reads with proper authorization
      [X] 3.1.2.3 Subtask - Extract attribute value from loaded resource
      [X] 3.1.2.4 Subtask - Handle relationship traversal against loaded data

    [X] 3.1.3 Task - Implement transformation application
      Apply transformation rules to resolved values.

      [X] 3.1.3.1 Subtask - Apply `format` transformations (e.g., date formatting)
      [X] 3.1.3.2 Subtask - Apply `compute` transformations (e.g., calculated fields)
      [X] 3.1.3.3 Subtask - Apply `default` transformations when source is nil
      [X] 3.1.3.4 Subtask - Apply `validate` transformations and return errors

  [X] 3.2 Section - Bidirectional Value Bindings
    Implement two-way data binding for `:value` type bindings.

    [X] 3.2.1 Task - Implement read direction
      Flow data from Ash resources to UI elements.

      [X] 3.2.1.1 Subtask - Subscribe to Ash resource changes
      [X] 3.2.1.2 Subtask - Re-evaluate binding on resource change
      [X] 3.2.1.3 Subtask - Update LiveView assigns on value change
      [X] 3.2.1.4 Subtask - Handle loading and error states

    [X] 3.2.2 Task - Implement write direction
      Flow data from UI elements to Ash resources.

      [X] 3.2.2.1 Subtask - Capture user input events from LiveView
      [X] 3.2.2.2 Subtask - Validate input data before writing
      [X] 3.2.2.3 Subtask - Call real Ash update actions with new value
      [X] 3.2.2.4 Subtask - Handle update errors and display to user

    [X] 3.2.3 Task - Implement conflict resolution
      Handle concurrent updates to shared data.

      [X] 3.2.3.1 Subtask - Detect stale data with optimistic locking
      [X] 3.2.3.2 Subtask - Retry on conflict with backoff
      [X] 3.2.3.3 Subtask - Present conflict UI to user for resolution
      [X] 3.2.3.4 Subtask - Emit conflict telemetry events

  [X] 3.3 Section - List Bindings
    Implement collection binding for `:list` type bindings.

    [X] 3.3.1 Task - Implement collection loading
      Load and bind collections of resources to UI elements.

      [X] 3.3.1.1 Subtask - Resolve collection source path
      [X] 3.3.1.2 Subtask - Use real Ash reads to load collection
      [X] 3.3.1.3 Subtask - Apply pagination and filtering
      [X] 3.3.1.4 Subtask - Handle empty collections

    [X] 3.3.2 Task - Implement collection reactivity
      Update UI when collection data changes.

      [X] 3.3.2.1 Subtask - Subscribe to collection changes
      [X] 3.3.2.2 Subtask - Re-render list on collection modification
      [X] 3.3.2.3 Subtask - Handle insert, update, delete operations
      [X] 3.3.2.4 Subtask - Maintain scroll position during updates

  [X] 3.4 Section - Action Bindings
    Implement event-driven binding for `:action` type bindings.

    [X] 3.4.1 Task - Implement action execution
      Execute Ash actions in response to UI events.

      [X] 3.4.1.1 Subtask - Parse action source
      [X] 3.4.1.2 Subtask - Call real Ash actions with event data
      [X] 3.4.1.3 Subtask - Check authorization before execution
      [X] 3.4.1.4 Subtask - Return action result to UI

    [X] 3.4.2 Task - Implement action event wiring
      Connect UI events to action bindings.

      [X] 3.4.2.1 Subtask - Generate event handler from binding definition
      [X] 3.4.2.2 Subtask - Wire handler to LiveView `handle_event/3`
      [X] 3.4.2.3 Subtask - Pass event data to action parameters
      [X] 3.4.2.4 Subtask - Handle action errors and display feedback

  [X] 3.5 Section - Signal Format Conversion
    Convert Ash bindings to unified-ui signal format.

    [X] 3.5.1 Task - Define signal structure
      Create the signal structure matching unified-ui spec.

      [X] 3.5.1.1 Subtask - Implement `AshUI.Signal` struct with `id`, `source`, `target` fields
      [X] 3.5.1.2 Subtask - Add `type`, `transform`, `metadata` fields
      [X] 3.5.1.3 Subtask - Implement signal creation helpers
      [X] 3.5.1.4 Subtask - Add signal validation

    [X] 3.5.2 Task - Convert to Jido.Signal format
    Ensure signals are compatible with unified signal transport.

      [X] 3.5.2.1 Subtask - Wrap Ash signals in Jido.Signal structure
      [X] 3.5.2.2 Subtask - Use CloudEvents-compatible event format
      [X] 3.5.2.3 Subtask - Include required CloudEvents fields (id, source, type)
      [X] 3.5.2.4 Subtask - Add signal metadata for tracing

  [X] 3.6 Section - Phase 3 Integration Tests
    Validate binding evaluation and reactivity end-to-end.

    [X] 3.6.1 Task - Value binding integration scenarios
      Verify bidirectional value bindings work correctly.

      [X] 3.6.1.1 Subtask - Verify binding reads from Ash resource on mount
      [X] 3.6.1.2 Subtask - Verify binding updates on resource change
      [X] 3.6.1.3 Subtask - Verify user input writes back to Ash resource
      [X] 3.6.1.4 Subtask - Verify transformation rules apply correctly

    [X] 3.6.2 Task - List binding integration scenarios
      Verify collection bindings work correctly.

      [X] 3.6.2.1 Subtask - Verify list loads and displays collection
      [X] 3.6.2.2 Subtask - Verify list updates on collection changes
      [X] 3.6.2.3 Subtask - Verify pagination and filtering work
      [X] 3.6.2.4 Subtask - Verify empty list state displays correctly

    [X] 3.6.3 Task - Action binding integration scenarios
      Verify action bindings execute correctly.

      [X] 3.6.3.1 Subtask - Verify button click triggers Ash action
      [X] 3.6.3.2 Subtask - Verify action passes event data correctly
      [X] 3.6.3.3 Subtask - Verify authorization is checked
      [X] 3.6.3.4 Subtask - Verify action errors display to user

    [X] 3.6.4 Task - Error handling integration scenarios
      Verify binding errors are handled gracefully.

      [X] 3.6.4.1 Subtask - Verify invalid source produces clear error
      [X] 3.6.4.2 Subtask - Verify unauthorized access is blocked
      [X] 3.6.4.3 Subtask - Verify transformation errors are surfaced
      [X] 3.6.4.4 Subtask - Verify action execution errors display feedback
