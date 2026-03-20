defmodule AshUI.Signal.CloudEvents do
  @moduledoc """
  CloudEvents-compatible signal format for unified signal transport.

  Wraps Ash UI signals in the CloudEvents standard format for
  compatibility with the unified-ui signal transport specification.
  """

  alias AshUI.Signal.Struct

  @type cloud_event :: %{
          required(String.t()) => term()
        }

  @doc """
  Converts an Ash UI signal to CloudEvents format.

  ## CloudEvents Spec
  https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents.md

  ## Returns
    * CloudEvents map with required fields

  ## Examples

      iex> signal = AshUI.Signal.Struct.bidirectional("User.name", "input-1")
      iex> AshUI.Signal.CloudEvents.to_cloud_event(signal)
      %{
        "id" => "signal-123",
        "source" => "ash-ui/User.name",
        "type" => "ash_ui.signal.bidirectional",
        "datacontenttype" => "application/json",
        "data" => %{...}
      }
  """
  @spec to_cloud_event(Struct.t()) :: cloud_event()
  def to_cloud_event(%Struct{} = signal) do
    %{
      "id" => signal.id,
      "source" => build_source(signal),
      "type" => build_type(signal),
      "datacontenttype" => "application/json",
      "data" => build_data(signal),
      "time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "ashui" => %{
        "target" => signal.target,
        "transform" => signal.transform
      }
    }
  end

  @doc """
  Converts a CloudEvents event back to an Ash UI signal.

  ## Returns
    * `{:ok, AshUI.Signal.Struct.t()}` or `{:error, reason}`
  """
  @spec from_cloud_event(cloud_event()) :: {:ok, Struct.t()} | {:error, term()}
  def from_cloud_event(cloud_event) when is_map(cloud_event) do
    with :ok <- validate_cloud_event(cloud_event),
         {:ok, type} <- parse_signal_type(cloud_event["type"]),
         {:ok, source} <- parse_signal_source(cloud_event["source"]) do
      signal = Struct.new(
        id: cloud_event["id"],
        source: source,
        target: get_in(cloud_event, ["ashui", "target"]) || "",
        type: type,
        transform: get_in(cloud_event, ["ashui", "transform"]),
        metadata: extract_metadata(cloud_event)
      )

      {:ok, signal}
    end
  end

  @doc """
  Wraps a list of signals in a CloudEvents batch envelope.

  ## Returns
    * CloudEvents batch envelope
  """
  @spec batch([Struct.t()]) :: map()
  def batch(signals) when is_list(signals) do
    events = Enum.map(signals, &to_cloud_event/1)

    %{
      "specversion" => "1.0",
      "id" => generate_batch_id(),
      "source" => "ash-ui",
      "type" => "ash_ui.signal.batch",
      "datacontenttype" => "application/json",
      "data" => %{"events" => events},
      "time" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @type envelopes :: :json | :binary | :text

  @doc """
  Serializes a CloudEvents event to a specific format.

  ## Options
    * `:format` - :json, :binary, or :text (default: :json)

  ## Returns
    * Serialized event

  ## Examples

      iex> signal = AshUI.Signal.Struct.bidirectional("User.name", "input-1")
      iex> AshUI.Signal.CloudEvents.serialize(signal, :json)
      "{\\"id\\": \\"signal-123\\", ...}"
  """
  @spec serialize(cloud_event() | Struct.t(), keyword()) :: String.t() | binary()
  def serialize(cloud_event_or_signal, opts \\ [])
  def serialize(%Struct{} = signal, opts) do
    event = to_cloud_event(signal)
    serialize(event, opts)
  end

  def serialize(cloud_event, opts) when is_map(cloud_event) do
    format = Keyword.get(opts, :format, :json)

    case format do
      :json ->
        Jason.encode!(cloud_event)

      :binary ->
        # In production, would use proper binary encoding
        Jason.encode!(cloud_event)

      :text ->
        # Human-readable text format
        format_text(cloud_event)
    end
  end

  # Private functions

  defp build_source(%Struct{source: source}) do
    resource = Map.get(source, "resource", "")
    field = Map.get(source, "field", "")
    "ash-ui/#{resource}/#{field}"
  end

  defp build_type(%Struct{type: type}) do
    "ash_ui.signal.#{Atom.to_string(type)}"
  end

  defp build_data(%Struct{} = signal) do
    %{
      "source" => signal.source,
      "target" => signal.target,
      "value" => get_current_value(signal)
    }
  end

  defp get_current_value(%Struct{}) do
    # In production, would fetch current value from context
    nil
  end

  defp validate_cloud_event(cloud_event) do
    required = ["id", "source", "type"]

    missing =
      Enum.reject(required, fn key -> Map.has_key?(cloud_event, key) end)

    if missing == [] do
      :ok
    else
      {:error, {:missing_required_fields, missing}}
    end
  end

  defp parse_signal_type("ash_ui.signal." <> type_str) do
    type = String.to_existing_atom(type_str)

    if type in [:bidirectional, :collection, :event] do
      {:ok, type}
    else
      {:error, {:unknown_type, type}}
    end
  rescue
    ArgumentError -> {:error, {:unknown_type, type_str}}
  end

  defp parse_signal_type(type), do: {:error, {:unknown_type, type}}

  defp parse_signal_source("ash-ui/" <> rest) do
    case String.split(rest, "/", parts: 2) do
      [resource, field] ->
        {:ok,
         %{
           "type" => "field",
           "resource" => resource,
           "field" => field
         }}

      _ ->
        {:error, {:invalid_source, rest}}
    end
  end

  defp parse_signal_source(source), do: {:error, {:invalid_source, source}}

  defp extract_metadata(cloud_event) do
    # Extract time and other CloudEvents metadata
    time = Map.get(cloud_event, "time")
    %{"cloud_events" => %{"time" => time}}
  end

  defp generate_batch_id do
    "batch_#{System.system_time(:millisecond)}_#{:rand.uniform(10000)}"
  end

  defp format_text(cloud_event) do
    """
    CloudEvent: #{cloud_event["type"]}
    ID: #{cloud_event["id"]}
    Source: #{cloud_event["source"]}
    Time: #{cloud_event["time"]}
    """
  end

  @type envelope :: %{
          required(String.t()) => term()
        }
end
