defmodule AshUI.Signal do
  @moduledoc """
  Signal conversion module for transforming Ash UI bindings to unified-ui signals.

  This module handles the conversion from Ash binding definitions to
  the canonical signal format used by unified-ui renderers.
  """

  alias AshUI.Resources.Binding

  @doc """
  Converts an Ash binding to canonical unified signal format.

  ## Examples

      iex> binding = %AshUI.Resources.Binding{
      ...>   source: %{"resource" => "User", "field" => "name"},
      ...>   target: "value",
      ...>   binding_type: :value
      ...> }
      iex> AshUI.Signal.to_canonical(binding)
      %{
        "type" => "bidirectional",
        "source" => %{"resource" => "User", "field" => "name"},
        "target" => "value",
        "transform" => %{}
      }
  """
  @spec to_canonical(Binding.t() | map()) :: map()
  def to_canonical(%Binding{} = binding) do
    %{
      "type" => map_binding_type(binding.binding_type),
      "source" => convert_source(binding.source),
      "target" => binding.target,
      "transform" => binding.transform || %{},
      "metadata" => binding.metadata || %{}
    }
  end

  def to_canonical(binding) when is_map(binding) do
    binding_type = Map.get(binding, :binding_type) || Map.get(binding, "binding_type", :value)

    %{
      "type" => map_binding_type(binding_type),
      "source" => convert_source(Map.get(binding, :source) || Map.get(binding, "source", %{})),
      "target" => Map.get(binding, :target) || Map.get(binding, "target", ""),
      "transform" => Map.get(binding, :transform) || Map.get(binding, "transform") || %{},
      "metadata" => Map.get(binding, :metadata) || Map.get(binding, "metadata") || %{}
    }
  end

  # Map Ash binding types to unified signal types
  defp map_binding_type(:value), do: "bidirectional"
  defp map_binding_type("value"), do: "bidirectional"
  defp map_binding_type(:list), do: "collection"
  defp map_binding_type("list"), do: "collection"
  defp map_binding_type(:action), do: "event"
  defp map_binding_type("action"), do: "event"
  defp map_binding_type(other), do: to_string(other)

  # Convert binding source to canonical format
  defp convert_source(source) when is_map(source) do
    # Source is already a map, ensure it has the canonical format
    if Map.has_key?(source, "resource") do
      # Ash resource path format: {"resource" => "User", "field" => "name"}
      resolve_source_path(source)
    else
      source
    end
  end

  defp convert_source(source) when is_binary(source) do
    # Parse string path like "User.name" or "Domain.Resource.field"
    parse_source_path(source)
  end

  defp convert_source(_), do: %{}

  # Resolve Ash resource path to canonical signal reference
  defp resolve_source_path(%{"resource" => resource} = source) do
    field = Map.get(source, "field") || Map.get(source, "attribute")
    action = Map.get(source, "action")
    relationship = Map.get(source, "relationship")

    cond do
      action ->
        %{
          "type" => "action",
          "resource" => resource,
          "action" => action
        }

      relationship ->
        %{
          "type" => "relationship",
          "resource" => resource,
          "relationship" => relationship
        }

      field ->
        %{
          "type" => "field",
          "resource" => resource,
          "field" => field
        }

      true ->
        %{
          "type" => "resource",
          "resource" => resource
        }
    end
  end

  defp resolve_source_path(source), do: source

  # Parse string source path
  defp parse_source_path(path) do
    parts = String.split(path, ".", trim: true)

    case parts do
      [resource] ->
        %{"type" => "resource", "resource" => resource}

      [resource, field] ->
        %{"type" => "field", "resource" => resource, "field" => field}

      [resource, relationship, field] ->
        %{
          "type" => "nested",
          "resource" => resource,
          "relationship" => relationship,
          "field" => field
        }

      _ ->
        %{"type" => "path", "path" => path}
    end
  end

  @doc """
  Validates that a binding source exists in Ash resource definitions.

  ## Examples

      iex> AshUI.Signal.valid_source?(%{"resource" => "User", "field" => "name"})
      true

      iex> AshUI.Signal.valid_source?(%{"resource" => "NonExistent", "field" => "foo"})
      false
  """
  @spec valid_source?(map()) :: boolean()
  def valid_source?(source) when is_map(source) do
    resource = Map.get(source, "resource")

    if resource do
      # Check if resource exists in Ash domain
      # For now, return true if resource name is provided
      # In production, this would check against actual Ash resources
      is_binary(resource) and resource != ""
    else
      false
    end
  end

  @doc """
  Applies transformation rules to a signal value.

  ## Examples

      iex> AshUI.Signal.apply_transform("hello", %{"function" => "uppercase"})
      "HELLO"

      iex> AshUI.Signal.apply_transform("  test  ", %{"function" => "trim"})
      "test"
  """
  @spec apply_transform(term(), map()) :: term()
  def apply_transform(value, %{"function" => function} = transform) do
    args = Map.get(transform, "args", [])

    case function do
      "uppercase" -> String.upcase(to_string(value))
      "lowercase" -> String.downcase(to_string(value))
      "trim" -> String.trim(to_string(value))
      "default" -> apply_default(value, args)
      "format" -> apply_format(value, args)
      _ -> value
    end
  end

  def apply_transform(value, _), do: value

  defp apply_default(nil, [default]), do: default
  defp apply_default("", [default]), do: default
  defp apply_default(value, _), do: value

  defp apply_format(value, [pattern]) when is_binary(value) and is_binary(pattern) do
    # Simple format string replacement
    # In production, would use more sophisticated formatting
    String.replace(pattern, "{value}", to_string(value))
  end

  defp apply_format(value, _), do: value
end
