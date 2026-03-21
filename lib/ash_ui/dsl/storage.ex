defmodule AshUI.DSL.Storage do
  @moduledoc """
  DSL storage format and utilities for unified-ui definitions.

  Defines the structure for storing unified-ui DSL in Ash Resources
  and provides helpers for working with stored DSL.
  """

  @type unified_dsl :: %{
          type: String.t(),
          props: map(),
          children: [unified_dsl()],
          signals: [signal()],
          metadata: map()
        }

  @type signal :: %{
          type: atom(),
          target: String.t(),
          source: String.t() | nil,
          transform: term() | nil
        }

  @doc """
  Defines the unified_dsl attribute for Ash Resources.

  Returns an Ash attribute specification that can be used
  in resource definitions.

  ## Examples

      attribute :unified_dsl, AshUI.DSL.Storage.attribute_type()
  """
  @spec attribute_type() :: Ash.Type.Type.t()
  def attribute_type do
    # Use :map type for storing JSON/DSL
    :map
  end

  @doc """
  Default empty DSL structure.

  ## Examples

      AshUI.DSL.Storage.default()
  """
  @spec default() :: unified_dsl()
  def default do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      type: "fragment",
      props: %{},
      children: [],
      signals: [],
      metadata: normalize_metadata_keys(%{version: "1.0.0", created_at: timestamp})
    }
  end

  @doc """
  Validates DSL structure before database write.

  Checks that the DSL conforms to expected structure and
  contains valid widget types.

  ## Returns
    * `:ok` - Valid DSL
    * `{:error, errors}` - List of validation errors

  ## Examples

      case AshUI.DSL.Storage.validate_write(dsl) do
        :ok -> {:ok, dsl}
        {:error, errors} -> {:error, errors}
      end
  """
  @spec validate_write(unified_dsl()) :: :ok | {:error, [String.t()]}
  def validate_write(dsl) when is_map(dsl) do
    errors =
      []
      |> validate_structure(dsl)
      |> validate_widget_types(dsl)
      |> validate_signal_references(dsl)
      |> validate_no_circular_refs(dsl, [])

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  @doc """
  Checks if a widget type is valid.

  ## Returns
    * `true` - Valid widget type
    * `false` - Invalid widget type

  ## Examples

      AshUI.DSL.Storage.valid_widget_type?("text") # => true
      AshUI.DSL.Storage.valid_widget_type?("invalid") # => false
  """
  @spec valid_widget_type?(String.t()) :: boolean()
  def valid_widget_type?(type) when is_binary(type) do
    valid_layouts = ["row", "column", "grid", "stack", "fragment", "container"]
    valid_widgets = ["text", "button", "input", "checkbox", "select", "image", "spacer"]

    type in valid_layouts or type in valid_widgets or String.starts_with?(type, "custom:")
  end

  @doc """
  Gets all widget types referenced in a DSL structure.

  ## Examples

      types = AshUI.DSL.Storage.widget_types(dsl)
      # => ["row", "text", "button"]
  """
  @spec widget_types(unified_dsl()) :: [String.t()]
  def widget_types(dsl) do
    types =
      case dsl_type(dsl) do
        nil -> []
        type -> [type]
      end

    child_types =
      Enum.flat_map(dsl_children(dsl), fn child ->
        widget_types(child)
      end)

    types ++ child_types
  end

  @doc """
  Gets all signal references in a DSL structure.

  ## Examples

      signals = AshUI.DSL.Storage.signal_references(dsl)
      # => [%{type: :bidirectional, target: "name", source: "User.name"}]
  """
  @spec signal_references(unified_dsl()) :: [signal()]
  def signal_references(dsl) do
    local_signals = dsl_signals(dsl)

    child_signals =
      Enum.flat_map(dsl_children(dsl), fn child ->
        signal_references(child)
      end)

    local_signals ++ child_signals
  end

  @doc """
  Merges metadata into a DSL structure.

  ## Examples

      dsl_with_metadata = AshUI.DSL.Storage.put_metadata(dsl, %{
        screen_id: "screen-1",
        version: "1.0.0"
      })
  """
  @spec put_metadata(unified_dsl(), map()) :: unified_dsl()
  def put_metadata(dsl, metadata) do
    Map.update(dsl, :metadata, metadata, fn existing ->
      Map.merge(existing, normalize_metadata_keys(metadata))
    end)
  end

  @doc """
  Gets metadata from a DSL structure.

  ## Examples

      metadata = AshUI.DSL.Storage.get_metadata(dsl)
  """
  @spec get_metadata(unified_dsl()) :: map()
  def get_metadata(dsl) when is_map(dsl) do
    Map.get(dsl, :metadata) || Map.get(dsl, "metadata") || %{}
  end

  @doc """
  Increments the DSL version.

  ## Examples

      updated_dsl = AshUI.DSL.Storage.increment_version(dsl)
  """
  @spec increment_version(unified_dsl()) :: unified_dsl()
  def increment_version(dsl) do
    put_metadata(dsl, %{
      version: get_next_version(),
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Private functions

  defp validate_structure(errors, dsl) do
    required_fields = [:type, :props, :children, :signals]

    missing =
      Enum.reject(required_fields, fn field ->
        Map.has_key?(dsl, field) or Map.has_key?(dsl, Atom.to_string(field))
      end)

    case missing do
      [] -> errors
      fields -> ["Missing required fields: #{inspect(fields)}" | errors]
    end
  end

  defp validate_widget_types(errors, dsl) do
    invalid_types =
      dsl
      |> widget_types()
      |> Enum.reject(&valid_widget_type?/1)
      |> Enum.uniq()

    case invalid_types do
      [] -> errors
      types -> ["Invalid widget types: #{inspect(types)}" | errors]
    end
  end

  defp validate_signal_references(errors, dsl) do
    signals = signal_references(dsl)

    invalid_signals =
      Enum.reject(signals, fn signal ->
        valid_signal_structure?(signal)
      end)

    case invalid_signals do
      [] -> errors
      _ -> ["Invalid signal references found" | errors]
    end
  end

  defp validate_no_circular_refs(errors, dsl, path) do
    current_type = dsl_type(dsl)

    if current_type in path do
      ["Circular reference detected: #{Enum.join(path ++ [current_type], " -> ")}" | errors]
    else
      new_path = path ++ [current_type]

      Enum.reduce(dsl_children(dsl), errors, fn child, acc ->
        validate_no_circular_refs(acc, child, new_path)
      end)
    end
  end

  defp valid_signal_structure?(signal) do
    is_map(signal) and
      (Map.has_key?(signal, :type) or Map.has_key?(signal, "type")) and
      (Map.has_key?(signal, :target) or Map.has_key?(signal, "target"))
  end

  defp get_next_version do
    "1.0.#{System.system_time(:second)}"
  end

  defp dsl_type(dsl), do: Map.get(dsl, :type) || Map.get(dsl, "type")
  defp dsl_children(dsl), do: Map.get(dsl, :children) || Map.get(dsl, "children") || []
  defp dsl_signals(dsl), do: Map.get(dsl, :signals) || Map.get(dsl, "signals") || []

  defp normalize_metadata_keys(metadata) when is_map(metadata) do
    Enum.reduce(metadata, metadata, fn
      {:version, value}, acc -> Map.put(acc, "version", value)
      {"version", value}, acc -> Map.put(acc, :version, value)
      {:created_at, value}, acc -> Map.put(acc, "created_at", value)
      {"created_at", value}, acc -> Map.put(acc, :created_at, value)
      {:updated_at, value}, acc -> Map.put(acc, "updated_at", value)
      {"updated_at", value}, acc -> Map.put(acc, :updated_at, value)
      _, acc -> acc
    end)
  end
end
