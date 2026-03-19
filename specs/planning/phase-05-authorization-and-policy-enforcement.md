# Phase 5 - Authorization and Policy Enforcement

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `Ash.Policy.Authorizer`
- `Ash.Policy.Check`
- `AshUI.Resource`
- Ash policy DSL (`policy`, `authorize_if`, `forbid_if`)

## Relevant Assumptions / Defaults
- Ash policies control access to UI resources
- Policies are checked on mount and for each action
- Unauthorized access returns user-friendly errors
- Policy failures emit telemetry events

[ ] 5 Phase 5 - Authorization and Policy Enforcement
  Implement Ash policy integration for UI resource access control and action authorization.

  [X] 5.1 Section - Policy Definitions
    Define Ash policies for UI resources.

    [X] 5.1.1 Task - Define UI.Screen policies
    Add policies to screen resource for access control.

      [X] 5.1.1.1 Subtask - Add `policies` block to `AshUI.Screen` resource
      [X] 5.1.1.2 Subtask - Define `:read` policy for screen viewing
      [X] 5.1.1.3 Subtask - Define `:mount` policy for screen mounting
      [X] 5.1.1.4 Subtask - Define `:create`, `:update`, `:destroy` policies

    [X] 5.1.2 Task - Define UI.Element policies
    Add policies to element resource for access control.

      [X] 5.1.2.1 Subtask - Add `policies` block to `AshUI.Element` resource
      [X] 5.1.2.2 Subtask - Define element visibility policies
      [X] 5.1.2.3 Subtask - Define element modification policies
      [X] 5.1.2.4 Subtask - Inherit screen policies where appropriate

    [X] 5.1.3 Task - Define UI.Binding policies
    Add policies to binding resource for access control.

      [X] 5.1.3.1 Subtask - Add `policies` block to `AshUI.Binding` resource
      [X] 5.1.3.2 Subtask - Define binding evaluation policies
      [X] 5.1.3.3 Subtask - Define binding modification policies
      [X] 5.1.3.4 Subtask - Check data source access in binding policies

    [X] 5.1.4 Task - Define common policy checks
    Create reusable policy checks for UI resources.

      [X] 5.1.4.1 Subtask - Implement `user_active` check
      [X] 5.1.4.2 Subtask - Implement `user_role` check with roles
      [X] 5.1.4.3 Subtask - Implement `screen_owner` check
      [X] 5.1.4.4 Subtask - Implement `environment` check (dev/prod)

  [X] 5.2 Section - Runtime Authorization
    Implement policy checking at runtime.

    [X] 5.2.1 Task - Check policies on mount
    Verify authorization when screen is mounted.

      [X] 5.2.1.1 Subtask - Extract user from LiveView session
      [X] 5.2.1.2 Subtask - Call `Ash.can?/3` for mount action
      [X] 5.2.1.3 Subtask - Redirect on authorization failure
      [X] 5.2.1.4 Subtask - Emit authorization attempt telemetry

    [X] 5.2.2 Task - Check policies on actions
    Verify authorization before executing actions.

      [X] 5.2.2.1 Subtask - Check policy before Ash action execution
      [X] 5.2.2.2 Subtask - Return user-friendly error on denial
      [X] 5.2.2.3 Subtask - Log authorization failures
      [X] 5.2.2.4 Subtask - Include policy details in error message

    [X] 5.2.3 Task - Check data source access
    Verify access to bound Ash resources.

      [X] 5.2.3.1 Subtask - Check `:read` policy on binding source resource
      [X] 5.2.3.2 Subtask - Check `:update` policy for write bindings
      [X] 5.2.3.3 Subtask - Handle unauthorized data access gracefully
      [X] 5.2.3.4 Subtask - Redact sensitive data when unauthorized

    [X] 5.2.4 Task - Implement policy caching
    Cache policy results for performance.

      [X] 5.2.4.1 Subtask - Cache policy checks per user/resource
      [X] 5.2.4.2 Subtask - Invalidate cache on resource change
      [X] 5.2.4.3 Subtask - Invalidate cache on role change
      [X] 5.2.4.4 Subtask - Configure cache TTL

  [X] 5.3 Section - Policy DSL Extensions
    Create DSL extensions for common UI authorization patterns.

    [X] 5.3.1 Task - Create UI policy DSL
    Add convenience functions for UI policies.

      [X] 5.3.1.1 Subtask - Implement `visible_if/2` policy helper
      [X] 5.3.1.2 Subtask - Implement `editable_if/2` policy helper
      [X] 5.3.1.3 Subtask - Implement `accessible_if/2` policy helper
      [X] 5.3.1.4 Subtask - Document policy DSL usage

    [X] 5.3.2 Task - Create resource-level policies
    Add policies for accessing bound resources.

      [X] 5.3.2.1 Subtask - Implement `can_read_source/1` policy
      [X] 5.3.2.2 Subtask - Implement `can_write_source/1` policy
      [X] 5.3.2.3 Subtask - Implement `can_access_field/2` policy
      [X] 5.3.2.4 Subtask - Implement `can_execute_action/2` policy

  [ ] 5.4 Section - Error Handling
    Implement user-friendly authorization errors.

    [ ] 5.4.1 Task - Define error types
    Create structured error types for authorization failures.

      [ ] 5.4.1.1 Subtask - Implement `AshUI.AuthorizationError` exception
      [ ] 5.4.1.2 Subtask - Add fields: `resource`, `action`, `policy`, `reason`
      [ ] 5.4.1.3 Subtask - Implement error formatting for display
      [ ] 5.4.1.4 Subtask - Add error translation support

    [ ] 5.4.2 Task - Display authorization errors
    Present authorization errors to users.

      [ ] 5.4.2.1 Subtask - Show clear "access denied" message
      [ ] 5.4.2.2 Subtask - Suggest login link for unauthenticated users
      [ ] 5.4.2.3 Subtask - Show required permissions for authorized users
      [ ] 5.4.2.4 Subtask - Support custom error pages per resource

  [ ] 5.5 Section - Phase 5 Integration Tests
    Validate authorization and policy enforcement end-to-end.

    [ ] 5.5.1 Task - Mount authorization scenarios
      Verify screen mount authorization works correctly.

      [ ] 5.5.1.1 Subtask - Verify authorized user can mount screen
      [ ] 5.5.1.2 Subtask - Verify unauthorized user is redirected
      [ ] 5.5.1.3 Subtask - Verify unauthenticated user redirects to login
      [ ] 5.5.1.4 Subtask - Verify policy changes affect access immediately

    [ ] 5.5.2 Task - Action authorization scenarios
      Verify action authorization works correctly.

      [ ] 5.5.2.1 Subtask - Verify authorized action executes successfully
      [ ] 5.5.2.2 Subtask - Verify unauthorized action returns error
      [ ] 5.5.2.3 Subtask - Verify action errors include policy details
      [ ] 5.5.2.4 Subtask - Verify partial authorization (some fields allowed)

    [ ] 5.5.3 Task - Data source authorization scenarios
      Verify binding data source authorization.

      [ ] 5.5.3.1 Subtask - Verify authorized binding shows data
      [ ] 5.5.3.2 Subtask - Verify unauthorized binding shows placeholder
      [ ] 5.5.3.3 Subtask - Verify unauthorized binding doesn't leak data
      [ ] 5.5.3.4 Subtask - Verify cross-resource authorization works

    [ ] 5.5.4 Task - Policy caching scenarios
      Verify policy caching behavior.

      [ ] 5.5.4.1 Subtask - Verify repeated checks use cache
      [ ] 5.5.4.2 Subtask - Verify cache invalidates on resource change
      [ ] 5.5.4.3 Subtask - Verify cache invalidates on role change
      [ ] 5.5.4.4 Subtask - Verify cache TTL is respected
