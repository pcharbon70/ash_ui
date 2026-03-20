defmodule AshUI.Runtime.BidirectionalBinding do
  @moduledoc """
  Bidirectional value binding for two-way data flow.

  Handles reading from Ash resources to UI elements and writing
  user input back to Ash resources with proper change tracking.
  """

  alias AshUI.Runtime.BindingEvaluator
  alias AshUI.Resources.Binding
  alias AshUI.Telemetry

  @type socket :: map()
  @type context :: %{
          user_id: String.t() | nil,
          params: map(),
          assigns: map()
        }

  @doc """
  Reads binding value from Ash resource and updates socket assigns.

  This is the "read" direction of bidirectional binding.

  ## Parameters
    * binding - The binding to read
    * socket - LiveView socket
    * context - Evaluation context

  ## Returns
    * `{:ok, socket}` - Updated socket with binding value
    * `{:error, reason}` - Read failed
  """
  @spec read_binding(Binding.t() | map(), socket(), context()) ::
          {:ok, socket()} | {:error, term()}
  def read_binding(binding, socket, context) do
    with {:ok, value} <- BindingEvaluator.evaluate(binding, context) do
      updated_socket = put_binding_value(socket, binding, value)
      {:ok, updated_socket}
    end
  end

  @doc """
  Writes user input from UI element back to Ash resource.

  This is the "write" direction of bidirectional binding.

  ## Parameters
    * binding - The binding to write
    * new_value - The value from user input
    * socket - LiveView socket
    * context - Evaluation context

  ## Returns
    * `{:ok, socket, result}` - Write succeeded, updated socket and Ash result
    * `{:error, reason, socket}` - Write failed, socket with error state
  """
  @spec write_binding(Binding.t() | map(), term(), socket(), context()) ::
          {:ok, socket(), map()} | {:error, term(), socket()}
  def write_binding(binding, new_value, socket, context) do
    started_at = System.monotonic_time()

    result =
      with :ok <- validate_input(binding, new_value),
           {:ok, sanitized} <- sanitize_input(binding, new_value),
           {:ok, result} <- update_resource(binding, sanitized, context) do
        updated_socket = put_binding_value(socket, binding, sanitized)
        {:ok, updated_socket, result}
      else
        {:error, reason} ->
          error_socket = put_binding_error(socket, binding, reason)
          {:error, reason, error_socket}
      end

    emit_binding_update_telemetry(binding, context, started_at, result)
  end

  @doc """
  Subscribes to Ash resource changes for automatic re-evaluation.

  ## Parameters
    * binding - The binding to subscribe
    * socket - LiveView socket
    * context - Evaluation context

  ## Returns
    * `{:ok, socket}` - Subscribed, socket with tracking info
  """
  @spec subscribe_binding(Binding.t() | map(), socket(), context()) :: {:ok, socket()}
  def subscribe_binding(binding, socket, _context) do
    # Track subscription for this binding
    subscription_id = subscription_id(binding)
    source = Map.get(binding, :source) || Map.get(binding, "source") || %{}
    target = Map.get(binding, :target) || Map.get(binding, "target")

    # In production, this would subscribe to Ash.Notifier
    # For now, track in socket assigns
    subscriptions = get_in(socket.assigns, [:ash_ui, :subscriptions]) || %{}

    updated_subscriptions =
      Map.put(subscriptions, subscription_id, %{
        binding_id: get_binding_id(binding),
        source: source,
        target: target,
        subscribed_at: System.system_time(:millisecond)
      })

    updated_assigns =
      put_in(socket.assigns, [
        Access.key(:ash_ui, %{}),
        Access.key(:subscriptions, %{})
      ], updated_subscriptions)

    updated_socket = %{socket | assigns: updated_assigns}

    {:ok, updated_socket}
  end

  @doc """
  Re-evaluates binding on resource change notification.

  ## Parameters
    * binding - The binding to re-evaluate
    * change_data - Details of what changed
    * socket - LiveView socket
    * context - Evaluation context

  ## Returns
    * `{:ok, socket, changed?}` - Re-evaluated, socket, whether value changed
  """
  @spec reevaluate_binding(Binding.t() | map(), map(), socket(), context()) ::
          {:ok, socket(), boolean()}
  def reevaluate_binding(binding, _change_data, socket, context) do
    old_value = get_binding_value(socket, binding)

    case BindingEvaluator.evaluate(binding, context) do
      {:ok, new_value} ->
        changed = old_value != new_value
        updated_socket = put_binding_value(socket, binding, new_value)
        {:ok, updated_socket, changed}

      {:error, _reason} ->
        # Keep old value on error, but log
        {:ok, socket, false}
    end
  end

  # Validate user input before writing
  defp validate_input(binding, value) do
    # Check if binding has validation rules
    validation = get_in(binding, [:transform, "validate"])

    if validation do
      apply_validation(binding, value, validation)
    else
      :ok
    end
  end

  defp apply_validation(_binding, _value, nil), do: :ok

  defp apply_validation(_binding, value, validation_rules) when is_list(validation_rules) do
    Enum.reduce_while(validation_rules, :ok, fn rule, _acc ->
      case validate_with_rule(rule, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_validation(_binding, _value, _rule), do: :ok

  defp validate_with_rule(%{"type" => "required"}, value) do
    if value in [nil, ""] do
      {:error, :required}
    else
      :ok
    end
  end

  defp validate_with_rule(%{"type" => "min_length", "value" => min}, value) do
    if is_binary(value) and String.length(value) >= min do
      :ok
    else
      {:error, {:min_length, min}}
    end
  end

  defp validate_with_rule(%{"type" => "max_length", "value" => max}, value) do
    if is_binary(value) and String.length(value) <= max do
      :ok
    else
      {:error, {:max_length, max}}
    end
  end

  defp validate_with_rule(_rule, _value), do: :ok

  # Sanitize user input
  defp sanitize_input(binding, value) do
    # Apply sanitization rules from binding transform
    sanitization = get_in(binding, [:transform, "sanitize"])

    case sanitization do
      nil -> {:ok, value}
      rules when is_list(rules) -> apply_sanitization(value, rules)
      _ -> {:ok, value}
    end
  end

  defp apply_sanitization(value, rules) do
    sanitized =
      Enum.reduce(rules, value, fn rule, acc ->
        {:ok, next_value} = sanitize_with_rule(rule, acc)
        next_value
      end)

    {:ok, sanitized}
  end

  defp sanitize_with_rule(%{"type" => "trim"}, value) when is_binary(value) do
    {:ok, String.trim(value)}
  end

  defp sanitize_with_rule(%{"type" => "strip_tags"}, value) when is_binary(value) do
    # Placeholder: In production, use HTML sanitization library
    {:ok, value}
  end

  defp sanitize_with_rule(_rule, value), do: {:ok, value}

  # Update Ash resource with new value
  defp update_resource(binding, value, context) do
    source = Map.get(binding, :source) || Map.get(binding, "source") || %{}
    resource = Map.get(source, "resource")
    field = Map.get(source, "field")
    id = get_resource_id(source, context)

    # In production, this would call Ash.Domain.update/3
    # For now, return a mock result
    mock_update_result(resource, id, field, value)
  end

  defp get_resource_id(source, context) do
    Map.get(source, "id") || Map.get(context, :resource_id)
  end

  defp mock_update_result(_resource, _id, _field, value) do
    {:ok, %{status: :ok, value: value}}
  end

  # Helper functions for socket management
  defp put_binding_value(socket, binding, value) do
    target = Map.get(binding, :target) || Map.get(binding, "target")
    ash_ui = Map.get(socket.assigns, :ash_ui, %{})
    bindings = Map.get(ash_ui, :bindings, %{})

    updated_bindings =
      Map.put(bindings, target, %{
        "value" => value,
        "updated_at" => System.system_time(:millisecond)
      })

    %{
      socket
      | assigns: Map.put(socket.assigns, :ash_ui, Map.put(ash_ui, :bindings, updated_bindings))
    }
  end

  defp get_binding_value(socket, binding) do
    target = Map.get(binding, :target) || Map.get(binding, "target")

    socket.assigns
    |> Map.get(:ash_ui, %{})
    |> Map.get(:bindings, %{})
    |> Map.get(target, %{})
    |> Map.get("value")
  end

  defp put_binding_error(socket, binding, error) do
    target = Map.get(binding, :target) || Map.get(binding, "target")
    ash_ui = Map.get(socket.assigns, :ash_ui, %{})
    bindings = Map.get(ash_ui, :bindings, %{})
    binding_state = Map.get(bindings, target, %{})
    updated_bindings = Map.put(bindings, target, Map.put(binding_state, "error", error))

    %{
      socket
      | assigns: Map.put(socket.assigns, :ash_ui, Map.put(ash_ui, :bindings, updated_bindings))
    }
  end

  defp get_binding_id(%Binding{id: id}), do: id
  defp get_binding_id(binding), do: Map.get(binding, :id) || Map.get(binding, "id")

  defp subscription_id(binding) do
    "#{get_binding_id(binding)}_#{System.system_time(:millisecond)}"
  end

  defp emit_binding_update_telemetry(binding, context, started_at, result) do
    duration = System.monotonic_time() - started_at

    metadata = %{
      binding_id: get_binding_id(binding),
      binding_type: Map.get(binding, :binding_type) || Map.get(binding, "binding_type"),
      target: Map.get(binding, :target) || Map.get(binding, "target"),
      resource_id: get_binding_id(binding),
      resource_type: :binding,
      screen_id: Map.get(binding, :screen_id) || Map.get(binding, "screen_id"),
      user_id: Map.get(context, :user_id)
    }

    case result do
      {:ok, updated_socket, update_result} ->
        Telemetry.emit(
          :binding,
          :update,
          %{count: 1, duration: duration},
          Map.put(metadata, :status, :ok)
        )

        {:ok, updated_socket, update_result}

      {:error, reason, error_socket} ->
        error_metadata = Map.merge(metadata, %{status: :error, error: inspect(reason)})

        Telemetry.emit(:binding, :update, %{count: 1, duration: duration}, error_metadata)
        Telemetry.emit(:binding, :error, %{count: 1, duration: duration}, error_metadata)
        {:error, reason, error_socket}
    end
  end
end
