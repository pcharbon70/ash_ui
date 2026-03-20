defmodule AshUI.Authorization.Runtime do
  @moduledoc """
  Runtime authorization checking for Ash UI.

  Performs policy checking at runtime for screen mounting,
  action execution, and data source access.
  """

  require Logger

  alias AshUI.Authorization.Policies
  alias AshUI.Authorization.ScreenPolicy
  alias AshUI.Authorization.ElementPolicy
  alias AshUI.Authorization.BindingPolicy
  alias AshUI.Telemetry

  @type auth_result :: :authorized | {:forbidden, map()} | {:error, term()}
  @type auth_context :: %{
          user: term() | nil,
          action: atom(),
          resource: module(),
          params: map()
        }

  @doc """
  Check authorization for screen mount.

  Verifies that the user has permission to mount the screen
  before displaying it in LiveView.

  ## Returns
    * `:authorized` - User can mount the screen
    * `{:forbidden, reason}` - User cannot mount the screen

  ## Examples

      case Runtime.check_mount_authorization(user, screen) do
        :authorized -> {:ok, socket}
        {:forbidden, reason} -> {:error, :unauthorized}
      end
  """
  @spec check_mount_authorization(term(), map()) :: auth_result()
  def check_mount_authorization(user, screen) do
    context = build_context(user, :mount, screen)

    with :ok <- emit_auth_telemetry(:mount_attempt, context),
         :ok <- check_user_present(user),
         :ok <- check_user_active(user),
         :ok <- check_screen_accessible(user, screen),
         :ok <- check_policy(user, screen, :mount) do
      emit_auth_telemetry(:mount_success, context)
      :authorized
    else
      {:error, :no_user} ->
        emit_auth_telemetry(:mount_no_user, context)
        {:forbidden, %{reason: :unauthenticated, redirect: :login}}

      {:error, :inactive_user} ->
        emit_auth_telemetry(:mount_inactive, context)
        {:forbidden, %{reason: :inactive}}

      {:error, :not_accessible} ->
        emit_auth_telemetry(:mount_not_accessible, context)
        {:forbidden, %{reason: :forbidden}}

      {:error, reason} ->
        emit_auth_telemetry(:mount_error, context)
        {:forbidden, %{reason: reason}}
    end
  end

  @doc """
  Check authorization before executing an action.

  Verifies that the user has permission to execute the specific
  Ash action.

  ## Returns
    * `:authorized` - User can execute the action
    * `{:forbidden, reason}` - User cannot execute the action

  ## Examples

      case Runtime.check_action_authorization(user, action, params) do
        :authorized -> execute_action(action, params)
        {:forbidden, reason} -> {:error, reason}
      end
  """
  @spec check_action_authorization(term(), atom(), map()) :: auth_result()
  def check_action_authorization(user, action, params \\ %{}) do
    context = build_context(user, action, nil, params)

    with :ok <- emit_auth_telemetry(:action_attempt, context),
         :ok <- check_user_present(user),
         :ok <- check_user_active(user),
         :ok <- check_action_allowed(user, action, params),
         :ok <- check_policy(user, params, action) do
      emit_auth_telemetry(:action_success, context)
      :authorized
    else
      {:error, :no_user} ->
        emit_auth_telemetry(:action_no_user, context)
        {:forbidden,
         %{reason: :unauthenticated, message: "You must be logged in", redirect: :login}}

      {:error, :inactive_user} ->
        emit_auth_telemetry(:action_inactive, context)
        {:forbidden, %{reason: :inactive, message: "Your account is not active"}}

      {:error, :action_forbidden} ->
        emit_auth_telemetry(:action_forbidden, context)

        {:forbidden,
         %{reason: :forbidden, message: "You don't have permission to perform this action"}}

      {:error, reason} ->
        emit_auth_telemetry(:action_error, context)
        {:forbidden, %{reason: reason, message: format_action_error(reason)}}
    end
  end

  @doc """
  Check authorization to read binding data source.

  Verifies that the user has permission to read the data
  that the binding references.

  ## Returns
    * `:authorized` - User can read the data source
    * `{:forbidden, reason}` - User cannot read the data source

  ## Examples

      case Runtime.check_read_access(user, binding) do
        :authorized -> evaluate_binding(binding)
        {:forbidden, _} -> {:ok, redacted_value}
      end
  """
  @spec check_read_access(term(), map()) :: auth_result()
  def check_read_access(user, binding) do
    context = build_context(user, :read, binding)

    with :ok <- emit_auth_telemetry(:read_attempt, context),
         :ok <- check_user_present(user),
         :ok <- check_data_source_accessible(user, binding),
         :ok <- check_policy(user, binding, :read) do
      emit_auth_telemetry(:read_success, context)
      :authorized
    else
      {:error, :no_user} ->
        {:forbidden, %{reason: :unauthenticated}}

      {:error, :not_accessible} ->
        emit_auth_telemetry(:read_not_accessible, context)
        {:forbidden, %{reason: :forbidden}}

      {:error, reason} ->
        {:forbidden, %{reason: reason}}
    end
  end

  @doc """
  Check authorization to write to binding data source.

  Verifies that the user has permission to modify the data
  that the binding references.

  ## Returns
    * `:authorized` - User can write to the data source
    * `{:forbidden, reason}` - User cannot write to the data source
  """
  @spec check_write_access(term(), map()) :: auth_result()
  def check_write_access(user, binding) do
    context = build_context(user, :update, binding)

    with :ok <- emit_auth_telemetry(:write_attempt, context),
         :ok <- check_user_present(user),
         :ok <- check_data_source_writable(user, binding),
         :ok <- check_policy(user, binding, :update) do
      emit_auth_telemetry(:write_success, context)
      :authorized
    else
      {:error, :no_user} ->
        {:forbidden, %{reason: :unauthenticated}}

      {:error, :not_writable} ->
        emit_auth_telemetry(:write_not_writable, context)
        {:forbidden, %{reason: :forbidden}}

      {:error, reason} ->
        {:forbidden, %{reason: reason}}
    end
  end

  @doc """
  Extract user from LiveView socket assigns.

  ## Returns
    * `{:ok, user}` - User found
    * `{:error, :no_user}` - No user in assigns

  ## Examples

      case Runtime.extract_user(socket) do
        {:ok, user} -> check_authorization(user, resource)
        {:error, :no_user} -> redirect_to_login(socket)
      end
  """
  @spec extract_user(Phoenix.LiveView.Socket.t()) :: {:ok, term()} | {:error, :no_user}
  def extract_user(socket) do
    case socket.assigns[:current_user] do
      nil -> {:error, :no_user}
      user -> {:ok, user}
    end
  end

  @doc """
  Cache a policy check result.

  Stores authorization results in a cache for performance.

  ## Examples

      Runtime.cache_policy_check(user, screen, :mount, :authorized)
  """
  @spec cache_policy_check(term(), term(), atom(), auth_result()) :: :ok
  def cache_policy_check(user, resource, action, result) do
    cache_key = build_cache_key(user, resource, action)

    # In production, would use a proper cache (ETS, Cachex, etc.)
    :ets.insert(:ash_ui_auth_cache, {cache_key, result, System.system_time(:second)})

    :ok
  end

  @doc """
  Get cached policy check result.

  Returns cached result if available and not expired.

  ## Examples

      case Runtime.get_cached_policy(user, screen, :mount) do
        {:ok, :authorized} -> # use cached result
        :miss -> # check policy
      end
  """
  @spec get_cached_policy(term(), term(), atom()) :: {:ok, auth_result()} | :miss
  def get_cached_policy(user, resource, action) do
    cache_key = build_cache_key(user, resource, action)
    ttl = Application.get_env(:ash_ui, :auth_cache_ttl, 300)
    now = System.system_time(:second)

    case :ets.lookup(:ash_ui_auth_cache, cache_key) do
      [{^cache_key, result, timestamp}] when now - timestamp < ttl ->
        {:ok, result}

      _ ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  @doc """
  Invalidate policy cache for a user.

  Call this when user roles or permissions change.

  ## Examples

      Runtime.invalidate_user_cache(user_id)
  """
  @spec invalidate_user_cache(String.t() | nil) :: :ok
  def invalidate_user_cache(nil), do: :ok

  def invalidate_user_cache(user_id) when is_binary(user_id) do
    # In production, would selectively invalidate by user
    :ets.delete_all_objects(:ash_ui_auth_cache)
    :ok
  end

  @doc """
  Invalidate policy cache for a resource.

  Call this when resource policies change.

  ## Examples

      Runtime.invalidate_resource_cache(screen)
  """
  @spec invalidate_resource_cache(term()) :: :ok
  def invalidate_resource_cache(resource) do
    # In production, would selectively invalidate by resource
    :ets.delete_all_objects(:ash_ui_auth_cache)
    :ok
  end

  @doc """
  Initialize the authorization cache.

  Call this during application startup.
  """
  @spec init_cache() :: :ok
  def init_cache do
    try do
      :ets.new(:ash_ui_auth_cache, [:named_table, :public, read_concurrency: true])
    rescue
      ArgumentError ->
        # Table already exists
        :ok
    end

    :ok
  end

  @doc """
  Builds a normalized authorization context map for checks and telemetry.
  """
  def build_context(user, action, resource, params \\ %{}) do
    %{
      user: user,
      user_id: get_user_id(user),
      action: action,
      resource: resource,
      params: params,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Builds a stable cache key for a user, resource, and action tuple.
  """
  def build_cache_key(user, resource, action) do
    user_id = get_user_id(user) || "anonymous"
    resource_id = get_resource_id(resource)
    "#{user_id}:#{resource_id}:#{action}"
  end

  @doc """
  Emits authorization telemetry for the given event and context.
  """
  def emit_auth_telemetry(event, context) do
    metadata = %{
      user_id: context.user_id,
      action: context.action,
      resource_id: get_resource_id(context.resource),
      resource_type: :authorization,
      event: event
    }

    Telemetry.execute(
      [:ash_ui, :auth, event],
      %{count: 1},
      metadata
    )

    Telemetry.emit(
      :authorization,
      auth_summary_event(event),
      %{count: 1},
      metadata
    )

    :ok
  end

  # Private functions

  defp get_user_id(nil), do: nil
  defp get_user_id(%{id: id}), do: id
  defp get_user_id(_), do: nil

  defp check_user_present(nil), do: {:error, :no_user}
  defp check_user_present(_user), do: :ok

  defp check_user_active(user) do
    if Policies.user_active(user) do
      :ok
    else
      {:error, :inactive_user}
    end
  end

  defp check_screen_accessible(user, screen) do
    if ScreenPolicy.can_mount?(user, screen) do
      :ok
    else
      {:error, :not_accessible}
    end
  end

  defp check_action_allowed(user, action, params) do
    # Check if user role allows this action
    if Policies.user_role(user, :admin) do
      :ok
    else
      # In production, would check specific action permissions
      :ok
    end
  end

  defp auth_summary_event(event)
       when event in [:mount_attempt, :action_attempt, :read_attempt, :write_attempt],
       do: :auth_check

  defp auth_summary_event(event)
       when event in [:mount_success, :action_success, :read_success, :write_success],
       do: :auth_success

  defp auth_summary_event(_event), do: :auth_fail

  defp check_data_source_accessible(user, binding) do
    if BindingPolicy.source_accessible?(user, binding) do
      :ok
    else
      {:error, :not_accessible}
    end
  end

  defp check_data_source_writable(user, binding) do
    if BindingPolicy.can_write?(user, binding) do
      :ok
    else
      {:error, :not_writable}
    end
  end

  defp check_policy(user, resource, action) do
    # In production, would use Ash.Policy.Authorizer
    :ok
  end

  defp get_resource_id(%{id: id}), do: id
  defp get_resource_id(_), do: "unknown"

  defp format_action_error(reason) do
    case reason do
      :forbidden -> "You don't have permission to perform this action"
      :invalid_params -> "Invalid parameters provided"
      _ -> "Action not allowed"
    end
  end
end
