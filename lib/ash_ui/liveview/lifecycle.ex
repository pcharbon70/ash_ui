defmodule AshUI.LiveView.Lifecycle do
  @moduledoc """
  Screen lifecycle management for Ash UI LiveView integration.

  Manages the lifecycle of Ash UI screens within LiveView sessions,
  ensuring proper initialization, state isolation, and cleanup.
  """

  require Logger

  alias AshUI.Telemetry

  alias AshUI.LiveView.UpdateIntegration

  @type session_state :: %{
          screen_id: String.t() | nil,
          mounted_at: DateTime.t() | nil,
          subscriptions: list(),
          state: map()
        }

  @doc """
  Initializes a new screen session.

  Sets up the initial state for a screen within a LiveView session.

  ## Examples

      def mount(params, session, socket) do
        {:ok, socket} = AshUI.LiveView.Lifecycle.init_session(socket, :dashboard)
        {:ok, socket}
      end
  """
  @spec init_session(Phoenix.LiveView.Socket.t(), term()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def init_session(socket, screen_id) do
    session_state = %{
      screen_id: screen_id,
      mounted_at: DateTime.utc_now(),
      subscriptions: [],
      state: %{}
    }

    socket =
      socket
      |> Phoenix.Component.assign(:ash_ui_session, session_state)
      |> Phoenix.Component.assign(:ash_ui_session_id, generate_session_id())

    {:ok, socket}
  end

  @doc """
  Registers a lifecycle hook for a specific event.

  ## Hook Types
    * `:on_init` - Called after screen mounts
    * `:on_update` - Called after screen updates
    * `:on_unmount` - Called before screen unmounts
    * `:on_error` - Called when an error occurs

  ## Examples

      socket = Lifecycle.register_hook(socket, :on_init, fn socket ->
        # Custom initialization
        socket
      end)
  """
  @spec register_hook(Phoenix.LiveView.Socket.t(), atom(), fun()) :: Phoenix.LiveView.Socket.t()
  def register_hook(socket, hook_type, callback)
      when is_function(callback, 1) or is_function(callback, 2) do
    hooks = Map.get(socket.assigns, :ash_ui_lifecycle_hooks, %{})
    type_hooks = Map.get(hooks, hook_type, [])
    updated_hooks = Map.put(hooks, hook_type, [callback | type_hooks])

    Phoenix.Component.assign(socket, :ash_ui_lifecycle_hooks, updated_hooks)
  end

  @doc """
  Executes all registered hooks for a specific type.

  ## Examples

      socket = Lifecycle.execute_hooks(socket, :on_init)
  """
  @spec execute_hooks(Phoenix.LiveView.Socket.t(), atom()) :: Phoenix.LiveView.Socket.t()
  def execute_hooks(socket, hook_type) do
    hooks = Map.get(socket.assigns, :ash_ui_lifecycle_hooks, %{})
    type_hooks = Map.get(hooks, hook_type, [])
    user_hooks = user_hooks_for(hooks, hook_type)

    Enum.reduce(type_hooks ++ user_hooks, socket, fn hook, acc ->
      execute_hook(hook, acc, hook_type)
    end)
  end

  @doc """
  Ensures state isolation between LiveView sessions.

  Each LiveView session gets its own isolated state with
  session-specific identifiers.

  ## Examples

      socket = Lifecycle.ensure_isolation(socket)
  """
  @spec ensure_isolation(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def ensure_isolation(socket) do
    session_id = get_session_id(socket)

    socket
    |> Phoenix.Component.assign(:ash_ui_isolated, true)
    |> Phoenix.Component.assign(:ash_ui_session_key, session_id)
    |> isolate_binding_state()
  end

  @doc """
  Stores session-specific state.

  State stored here is isolated to the current LiveView session
  and will be cleaned up on unmount.

  ## Examples

      socket = Lifecycle.put_session_state(socket, :current_tab, "profile")
  """
  @spec put_session_state(Phoenix.LiveView.Socket.t(), atom(), term()) ::
          Phoenix.LiveView.Socket.t()
  def put_session_state(socket, key, value) do
    session_state = Map.get(socket.assigns, :ash_ui_session_state, %{})
    updated = Map.put(session_state, key, value)

    Phoenix.Component.assign(socket, :ash_ui_session_state, updated)
  end

  @doc """
  Retrieves session-specific state.

  ## Examples

      current_tab = Lifecycle.get_session_state(socket, :current_tab)
  """
  @spec get_session_state(Phoenix.LiveView.Socket.t(), atom()) :: term() | nil
  def get_session_state(socket, key) do
    session_state = Map.get(socket.assigns, :ash_ui_session_state, %{})
    Map.get(session_state, key)
  end

  @doc """
  Cleans up session state on disconnect or unmount.

  Removes all session-specific state and unsubscribes from
  resource notifications.

  ## Examples

      def terminate(reason, socket) do
        AshUI.LiveView.Lifecycle.cleanup_session(socket)
      end
  """
  @spec cleanup_session(Phoenix.LiveView.Socket.t()) :: :ok
  def cleanup_session(socket) do
    # Execute on_unmount hooks
    socket = execute_hooks(socket, :on_unmount)

    # Clean up subscriptions
    UpdateIntegration.cleanup_subscriptions(socket)

    # Log session end
    session_id = get_session_id(socket)
    Logger.debug("Ash UI session cleaned up: #{session_id}")

    :ok
  end

  @doc """
  Handles session changes during LiveView updates.

  Called when the session state changes, allowing for
  custom handling of state transitions.

  ## Examples

      def handle_params(params, uri, socket) do
        AshUI.LiveView.Lifecycle.on_session_change(socket, params)
        {:noreply, socket}
      end
  """
  @spec on_session_change(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def on_session_change(socket, params) do
    # Execute on_update hooks
    socket = execute_hooks(socket, :on_update)

    # Update session state if needed
    socket
    |> maybe_update_screen_params(params)
    |> refresh_bindings_if_needed()
  end

  @doc """
  Creates a session-specific key for storing data.

  Ensures that data stored by one session doesn't leak to another.

  ## Examples

      key = Lifecycle.session_key(socket, "current_user")
      # => "ash_ui_session_abc123_current_user"
  """
  @spec session_key(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def session_key(socket, suffix) do
    session_id = get_session_id(socket)
    "ash_ui_session_#{session_id}_#{suffix}"
  end

  @doc """
  Checks if a session is properly isolated.

  Returns true if the session has isolation enabled and
  a unique session ID.

  ## Examples

      if Lifecycle.session_isolated?(socket) do
        # Safe to store session-specific data
      end
  """
  @spec session_isolated?(Phoenix.LiveView.Socket.t()) :: boolean()
  def session_isolated?(socket) do
    Map.get(socket.assigns, :ash_ui_isolated, false) and
      get_session_id(socket) != nil
  end

  @doc """
  Handles errors during screen lifecycle.

  Executes error hooks and ensures proper cleanup even
  when errors occur.

  ## Examples

      try do
        # risky operation
      rescue
        e -> AshUI.LiveView.Lifecycle.handle_error(e, __STACKTRACE__, socket)
      end
  """
  @spec handle_error(Exception.t(), list(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_error(exception, stacktrace, socket) do
    Logger.error("""
    Ash UI lifecycle error: #{inspect(exception)}
    #{Exception.format_stacktrace(stacktrace)}
    """)

    # Execute error hooks
    socket = execute_hooks(socket, :on_error)

    # Store error for display
    socket =
      Phoenix.Component.assign(socket, :ash_ui_error, %{
        exception: exception,
        stacktrace: stacktrace,
        timestamp: DateTime.utc_now()
      })

    socket
  end

  @doc """
  Tracks the lifecycle of a screen for telemetry.

  Emits telemetry events at key lifecycle points.

  ## Events
    * `[:ash_ui, :lifecycle, :init]` - Session initialized
    * `[:ash_ui, :lifecycle, :mount]` - Screen mounted
    * `[:ash_ui, :lifecycle, :update]` - Screen updated
    * `[:ash_ui, :lifecycle, :unmount]` - Screen unmounted
    * `[:ash_ui, :lifecycle, :error]` - Error occurred

  ## Examples

      Lifecycle.emit_telemetry(:mount, socket, %{screen_id: "dashboard"})
  """
  @spec emit_telemetry(atom(), Phoenix.LiveView.Socket.t(), map()) :: :ok
  def emit_telemetry(event, socket, metadata \\ %{}) do
    session_id = get_session_id(socket)
    screen_id = get_screen_id(socket)

    base_metadata = %{
      resource_id: screen_id,
      resource_type: :screen,
      session_id: session_id,
      screen_id: screen_id
    }

    measurements = %{count: 1}
    metadata = Map.merge(base_metadata, metadata)

    case event do
      canonical_event when canonical_event in [:mount, :unmount, :update] ->
        Telemetry.emit(:screen, canonical_event, measurements, metadata,
          legacy_event_names: [[:ash_ui, :lifecycle, event]]
        )

      _other ->
        Telemetry.execute([:ash_ui, :lifecycle, event], measurements, metadata)
    end

    :ok
  end

  # Private functions

  defp generate_session_id do
    "session_#{System.system_time(:microsecond)}_#{:rand.uniform(10000)}"
  end

  defp get_session_id(socket) do
    Map.get(socket.assigns, :ash_ui_session_id) ||
      Map.get(socket.assigns, :ash_ui_session_key)
  end

  defp get_screen_id(socket) do
    case socket.assigns[:ash_ui_screen] do
      %{id: id} ->
        id

      _ ->
        case socket.assigns[:ash_ui_session] do
          %{screen_id: screen_id} -> screen_id
          _ -> nil
        end
    end
  end

  defp execute_hook(hook, socket, hook_type) do
    try do
      case :erlang.fun_info(hook, :arity) do
        {:arity, 2} -> hook.(hook_type, socket)
        _ -> hook.(socket)
      end
    rescue
      e ->
        Logger.error("Ash UI lifecycle hook #{hook_type} failed: #{inspect(e)}")
        socket
    end
  end

  defp user_hooks_for(_hooks, :user_callback), do: []
  defp user_hooks_for(hooks, _hook_type), do: Map.get(hooks, :user_callback, [])

  defp isolate_binding_state(socket) do
    # Create isolated binding state using session-specific keys
    bindings = Map.get(socket.assigns, :ash_ui_bindings, %{})
    session_id = get_session_id(socket)

    isolated_bindings =
      Enum.map(bindings, fn {key, value} ->
        {"#{session_id}_#{key}", value}
      end)
      |> Map.new()

    Phoenix.Component.assign(socket, :ash_ui_bindings_isolated, isolated_bindings)
  end

  defp maybe_update_screen_params(socket, params) do
    if Map.has_key?(params, "screen_id") or Map.has_key?(params, :screen_id) do
      Phoenix.Component.assign(socket, :ash_ui_params, params)
    else
      socket
    end
  end

  defp refresh_bindings_if_needed(socket) do
    # Check if bindings need refresh based on session state changes
    needs_refresh =
      case socket.assigns[:ash_ui_session_state] do
        %{bindings_need_refresh: true} -> true
        _ -> false
      end

    if needs_refresh do
      refreshed_socket =
        case UpdateIntegration.refresh_bindings(socket) do
          {:noreply, refreshed_socket} -> refreshed_socket
        end

      update_in(refreshed_socket.assigns[:ash_ui_session_state], fn
        nil -> nil
        session_state -> Map.put(session_state, :bindings_need_refresh, false)
      end)
      |> then(fn session_state ->
        if is_nil(session_state) do
          refreshed_socket
        else
          Phoenix.Component.assign(refreshed_socket, :ash_ui_session_state, session_state)
        end
      end)
    else
      socket
    end
  end

  @doc """
  Creates a new lifecycle context for a screen.

  This is useful for testing or for creating isolated
  contexts within a single LiveView.

  ## Examples

      context = Lifecycle.create_context(%{user_id: "user-1"})
  """
  @spec create_context(map()) :: map()
  def create_context(initial_state \\ %{}) do
    Map.merge(
      %{
        session_id: generate_session_id(),
        created_at: DateTime.utc_now(),
        hooks: %{},
        state: %{}
      },
      initial_state
    )
  end

  @doc """
  Merges user-defined lifecycle callbacks.

  Allows screens to define their own lifecycle callbacks
  that are called at specific points.

  ## Examples

      defmodule MyScreen do
        def on_lifecycle(:init, socket) do
          # Custom initialization
          socket
        end
      end
  """
  @spec merge_callbacks(Phoenix.LiveView.Socket.t(), module()) :: Phoenix.LiveView.Socket.t()
  def merge_callbacks(socket, module) when is_atom(module) do
    # Check if module defines callback functions
    if function_exported?(module, :on_lifecycle, 2) do
      callback = fn event, socket ->
        try do
          module.on_lifecycle(event, socket)
        rescue
          _ -> socket
        end
      end

      register_hook(socket, :user_callback, callback)
    else
      socket
    end
  end
end
