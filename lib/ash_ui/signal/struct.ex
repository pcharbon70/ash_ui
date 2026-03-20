defmodule AshUI.Signal.Struct do
  @moduledoc """
  Signal structure matching unified-ui signal transport spec.

  Provides the canonical signal format used throughout Ash UI
  for communication between UI elements and Ash resources.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          source: signal_source(),
          target: String.t(),
          type: signal_type(),
          transform: map() | nil,
          metadata: map()
        }

  @type signal_type :: :bidirectional | :collection | :event
  @type signal_source :: %{
          type: String.t(),
          resource: String.t() | nil,
          field: String.t() | nil,
          action: String.t() | nil,
          relationship: String.t() | nil
        }

  defstruct [
    :id,
    :source,
    :target,
    :type,
    :transform,
    metadata: %{}
  ]

  @doc """
  Creates a new signal struct.

  ## Options
    * `:id` - Unique signal identifier
    * `:source` - Signal source map with type/resource/field
    * `:target` - Target element ID
    * `:type` - Signal type (:bidirectional, :collection, :event)
    * `:transform` - Transformation rules
    * `:metadata` - Additional metadata

  ## Examples

      iex> AshUI.Signal.Struct.new(
      ...>   id: "signal-1",
      ...>   source: %{"type" => "field", "resource" => "User", "field" => "name"},
      ...>   target: "input-name",
      ...>   type: :bidirectional
      ...> )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    id = Keyword.get(opts, :id) || generate_id()
    source = Keyword.get(opts, :source, %{})
    target = Keyword.get(opts, :target, "")
    type = Keyword.get(opts, :type, :bidirectional)
    transform = Keyword.get(opts, :transform)
    metadata = Keyword.get(opts, :metadata, %{})

    %__MODULE__{
      id: id,
      source: normalize_source(source),
      target: target,
      type: type,
      transform: transform,
      metadata: metadata
    }
  end

  @doc """
  Creates a bidirectional signal for two-way data binding.

  ## Examples

      iex> AshUI.Signal.Struct.bidirectional("User.name", "input-name")
  """
  @spec bidirectional(String.t(), String.t(), keyword()) :: t()
  def bidirectional(source_path, target, opts \\ []) do
    source = parse_source_path(source_path)

    new(
      id: Keyword.get(opts, :id),
      source: source,
      target: target,
      type: :bidirectional,
      transform: Keyword.get(opts, :transform),
      metadata: Keyword.get(opts, :metadata, %{"direction" => "bidirectional"})
    )
  end

  @doc """
  Creates a collection signal for list binding.

  ## Examples

      iex> AshUI.Signal.Struct.collection("Post.comments", "list-comments")
  """
  @spec collection(String.t(), String.t(), keyword()) :: t()
  def collection(source_path, target, opts \\ []) do
    source = parse_collection_source_path(source_path)

    new(
      id: Keyword.get(opts, :id),
      source: source,
      target: target,
      type: :collection,
      transform: Keyword.get(opts, :transform),
      metadata: Keyword.get(opts, :metadata, %{"direction" => "collection"})
    )
  end

  @doc """
  Creates an event signal for action binding.

  ## Examples

      iex> AshUI.Signal.Struct.event("User.create", "button-submit")
  """
  @spec event(String.t(), String.t(), keyword()) :: t()
  def event(source_path, target, opts \\ []) do
    source = parse_source_path(source_path)

    new(
      id: Keyword.get(opts, :id),
      source: source,
      target: target,
      type: :event,
      transform: Keyword.get(opts, :transform),
      metadata: Keyword.get(opts, :metadata, %{"direction" => "event"})
    )
  end

  @doc """
  Validates a signal struct.

  ## Returns
    * `:ok` - Valid signal
    * `{:error, reasons}` - List of validation errors
  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = signal) do
    errors =
      []
      |> validate_id(signal)
      |> validate_target(signal)
      |> validate_type(signal)
      |> validate_source(signal)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  defp validate_id(errors, %__MODULE__{id: id}) when is_binary(id) and id != "", do: errors
  defp validate_id(errors, _), do: ["Signal ID is required and must be a non-empty string" | errors]

  defp validate_target(errors, %__MODULE__{target: target}) when is_binary(target) and target != "",
    do: errors

  defp validate_target(errors, _), do: ["Signal target is required and must be a non-empty string" | errors]

  defp validate_type(errors, %__MODULE__{type: type}) when type in [:bidirectional, :collection, :event],
    do: errors

  defp validate_type(errors, _), do: ["Signal type must be :bidirectional, :collection, or :event" | errors]

  defp validate_source(errors, %__MODULE__{source: source}) when is_map(source) do
    if Map.has_key?(source, "type") do
      errors
    else
      ["Signal source must have a 'type' key" | errors]
    end
  end

  defp validate_source(errors, _), do: ["Signal source must be a map" | errors]

  # Parse source path string into source map
  defp parse_source_path(path) when is_binary(path) do
    case String.split(path, ".") do
      [resource] ->
        %{"type" => "resource", "resource" => resource}

      [resource, action] when action in ["create", "update", "delete"] ->
        %{"type" => "action", "resource" => resource, "action" => action}

      [resource, field] ->
        %{"type" => "field", "resource" => resource, "field" => field}

      parts ->
        # Handle nested relationships
        {:ok, source} = parse_relationship_path(parts)
        source
    end
  end

  defp parse_source_path(source) when is_map(source), do: normalize_source(source)

  defp parse_collection_source_path(path) when is_binary(path) do
    case String.split(path, ".", trim: true) do
      [resource] ->
        %{"type" => "resource", "resource" => resource}

      [resource, relationship] ->
        %{"type" => "relationship", "resource" => resource, "relationship" => relationship}

      [resource | relationship_parts] ->
        %{
          "type" => "relationship",
          "resource" => resource,
          "relationship" => Enum.join(relationship_parts, ".")
        }
    end
  end

  defp parse_collection_source_path(source) when is_map(source), do: normalize_source(source)

  defp parse_relationship_path([resource | relationship_parts]) do
    {
      :ok,
      %{
        "type" => "relationship",
        "resource" => resource,
        "path" => relationship_parts
      }
    }
  end

  # Normalize source map to ensure required fields
  defp normalize_source(source) when is_map(source) and map_size(source) == 0, do: %{}

  defp normalize_source(source) when is_map(source) do
    Map.put_new(source, "type", "custom")
  end

  # Generate unique signal ID
  defp generate_id do
    "signal_#{System.system_time(:millisecond)}_#{:rand.uniform(10000)}"
  end
end
