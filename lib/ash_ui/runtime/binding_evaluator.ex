defmodule AshUI.Runtime.BindingEvaluator do
  @moduledoc """
  Runtime evaluator for resolving bindings against Ash resource data.

  This module handles the evaluation of bindings at runtime, connecting
  UI elements to actual Ash resource data with proper authorization.
  """

  alias AshUI.Resources.Binding
  alias AshUI.Runtime.ResourceAccess
  alias AshUI.Telemetry

  @type context :: %{
          user_id: String.t() | nil,
          params: map(),
          assigns: map()
        }

  @type evaluation_result :: {:ok, term()} | {:error, term()}

  @doc """
  Evaluates a binding against Ash resource data.

  ## Parameters
    * binding - The binding to evaluate
    * context - Map with user_id, params, and assigns
    * opts - Options including cache settings

  ## Returns
    * `{:ok, value}` - Successfully evaluated
    * `{:error, reason}` - Evaluation failed

  ## Examples

      iex> context = %{user_id: "user-1", params: %{}, assigns: %{}}
      iex> binding = %AshUI.Resources.Binding{
      ...>   source: %{"resource" => "User", "field" => "name"}
      ...> }
      iex> AshUI.Runtime.BindingEvaluator.evaluate(binding, context)
      {:ok, "John Doe"}
  """
  @spec evaluate(Binding.t() | map(), context(), keyword()) :: evaluation_result()
  def evaluate(binding, context, opts \\ [])

  def evaluate(%Binding{} = binding, context, opts) do
    source_map = binding.source || %{}
    transform = binding.transform || %{}
    started_at = System.monotonic_time()

    result =
      with {:ok, value} <- resolve_source(source_map, context, opts),
           {:ok, transformed} <- apply_transformations(value, transform, context) do
        {:ok, transformed}
      end

    emit_binding_telemetry(binding, context, started_at, :evaluate, result)
  end

  def evaluate(binding, context, opts) when is_map(binding) do
    source = Map.get(binding, :source) || Map.get(binding, "source", %{})
    transform = Map.get(binding, :transform) || Map.get(binding, "transform", %{})
    started_at = System.monotonic_time()

    result =
      with {:ok, value} <- resolve_source(source, context, opts),
           {:ok, transformed} <- apply_transformations(value, transform, context) do
        {:ok, transformed}
      end

    emit_binding_telemetry(binding, context, started_at, :evaluate, result)
  end

  # Resolve source path to actual value
  defp resolve_source(%{"resource" => _resource} = source, context, opts) do
    case Map.get(source, "action") do
      nil -> resolve_field_or_relationship(source, context, opts)
      action -> resolve_action(source, action, context, opts)
    end
  end

  defp resolve_source(source, _context, _opts) do
    {:error, {:invalid_source, source}}
  end

  # Resolve field or relationship from resource
  defp resolve_field_or_relationship(source, context, opts) do
    field = Map.get(source, "field")
    relationship = Map.get(source, "relationship")

    cond do
      field ->
        resolve_field(source, field, context, opts)

      relationship ->
        resolve_relationship(source, relationship, context, opts)

      true ->
        {:error, {:missing_field_or_relationship, source}}
    end
  end

  # Resolve a single field from a resource
  defp resolve_field(source, field, context, _opts),
    do: ResourceAccess.read_field(source, field, context)

  defp resolve_relationship(source, relationship, context, _opts),
    do: ResourceAccess.read_relationship(source, relationship, context)

  # Resolve an action source
  defp resolve_action(source, action_name, _context, _opts) do
    resource = Map.get(source, "resource")

    # Actions don't have values to read
    # Return action metadata instead
    {:ok,
     %{
       "type" => "action",
       "resource" => resource,
       "action" => action_name
     }}
  end

  # Apply transformations to the resolved value
  defp apply_transformations(value, transform, _context) do
    transforms = List.wrap(transform)

    transformed =
      Enum.reduce(transforms, value, fn transform, acc ->
        {:ok, new_value} = apply_single_transform(acc, transform)
        new_value
      end)

    {:ok, transformed}
  end

  # Apply a single transformation
  defp apply_single_transform(value, %{"function" => "default"} = transform) do
    args = Map.get(transform, "args", [])

    if value == nil || value == "" do
      default = List.first(args)
      {:ok, default}
    else
      {:ok, value}
    end
  end

  defp apply_single_transform(value, %{"function" => "format"}) do
    # Format transformation - would use specific format rules
    {:ok, format_value(value)}
  end

  defp apply_single_transform(value, %{"function" => "uppercase"}) do
    {:ok, String.upcase(to_string(value))}
  end

  defp apply_single_transform(value, %{"function" => "lowercase"}) do
    {:ok, String.downcase(to_string(value))}
  end

  defp apply_single_transform(value, %{"function" => "trim"}) do
    {:ok, String.trim(to_string(value))}
  end

  defp apply_single_transform(value, %{"function" => "compute"}) do
    # Compute transformation - would apply calculation
    {:ok, value}
  end

  defp apply_single_transform(value, %{"function" => "validate"}) do
    # Validate transformation - would check constraints
    {:ok, value}
  end

  defp apply_single_transform(value, _transform) do
    # Unknown transformation - pass through
    {:ok, value}
  end

  # Format a value (placeholder implementation)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp format_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp format_value(%Date{} = value), do: Date.to_iso8601(value)
  defp format_value(value), do: inspect(value)

  @doc """
  Batch evaluates multiple bindings.

  ## Parameters
    * bindings - List of bindings to evaluate
    * context - Evaluation context
    * opts - Options

  ## Returns
    * Map of binding_id to result
  """
  @spec evaluate_batch([Binding.t() | map()], context(), keyword()) :: %{
          String.t() => evaluation_result()
        }
  def evaluate_batch(bindings, context, opts \\ []) do
    Enum.reduce(bindings, %{}, fn binding, acc ->
      id = get_binding_id(binding)
      result = evaluate(binding, context, opts)
      Map.put(acc, id, result)
    end)
  end

  defp get_binding_id(%Binding{id: id}), do: id
  defp get_binding_id(binding), do: Map.get(binding, :id) || Map.get(binding, "id")

  defp emit_binding_telemetry(binding, context, started_at, event, result) do
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
      {:ok, _value} = success ->
        Telemetry.emit(
          :binding,
          event,
          %{count: 1, duration: duration},
          Map.put(metadata, :status, :ok)
        )

        success

      {:error, reason} = error ->
        error_metadata = Map.merge(metadata, %{status: :error, error: inspect(reason)})

        Telemetry.emit(:binding, event, %{count: 1, duration: duration}, error_metadata)
        Telemetry.emit(:binding, :error, %{count: 1, duration: duration}, error_metadata)
        error
    end
  end
end
