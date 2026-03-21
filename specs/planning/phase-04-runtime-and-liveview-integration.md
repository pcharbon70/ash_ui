# Phase 4 - Runtime and LiveView Integration

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `AshUI.Runtime.Session`
- `AshUI.LiveView`
- `AshUI.Runtime.Lifecycle`
- `Phoenix.LiveView`
- `Phoenix.LiveView.Socket`

## Relevant Assumptions / Defaults
- LiveView provides the runtime session boundary
- Screen lifecycle maps to LiveView mount/update/unmount
- Each LiveView session has isolated state
- Events flow through LiveView `handle_event/3` and `handle_info/2`

[X] 4 Phase 4 - Runtime and LiveView Integration
  Implement the LiveView integration layer that manages screen lifecycle, session state, and event handling.

  Status note: mount-time compilation, event routing, and LiveView reactivity now run against real Ash-backed binding paths, including PubSub-driven resource change subscriptions.

  [X] 4.1 Section - LiveView Mount Integration
    Implement screen mounting through LiveView `mount/3` callback.

    [X] 4.1.1 Task - Implement mount_ui_screen helper
      Create the helper function for mounting UI screens in LiveView.

      [X] 4.1.1.1 Subtask - Implement `AshUI.LiveView.mount_ui_screen/3`
      [X] 4.1.1.2 Subtask - Accept socket, screen identifier, and params
      [X] 4.1.1.3 Subtask - Load screen resource by name or ID
      [X] 4.1.1.4 Subtask - Return `{:ok, socket}` with screen state assigned

    [X] 4.1.2 Task - Implement screen authorization on mount
      Check Ash policies before allowing screen access.

      [X] 4.1.2.1 Subtask - Load current user from socket assigns
      [X] 4.1.2.2 Subtask - Check `:mount` action policy for screen resource
      [X] 4.1.2.3 Subtask - Redirect to login on authorization failure
      [X] 4.1.2.4 Subtask - Emit authorization failure telemetry

    [X] 4.1.3 Task - Compile screen on mount
      Compile the screen resource to IUR on initial mount.

      [X] 4.1.3.1 Subtask - Call compiler with screen resource
      [X] 4.1.3.2 Subtask - Convert to canonical IUR
      [X] 4.1.3.3 Subtask - Store compiled IUR in socket assigns
      [X] 4.1.3.4 Subtask - Handle compilation errors gracefully

    [X] 4.1.4 Task - Evaluate bindings on mount
      Resolve all data bindings for initial render.

      [X] 4.1.4.1 Subtask - Load all bindings for screen and elements
      [X] 4.1.4.2 Subtask - Evaluate bindings against current data
      [X] 4.1.4.3 Subtask - Store binding values in socket assigns
      [X] 4.1.4.4 Subtask - Handle binding evaluation errors

  [X] 4.2 Section - LiveView Update Integration
    Implement reactive updates through LiveView `handle_info/2` callback.

    [X] 4.2.1 Task - Subscribe to data changes
      Subscribe to Ash resource change notifications.

      [X] 4.2.1.1 Subtask - Subscribe to real `Ash.Notifier` resource changes
      [X] 4.2.1.2 Subtask - Filter notifications to bound resources
      [X] 4.2.1.3 Subtask - Handle subscription messages in `handle_info/2`
      [X] 4.2.1.4 Subtask - Unsubscribe on unmount

    [X] 4.2.2 Task - Re-render on data changes
      Update LiveView when bound data changes.

      [X] 4.2.2.1 Subtask - Re-evaluate affected bindings on notification
      [X] 4.2.2.2 Subtask - Update socket assigns with new values
      [X] 4.2.2.3 Subtask - Trigger LiveView re-render
      [X] 4.2.2.4 Subtask - Batch multiple updates for performance

  [X] 4.3 Section - Event Handling Integration
    Implement UI event handling through LiveView `handle_event/3` callback.

    [X] 4.3.1 Task - Implement event routing
      Route UI events to appropriate handlers.

      [X] 4.3.1.1 Subtask - Parse event name and target from UI
      [X] 4.3.1.2 Subtask - Match event to binding or action
      [X] 4.3.1.3 Subtask - Route to appropriate handler module
      [X] 4.3.1.4 Subtask - Handle unknown events gracefully

    [X] 4.3.2 Task - Implement value change events
      Handle input value changes from form elements.

      [X] 4.3.2.1 Subtask - Capture `phx-blur` or `phx-change` events
      [X] 4.3.2.2 Subtask - Update socket assigns with new value
      [X] 4.3.2.3 Subtask - Write value to Ash resource for `:value` bindings
      [X] 4.3.2.4 Subtask - Handle validation errors

    [X] 4.3.3 Task - Implement action events
      Handle button clicks and other action triggers.

      [X] 4.3.3.1 Subtask - Capture `phx-click` events from buttons
      [X] 4.3.3.2 Subtask - Extract action binding from event target
      [X] 4.3.3.3 Subtask - Execute Ash action with parameters
      [X] 4.3.3.4 Subtask - Return action result to UI

  [X] 4.4 Section - Screen Lifecycle Management
    Implement screen lifecycle hooks and state management.

    [X] 4.4.1 Task - Implement lifecycle hooks
      Add hooks for screen lifecycle events.

      [X] 4.4.1.1 Subtask - Implement `on_mount` hook for initialization
      [X] 4.4.1.2 Subtask - Implement `on_update` hook for state changes
      [X] 4.4.1.3 Subtask - Implement `on_unmount` hook for cleanup
      [X] 4.4.1.4 Subtask - Allow user-defined lifecycle callbacks

    [X] 4.4.2 Task - Implement state isolation
      Ensure each LiveView session has isolated state.

      [X] 4.4.2.1 Subtask - Store screen state in socket assigns
      [X] 4.4.2.2 Subtask - Use session-specific identifiers for state
      [X] 4.4.2.3 Subtask - Prevent state leakage between sessions
      [X] 4.4.2.4 Subtask - Clean up session state on disconnect

  [X] 4.5 Section - Error Handling and Recovery
    Implement error handling for runtime failures.

    [X] 4.5.1 Task - Handle compilation errors
      Gracefully handle screen compilation failures.

      [X] 4.5.1.1 Subtask - Display user-friendly error message
      [X] 4.5.1.2 Subtask - Log detailed error for debugging
      [X] 4.5.1.3 Subtask - Provide retry option for transient errors
      [X] 4.5.1.4 Subtask - Emit error telemetry

    [X] 4.5.2 Task - Handle binding errors
      Gracefully handle binding evaluation failures.

      [X] 4.5.2.1 Subtask - Display placeholder or error state in UI
      [X] 4.5.2.2 Subtask - Continue rendering despite failed bindings
      [X] 4.5.2.3 Subtask - Log binding errors with context
      [X] 4.5.2.4 Subtask - Retry binding evaluation on recovery

  [X] 4.6 Section - Phase 4 Integration Tests
    Validate LiveView integration and lifecycle management end-to-end.

    [X] 4.6.1 Task - Mount lifecycle integration scenarios
      Verify screen mounting and initialization.

      [X] 4.6.1.1 Subtask - Verify screen mounts with valid user
      [X] 4.6.1.2 Subtask - Verify screen redirects on unauthorized access
      [X] 4.6.1.3 Subtask - Verify bindings are evaluated on mount
      [X] 4.6.1.4 Subtask - Verify compilation errors are handled

    [X] 4.6.2 Task - Event handling integration scenarios
      Verify UI events are handled correctly.

      [X] 4.6.2.1 Subtask - Verify button clicks trigger Ash actions
      [X] 4.6.2.2 Subtask - Verify input changes update Ash resources
      [X] 4.6.2.3 Subtask - Verify action errors display feedback
      [X] 4.6.2.4 Subtask - Verify event handlers receive correct parameters

    [X] 4.6.3 Task - Reactivity integration scenarios
      Verify reactive updates work correctly.

      [X] 4.6.3.1 Subtask - Verify UI updates when bound data changes
      [X] 4.6.3.2 Subtask - Verify multiple sessions don't interfere
      [X] 4.6.3.3 Subtask - Verify updates are batched efficiently
      [X] 4.6.3.4 Subtask - Verify subscriptions clean up on unmount
