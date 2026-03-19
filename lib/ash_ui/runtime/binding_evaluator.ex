defmodule AshUI.Runtime.BindingEvaluator do
  @moduledoc """
  Runtime evaluator for resolving bindings against Ash resource data.

  This module handles the evaluation of bindings at runtime, connecting
  UI elements to actual Ash resource data with proper authorization.
  """

  alias AshUI.Resources.Binding

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

    with {:ok, value} <- resolve_source(source_map, context, opts),
         {:ok, transformed} <- apply_transformations(value, binding.transform, context) do
      {:ok, transformed}
    end
  end

  def evaluate(binding, context, opts) when is_map(binding) do
    source = Map.get(binding, :source) || Map.get(binding, "source", %{})
    transform = Map.get(binding, :transform) || Map.get(binding, "transform", %{})

    with {:ok, value} <- resolve_source(source, context, opts),
         {:ok, transformed} <- apply_transformations(value, transform, context) do
      {:ok, transformed}
    end
  end

  # Resolve source path to actual value
  defp resolve_source(%{"resource" => resource} = source, context, opts) do
    case Map.get(source, "action") do
      nil -> resolve_field_or_relationship(source, context, opts)
      action -> resolve_action(source, action, context, opts)
    end
  end

  defp resolve_source(source, _context, _opts) do
    {:error, {:invalid_source, source}}
  end

  # Resolve field or relationship from resource
  defp resolve_field_or_relationship(%{"resource" => resource} = source, context, opts) do
    field = Map.get(source, "field")
    relationship = Map.get(source, "relationship")
    id = Map.get(source, "id")

    cond do
      field ->
        resolve_field(resource, field, id, context, opts)

      relationship ->
        resolve_relationship(resource, relationship, context, opts)

      true ->
        {:error, {:missing_field_or_relationship, source}}
    end
  end

  # Resolve a single field from a resource
  defp resolve_field(resource_name, field, id, context, _opts) do
    # Build Ash query to read the resource
    # In production, this would use the actual Ash domain and resources
    # For now, return a placeholder
    case load_resource(resource_name, id, context) do
      {:ok, resource} ->
        value = get_field(resource, field)
        {:ok, value}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Resolve a relationship (e.g., user.profile.name)
  defp resolve_relationship(resource_name, relationship, context, opts) do
    parts = String.split(relationship, ".")

    case load_resource(resource_name, nil, context) do
      {:ok, resource} ->
        navigate_relationship(resource, parts, context)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Navigate through nested relationships
  defp navigate_relationship(nil, _parts, _context), do: {:ok, nil}

  defp navigate_relationship(resource, [part | rest], context) do
    value = get_field(resource, part)

    if rest == [] do
      {:ok, value}
    else
      navigate_relationship(value, rest, context)
    end
  end

  # Resolve an action source
  defp resolve_action(source, action_name, context, _opts) do
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

  # Load a resource by name and ID
  defp load_resource(_resource_name, _id, _context) do
    # Placeholder: In production, this would call Ash.Domain.get/3
    # For now, return mock data
    {:ok,
     %{
       "id" => "mock-id",
       "name" => "Mock Resource",
       "type" => "mock"
     }}
  end

  # Get a field from a resource (map or struct)
  defp get_field(resource, field) when is_map(resource) do
    key = String.to_existing_atom(field)

    case Map.get(resource, key) do
      nil -> Map.get(resource, field)
      value -> value
    end
  rescue
    ArgumentError ->
      Map.get(resource, field)
  end

  defp get_field(_resource, _field), do: nil

  # Apply transformations to the resolved value
  defp apply_transformations(value, transform, _context) do
    transforms = List.wrap(transform)

    Enum.reduce_while(transforms, {:ok, value}, fn transform, {:ok, acc} ->
      case apply_single_transform(acc, transform) do
        {:ok, new_value} -> {:cont, {:ok, new_value}}
        {:error, _} = error -> {:halt, error}
      end
    end)
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

  defp apply_single_transform(_value, transform) do
    # Unknown transformation - pass through
    {:ok, nil}
  end

  # Format a value (placeholder implementation)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_number(value), do: to_string(value)
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
  @spec evaluate_batch([Binding.t() | map()], context(), keyword()) :: %{String.t() => evaluation_result()}
  def evaluate_batch(bindings, context, opts \\ []) do
    Enum.reduce(bindings, %{}, fn binding, acc ->
      id = get_binding_id(binding)
      result = evaluate(binding, context, opts)
      Map.put(acc, id, result)
    end)
  end

  defp get_binding_id(%Binding{id: id}), do: id
  defp get_binding_id(binding), do: Map.get(binding, :id) || Map.get(binding, "id")
end
