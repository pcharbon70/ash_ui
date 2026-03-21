defmodule AshUI.Runtime.ActionBinding do
  @moduledoc """
  Event-driven binding for `:action` type bindings.

  Handles execution of Ash actions in response to UI events
  with proper authorization and error handling.
  """

  alias AshUI.Resources.Binding
  alias AshUI.Runtime.ResourceAccess

  @type context :: %{
          user_id: String.t() | nil,
          params: map(),
          assigns: map()
        }

  @type action_result :: %{
          status: :ok | :error,
          data: map() | nil,
          errors: [map()] | nil
        }

  @doc """
  Executes an Ash action in response to a UI event.

  ## Parameters
    * binding - The action binding to execute
    * event_data - Data from the UI event (form values, click data, etc.)
    * context - Execution context with user info
    * opts - Options

  ## Returns
    * `{:ok, action_result}` - Action executed successfully
    * `{:error, reason}` - Action execution failed

  ## Examples

      iex> binding = %{
      ...>   source: %{"resource" => "User", "action" => "create"},
      ...>   binding_type: :action
      ...> }
      iex> event_data = %{"name" => "John", "email" => "john@example.com"}
      iex> AshUI.Runtime.ActionBinding.execute_action(binding, event_data, context)
      {:ok, %{status: :ok, data: %{...}}}
  """
  @spec execute_action(Binding.t() | map(), map(), context(), keyword()) ::
          {:ok, action_result()} | {:error, term()}
  def execute_action(binding, event_data, context, opts \\ []) do
    source = Map.get(binding, :source) || Map.get(binding, "source") || %{}

    with {:ok, :authorized} <- check_authorization(binding, context),
         {:ok, params} <- prepare_params(binding, event_data, context),
         {:ok, result} <- call_ash_action(source, params, context, opts) do
      {:ok,
       %{
         status: :ok,
         data: result,
         errors: nil
       }}
    else
      {:error, reason} ->
        {:error,
         %{
           status: :error,
           data: nil,
           errors: format_action_error(reason)
         }}
    end
  end

  @doc """
  Generates a LiveView event handler from an action binding.

  ## Parameters
    * binding - The action binding
    * element_id - The UI element ID

  ## Returns
    * Event handler function for LiveView

  ## Examples

      iex> binding = %{source: %{"resource" => "User", "action" => "delete"}}
      iex> handler = AshUI.Runtime.ActionBinding.event_handler(binding, "btn-1")
      iex> handler.(socket, %{"value" => "123"}, %{"target" => "btn-1"})
      {:noreply, updated_socket}
  """
  @spec event_handler(Binding.t() | map(), String.t()) :: function()
  def event_handler(binding, _element_id) do
    fn socket, event_data, _event_opts ->
      context = build_context(socket)

      case execute_action(binding, event_data, context) do
        {:ok, result} ->
          handle_action_success(socket, binding, result)

        {:error, _reason} ->
          handle_action_error(socket, binding)
      end
    end
  end

  @doc """
  Wires action bindings to LiveView handle_event/3.

  ## Parameters
    * bindings - List of action bindings
    * socket - LiveView socket

  ## Returns
    * Map of event_name to handler function
  """
  @spec wire_handlers([Binding.t() | map()], map()) :: %{String.t() => function()}
  def wire_handlers(bindings, _socket) do
    action_bindings =
      Enum.filter(bindings, fn b ->
        type = Map.get(b, :binding_type) || Map.get(b, "binding_type")
        type in [:action, "action"]
      end)

    Enum.reduce(action_bindings, %{}, fn binding, acc ->
      target = binding_target(binding)
      element_id = get_binding_element_id(binding)
      fallback_id = Map.get(binding, :id) || Map.get(binding, "id")

      handler_name = "ash_ui_action_#{target || element_id || fallback_id}"

      Map.put(acc, handler_name, event_handler(binding, element_id))
    end)
  end

  # Check authorization before executing action
  defp check_authorization(_binding, context) do
    if ResourceAccess.actor(context) do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  # Prepare parameters from event data and binding config
  defp prepare_params(binding, event_data, context) do
    param_mapping = get_in(binding, [:transform, "params"]) || %{}

    params =
      Enum.reduce(param_mapping, %{}, fn {key, source}, acc ->
        value = get_param_value(source, event_data, context)
        Map.put(acc, key, value)
      end)

    # Merge event data directly if no mapping
    merged_params =
      if param_mapping == %{} do
        Map.merge(params, event_data)
      else
        params
      end

    {:ok, merged_params}
  end

  defp get_param_value({"event", key}, event_data, _context) do
    Map.get(event_data, key)
  end

  defp get_param_value({"context", key}, _event_data, context) do
    Map.get(context, key)
  end

  defp get_param_value({"static", value}, _event_data, _context) do
    value
  end

  defp get_param_value(_source, _event_data, _context), do: nil

  # Call Ash action
  defp call_ash_action(source, params, context, opts),
    do: ResourceAccess.execute_action(source, params, context, opts)

  # Handle successful action
  defp handle_action_success(socket, binding, result) do
    target = binding_target(binding)
    ash_ui = Map.get(socket.assigns, :ash_ui, %{})
    actions = Map.get(ash_ui, :actions, %{})
    action_state = Map.get(actions, target, %{})

    updated_actions =
      actions
      |> Map.put(target, Map.put(action_state, "result", result))
      |> Map.update!(target, &Map.put(&1, "error", nil))

    # Store result in assigns
    updated_socket =
      %{socket | assigns: Map.put(socket.assigns, :ash_ui, Map.put(ash_ui, :actions, updated_actions))}

    # Show success message if configured
    updated_socket =
      if success_message = get_in(binding, [:metadata, "success_message"]) do
        put_flash(updated_socket, :info, success_message)
      else
        updated_socket
      end

    {:noreply, updated_socket}
  end

  # Handle action error
  defp handle_action_error(socket, binding) do
    target = binding_target(binding)
    ash_ui = Map.get(socket.assigns, :ash_ui, %{})
    actions = Map.get(ash_ui, :actions, %{})
    action_state = Map.get(actions, target, %{})
    updated_actions = Map.put(actions, target, Map.put(action_state, "error", "Action failed"))

    # Store error in assigns
    updated_socket =
      %{socket | assigns: Map.put(socket.assigns, :ash_ui, Map.put(ash_ui, :actions, updated_actions))}

    # Show error message
    error_message = get_in(binding, [:metadata, "error_message"]) || "Action failed"
    updated_socket = put_flash(updated_socket, :error, error_message)

    {:noreply, updated_socket}
  end

  # Build context from socket
  defp build_context(socket) do
    user = Map.get(socket.assigns, :current_user)
    user_id = get_in(socket.assigns, [:current_user_id]) || Map.get(user || %{}, :id)
    params = Map.get(socket.assigns, :params, %{})

    %{
      user_id: user_id,
      user: user,
      params: params,
      assigns: socket.assigns
    }
  end

  # Format action error for display
  defp format_action_error(reason) when is_binary(reason), do: [%{"message" => reason}]
  defp format_action_error(:unauthorized), do: [%{"message" => "Unauthorized"}]
  defp format_action_error(reason), do: [%{"message" => inspect(reason)}]

  defp get_binding_element_id(binding) do
    Map.get(binding, :element_id) || Map.get(binding, "element_id")
  end

  defp binding_target(binding) do
    Map.get(binding, :target) || Map.get(binding, "target")
  end

  defp put_flash(socket, kind, message) do
    # In production, this would use Phoenix.LiveView.put_flash/3
    # For now, store in assigns
    flash = Map.get(socket.assigns, :flash, %{})
    updated_flash = Map.update(flash, kind, [message], fn messages -> [message | messages] end)
    %{socket | assigns: Map.put(socket.assigns, :flash, updated_flash)}
  end
end
