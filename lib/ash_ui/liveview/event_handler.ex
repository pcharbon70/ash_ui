defmodule AshUI.LiveView.EventHandler do
  @moduledoc """
  LiveView event handling integration for Ash UI.

  Routes UI events to appropriate handlers, processes value changes,
  and executes Ash actions triggered by UI interactions.
  """

  require Logger

  alias AshUI.Runtime.ActionBinding
  alias AshUI.Runtime.BidirectionalBinding

  @type event_result :: {:noreply, Phoenix.LiveView.Socket.t()} | {:reply, map(), Phoenix.LiveView.Socket.t()}

  @doc """
  Handles UI events and routes them to appropriate handlers.

  This is the main entry point for UI events from LiveView.
  Events are parsed and routed based on their target and type.

  ## Parameters
    * `event_name` - The name of the event (e.g., "ash_ui_event")
    * `event_params` - Event parameters from the UI
    * `socket` - LiveView socket

  ## Returns
    * `{:noreply, socket}` - Event handled, no reply needed
    * `{:reply, map(), socket}` - Event handled with reply data

  ## Examples

      def handle_event("ash_ui_event", params, socket) do
        AshUI.LiveView.EventHandler.handle_event("ash_ui_event", params, socket)
      end
  """
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_event(event_name, event_params, socket) do
    with {:ok, event} <- parse_event(event_name, event_params),
         {:ok, socket} <- route_event(event, socket) do
      {:noreply, socket}
    else
      {:error, :unknown_event} ->
        Logger.debug("Unknown event: #{event_name}")
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Event handling failed: #{inspect(reason)}")
        socket = assign_flash(socket, :error, "Action failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc """
  Handles value change events from form elements.

  Processes `phx-blur` or `phx-change` events and updates
  bound Ash resources.

  ## Examples

      def handle_event("ash_ui_change", params, socket) do
        AshUI.LiveView.EventHandler.handle_value_change(params, socket)
      end
  """
  @spec handle_value_change(map(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_value_change(event_params, socket) do
    target = Map.get(event_params, "target")
    value = Map.get(event_params, "value")

    with {:ok, binding} <- find_binding_by_target(target, socket),
         context <- build_event_context(socket),
         {:ok, socket} <- write_value(binding, value, socket, context) do
      {:noreply, socket}
    else
      {:error, reason} ->
        Logger.error("Value change failed: #{inspect(reason)}")
        socket = assign_flash(socket, :error, "Update failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc """
  Handles action events from buttons and other triggers.

  Processes `phx-click` events and executes bound Ash actions.

  ## Examples

      def handle_event("ash_ui_action", params, socket) do
        AshUI.LiveView.EventHandler.handle_action_event(params, socket)
      end
  """
  @spec handle_action_event(map(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_action_event(event_params, socket) do
    action_id = Map.get(event_params, "action_id")
    event_data = Map.get(event_params, "data", %{})
    context = build_event_context(socket)

    with :ok <- authorize_action_context(context),
         {:ok, binding} <- find_action_binding(action_id, socket),
         {:ok, result} <- execute_action(binding, event_data, socket, context),
         socket <- handle_action_result(result, socket) do
      {:reply, %{status: :ok}, socket}
    else
      {:error, :unauthorized} ->
        socket = assign_flash(socket, :error, "You are not authorized to perform this action")
        {:reply, %{status: :error, reason: "unauthorized"}, socket}

      {:error, reason} ->
        Logger.error("Action execution failed: #{inspect(reason)}")
        socket = assign_flash(socket, :error, "Action failed: #{inspect(reason)}")
        {:reply, %{status: :error, reason: inspect(reason)}, socket}
    end
  end

  @doc """
  Parses a UI event into a structured format.

  ## Event Format
    * `target` - The UI element that triggered the event
    * `type` - The event type (change, click, submit, etc.)
    * `data` - Event data from the UI

  ## Returns
    * `{:ok, event}` - Successfully parsed
    * `{:error, :invalid_event}` - Invalid event format
  """
  @spec parse_event(String.t(), map()) :: {:ok, map()} | {:error, :invalid_event}
  def parse_event(event_name, event_params) do
    case extract_event_type(event_name) do
      {:ok, type} ->
        {:ok,
         %{
           type: type,
           target: Map.get(event_params, "target"),
           data: Map.get(event_params, "data", %{}),
           params: event_params
         }}

      :error ->
        {:error, :invalid_event}
    end
  end

  @doc """
  Routes an event to the appropriate handler based on type.

  ## Event Types
    * `:change` - Value change, routes to `handle_value_change/2`
    * `:click` - Button click, routes to `handle_action_event/2`
    * `:submit` - Form submit, routes to `handle_action_event/2`
  """
  @spec route_event(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()} | {:error, term()}
  def route_event(%{type: :change} = event, socket) do
    params = Map.merge(event.data, %{"target" => event.target})
    handle_value_change(params, socket)
    |> wrap_route_result()
  end

  def route_event(%{type: :click} = event, socket) do
    params = Map.merge(event.data, %{"action_id" => event.target})
    handle_action_event(params, socket)
    |> wrap_route_result()
  end

  def route_event(%{type: :submit} = event, socket) do
    params = Map.merge(event.data, %{"action_id" => event.target})
    handle_action_event(params, socket)
    |> wrap_route_result()
  end

  def route_event(%{type: type}, _socket) do
    {:error, {:unknown_event_type, type}}
  end

  @doc """
  Validates event data before processing.

  ## Returns
    * `:ok` - Valid event data
    * `{:error, reason}` - Invalid event data
  """
  @spec validate_event_data(map(), String.t()) :: :ok | {:error, term()}
  def validate_event_data(event_data, expected_type) do
    with :ok <- validate_required_fields(event_data, expected_type),
         :ok <- validate_event_type(event_data, expected_type) do
      :ok
    end
  end

  @doc """
  Handles validation errors from event processing.

  Displays errors to the user and logs them for debugging.

  ## Examples

      case validate_event_data(data, "change") do
        :ok -> # proceed
        {:error, reason} -> EventHandler.handle_validation_error(reason, socket)
      end
  """
  @spec handle_validation_error(term(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_validation_error(reason, socket) do
    Logger.warning("Validation error: #{inspect(reason)}")

    error_message =
      case reason do
        :missing_target -> "Missing target element"
        :missing_data -> "Missing required data"
        {:invalid_type, got, expected} -> "Invalid event type: expected #{expected}, got #{got}"
        _ -> "Validation failed"
      end

    socket = assign_flash(socket, :error, error_message)
    {:noreply, socket}
  end

  # Private functions

  defp extract_event_type("ash_ui_change"), do: {:ok, :change}
  defp extract_event_type("ash_ui_click"), do: {:ok, :click}
  defp extract_event_type("ash_ui_submit"), do: {:ok, :submit}
  defp extract_event_type(_), do: :error

  defp wrap_route_result({:noreply, socket}), do: {:ok, socket}
  defp wrap_route_result({:reply, _data, socket}), do: {:ok, socket}
  defp wrap_route_result({:error, reason}), do: {:error, reason}

  defp find_binding_by_target(target, socket) do
    bindings = socket.assigns[:ash_ui_bindings] || %{}

    case Enum.find(bindings, fn {_id, binding} ->
      Map.get(binding, :target) == target or Map.get(binding, "target") == target
    end) do
      {id, binding} ->
        binding =
          binding
          |> Map.put_new(:id, id)
          |> Map.put_new(:target, target)

        {:ok, binding}

      nil -> {:error, :binding_not_found}
    end
  end

  defp find_action_binding(action_id, socket) do
    bindings = socket.assigns[:ash_ui_bindings] || %{}
    atom_action_id = safe_to_existing_atom(action_id)

    case Map.get(bindings, action_id) ||
           (atom_action_id && Map.get(bindings, atom_action_id)) ||
           Enum.find_value(bindings, fn {_key, binding} ->
             if Map.get(binding, :id) == action_id or Map.get(binding, "id") == action_id do
               binding
             end
           end) do
      nil -> {:error, :binding_not_found}
      binding -> {:ok, binding}
    end
  end

  defp build_event_context(socket) do
    %{
      user_id: get_user_id(socket),
      user: socket.assigns[:ash_ui_user],
      params: socket.assigns[:ash_ui_params] || %{},
      assigns: socket.assigns,
      socket: socket
    }
  end

  defp authorize_action_context(%{user_id: nil}), do: {:error, :unauthorized}
  defp authorize_action_context(_context), do: :ok

  defp get_user_id(socket) do
    case socket.assigns[:ash_ui_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp write_value(binding, value, socket, context) do
    case BidirectionalBinding.write_binding(binding, value, socket, context) do
      {:ok, updated_socket, _result} -> {:ok, updated_socket}
      {:error, reason, _error_socket} -> {:error, reason}
    end
  end

  defp execute_action(binding, event_data, _socket, context) do
    case ActionBinding.execute_action(binding, event_data, context) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_action_result(result, socket) do
    case result.status do
      :ok ->
        socket = assign_flash(socket, :info, "Action completed successfully")
        socket

      :error ->
        socket = assign_flash(socket, :error, result.message || "Action failed")
        socket
    end
  end

  defp assign_flash(socket, type, message) do
    flash = Map.get(socket.assigns, :flash, %{})
    updated_flash = Map.put(flash, type, message)
    %{socket | assigns: Map.put(socket.assigns, :flash, updated_flash)}
  end

  defp validate_required_fields(event_data, expected_type) do
    required =
      case expected_type do
        "change" -> ["target", "data"]
        _ -> ["target"]
      end

    missing = Enum.reject(required, &Map.has_key?(event_data, &1))

    if missing == [] do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_event_type(_event_data, _expected_type) do
    # Additional type-specific validation
    :ok
  end

  defp safe_to_existing_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> nil
    end
  end

  defp safe_to_existing_atom(_value), do: nil

  @doc """
  Wires all event handlers for a screen's bindings.

  Call this during screen mount to set up all event handlers.

  ## Examples

      def mount(params, session, socket) do
        {:ok, socket} = AshUI.LiveView.Integration.mount_ui_screen(socket, :dashboard, params)
        {:ok, socket} = AshUI.LiveView.EventHandler.wire_handlers(socket)
        {:ok, socket}
      end
  """
  @spec wire_handlers(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def wire_handlers(socket) do
    bindings = socket.assigns[:ash_ui_bindings] || %{}

    # Create handler map for all bindings
    handlers = ActionBinding.wire_handlers(Map.values(bindings), socket)

    socket = Phoenix.Component.assign(socket, :ash_ui_handlers, handlers)
    {:ok, socket}
  end
end
