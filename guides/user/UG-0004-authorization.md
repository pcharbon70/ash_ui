# UG-0004: Authorization in Ash UI

---
id: UG-0004
title: Authorization in Ash UI
audience: Application Developers
status: Active
owners: Ash UI Team
last_reviewed: 2026-03-20
next_review: 2026-09-20
related_reqs: [REQ-AUTH-002, REQ-AUTH-003, REQ-AUTH-005, REQ-AUTH-007, REQ-AUTH-009, REQ-AUTH-012]
related_scns: [SCN-021, SCN-081, SCN-082, SCN-084, SCN-085, SCN-101]
related_guides: [UG-0001, UG-0002, UG-0003, DG-0001]
diagram_required: false
---

## Overview

This guide covers how Ash UI authorizes screen mounts, actions, and binding access at runtime. It focuses on the modules that exist in the current codebase rather than the longer-term policy roadmap.

## Prerequisites

Before reading this guide, you should:

- Know how your app represents users and roles
- Have read [UG-0001](./UG-0001-getting-started.md)
- Understand bindings from [UG-0003](./UG-0003-data-binding.md)

## Where Authorization Happens

The main runtime entry points are:

- `AshUI.LiveView.Integration.authorize_screen/2`
- `AshUI.Authorization.Runtime.check_mount_authorization/2`
- `AshUI.Authorization.Runtime.check_action_authorization/3`
- `AshUI.Authorization.Runtime.check_read_access/2`
- `AshUI.Authorization.Runtime.check_write_access/2`

Policy helpers live in:

- `AshUI.Authorization.ScreenPolicy`
- `AshUI.Authorization.ElementPolicy`
- `AshUI.Authorization.BindingPolicy`

## Minimum User Shape

The current authorization code expects a user value with at least:

```elixir
%{
  id: "user-1",
  role: :admin,
  active: true
}
```

Practical behavior today:

- missing user means unauthenticated
- inactive user is denied
- role and ownership checks determine access to protected screens and bindings

## Screen Mount Authorization

Mount authorization happens before compilation and binding evaluation.

```elixir
user = %{id: "admin-1", role: :admin, active: true}

case AshUI.Authorization.Runtime.check_mount_authorization(user, screen) do
  :authorized -> :ok
  {:forbidden, %{reason: :unauthenticated}} -> :redirect_to_login
  {:forbidden, %{reason: :inactive}} -> :show_inactive_message
  {:forbidden, %{reason: :forbidden}} -> :show_403
end
```

If you mount screens through `AshUI.LiveView.Integration.mount_ui_screen/3`, this check is part of the flow already.

## Action Authorization

Actions are checked before execution:

```elixir
case AshUI.Authorization.Runtime.check_action_authorization(user, :save_profile, %{}) do
  :authorized ->
    :ok

  {:forbidden, %{redirect: :login}} ->
    :login

  {:forbidden, reason} ->
    {:error, reason}
end
```

This is especially important for `:action` bindings, because button clicks and form submits may look harmless from the UI but still need policy enforcement.

## Binding Read and Write Access

Binding-level checks protect the data behind the UI.

```elixir
case AshUI.Authorization.Runtime.check_read_access(user, binding) do
  :authorized -> AshUI.Runtime.BindingEvaluator.evaluate(binding, context)
  {:forbidden, _} -> {:ok, nil}
end

case AshUI.Authorization.Runtime.check_write_access(user, binding) do
  :authorized -> AshUI.Runtime.BidirectionalBinding.write_binding(binding, "new", socket, context)
  {:forbidden, _} -> {:error, :forbidden}
end
```

## Bypass Mode

There is an explicit runtime bypass flag:

```elixir
config :ash_ui, :runtime_authorization_bypass, false
```

Keep this disabled in normal environments. It exists to support tightly controlled development or test workflows, not as a default behavior.

## What Gets Logged and Emitted

Authorization emits telemetry through `AshUI.Telemetry` and the runtime authorization module. Useful events include:

- `[:ash_ui, :authorization, :auth_check]`
- `[:ash_ui, :authorization, :auth_success]`
- `[:ash_ui, :authorization, :auth_fail]`
- screen-related failure events such as `[:ash_ui, :screen, :auth_failure]`

## Recommended Application Patterns

- Always assign `:current_user` before calling Ash UI mount helpers.
- Use explicit roles like `:admin` and `:user` in the user map or struct.
- Keep inactive users marked with `active: false` rather than deleting them from authorization logic.
- Shape binding sources so authorization code can inspect resource and field names directly.

## Failure Modes to Expect

### `{:error, :no_user}`

The LiveView socket did not include `:current_user`.

### `{:error, :unauthorized}`

The user was present, but the screen policy denied mount.

### `{:forbidden, %{reason: :forbidden}}`

The runtime blocked access to a binding or action.

## See Also

- [UG-0001: Getting Started](./UG-0001-getting-started.md)
- [UG-0003: Data Binding](./UG-0003-data-binding.md)
- [DG-0001: Architecture Overview](../developer/DG-0001-architecture-overview.md)
- [authorization_contract.md](../../specs/contracts/authorization_contract.md)
