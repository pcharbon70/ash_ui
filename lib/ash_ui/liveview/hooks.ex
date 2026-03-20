defmodule AshUI.LiveView.Hooks do
  @moduledoc """
  Lifecycle hooks for Ash UI LiveView integration.

  Provides hooks that can be attached to LiveViews to handle
  screen lifecycle events.
  """

  require Logger

  alias AshUI.LiveView.Integration

  @doc """
  on_mount hook for initializing Ash UI screens.

  Attach this hook in your LiveView:

      defmount AshUI.LiveView.Hooks.on_mount_ash_ui

  ## Assigns
    * `:ash_ui_loaded` - Set to true when screen is loaded
  """
  def on_mount_ash_ui(_params, _session, socket) do
    socket =
      socket
      |> Phoenix.Component.assign(:ash_ui_loaded, false)
      |> Phoenix.Component.assign(:ash_ui_subscriptions, [])

    {:cont, socket}
  end

  @doc """
  on_mount hook for screens with automatic mounting.

  Use this hook when you want to automatically mount a screen
  when the LiveView mounts.

  ## Options
    * `:screen_id` - Screen identifier to mount
    * `:screen_param` - Key in session containing screen ID

  ## Examples

      # Mount screen by ID
      on_mount {AshUI.LiveView.Hooks, :mount_screen, screen_id: :dashboard}

      # Mount screen from session
      on_mount {AshUI.LiveView.Hooks, :mount_screen, screen_param: "screen_id"}
  """
  def mount_screen(params, session, socket) do
    screen_id = get_screen_id(params, session)

    case Integration.mount_ui_screen(socket, screen_id, session) do
      {:ok, socket} ->
        socket = Phoenix.Component.assign(socket, :ash_ui_loaded, true)
        Integration.emit_telemetry(:mount, %{screen_id: screen_id}, %{})
        {:cont, socket}

      {:error, :unauthorized} ->
        Integration.emit_telemetry(:auth_failure, %{screen_id: screen_id}, %{})
        {:halt, redirect_to_login(socket)}

      {:error, reason} ->
        Integration.emit_telemetry(:mount_error, %{screen_id: screen_id, reason: inspect(reason)}, %{})
        Logger.error("Failed to mount screen: #{inspect(reason)}")
        {:cont, assign_error(socket, reason)}
    end
  end

  @doc """
  on_update hook for handling screen state changes.

  Called whenever the screen's state changes, allowing
  for custom handling of updates.

  ## Examples

      def handle_params(params, uri, socket) do
        AshUI.LiveView.Hooks.on_update(socket, fn socket ->
          # Custom update logic
          socket
        end)
      end
  """
  def on_update(socket, callback) when is_function(callback, 1) do
    socket
    |> callback.()
    |> then(&{:cont, &1})
  end

  @doc """
  on_unmount hook for cleaning up screen resources.

  Called when the LiveView is about to be unmounted.
  Use this to unsubscribe from notifications and clean up resources.

  ## Examples

      def terminate(_reason, socket) do
        AshUI.LiveView.Hooks.on_unmount(socket)
      end
  """
  def on_unmount(socket) do
    # Unsubscribe from all Ash resource notifications
    cleanup_subscriptions(socket)

    # Emit unmount telemetry
    screen_id = get_screen_id(socket)
    Integration.emit_telemetry(:unmount, %{screen_id: screen_id}, %{})

    :ok
  end

  @doc """
  User-defined lifecycle callback hook.

  Allows users to define custom lifecycle callbacks
  that are called at specific points in the screen lifecycle.

  ## Callback Types
    * `:on_init` - Called after screen mounts
    * `:on_update` - Called after screen state changes
    * `:on_unmount` - Called before screen unmounts

  ## Examples

      defmodule MyLiveView do
        use Phoenix.LiveView

        def mount(params, session, socket) do
          socket = AshUI.LiveView.Hooks.register_callback(socket, :on_init, &init_data/1)
          {:ok, socket}
        end

        defp init_data(socket) do
          # Custom initialization
          socket
        end
      end
  """
  def register_callback(socket, callback_type, callback_fn) when is_function(callback_fn, 1) do
    callbacks = Map.get(socket.assigns, :ash_ui_callbacks, %{})
    updated_callbacks = Map.update(callbacks, callback_type, [callback_fn], &(&1 ++ [callback_fn]))

    Phoenix.Component.assign(socket, :ash_ui_callbacks, updated_callbacks)
  end

  @doc """
  Executes registered callbacks for a given type.

  ## Examples

      AshUI.LiveView.Hooks.execute_callbacks(socket, :on_init)
  """
  def execute_callbacks(socket, callback_type) do
    callbacks = Map.get(socket.assigns, :ash_ui_callbacks, %{})

    callbacks
    |> Map.get(callback_type, [])
    |> Enum.reduce(socket, fn callback, acc ->
      try do
        callback.(acc)
      rescue
        e ->
          Logger.error("Callback #{callback_type} failed: #{inspect(e)}")
          acc
      end
    end)
  end

  @doc """
  Cleanup function for session state on disconnect.

  Ensures all session-specific resources are cleaned up
  when the user disconnects.

  ## Examples

      def handle_info(:disconnect, socket) do
        AshUI.LiveView.Hooks.cleanup_session(socket)
        {:noreply, socket}
      end
  """
  def cleanup_session(socket) do
    # Clean up any session-specific state
    subscriptions = Map.get(socket.assigns, :ash_ui_subscriptions, [])

    Enum.each(subscriptions, fn sub ->
      unsubscribe_from_resource(sub)
    end)

    socket
    |> Phoenix.Component.assign(:ash_ui_subscriptions, [])
    |> Phoenix.Component.assign(:ash_ui_bindings, %{})
  end

  # Private functions

  defp get_screen_id(params, session) do
    # Try to get screen_id from params or session
    Map.get(params, "screen_id") ||
      Map.get(params, :screen_id) ||
      Map.get(session, "screen_id") ||
      Map.get(session, :screen_id)
  end

  defp get_screen_id(socket) do
    case socket.assigns[:ash_ui_screen] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp redirect_to_login(socket) do
    # In production, would use Phoenix.LiveView.redirect
    socket
  end

  defp assign_error(socket, reason) do
    Phoenix.Component.assign(socket, :ash_ui_error, reason)
  end

  defp cleanup_subscriptions(socket) do
    subscriptions = Map.get(socket.assigns, :ash_ui_subscriptions, [])

    Enum.each(subscriptions, fn sub ->
      unsubscribe_from_resource(sub)
    end)
  end

  defp unsubscribe_from_resource(_subscription) do
    # Unsubscribe from Ash.Notifier
    # In production, would call Ash.Notifier.unsubscribe/1
    :ok
  end
end
