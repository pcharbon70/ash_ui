defmodule AshUI.Rendering.ConversionError do
  @moduledoc """
  Structured error type for IUR conversion failures.

  Provides detailed error information for debugging and user feedback.
  """

  defexception [:phase, :element_id, :reason, :details]

  @type t :: %__MODULE__{
          phase: atom(),
          element_id: String.t() | nil,
          reason: term(),
          details: map()
        }

  @doc """
  Creates a new conversion error.
  """
  @spec new(atom(), keyword()) :: t()
  def new(phase, opts \\ []) do
    element_id = Keyword.get(opts, :element_id)
    reason = Keyword.get(opts, :reason)
    details = Keyword.get(opts, :details, %{})

    %__MODULE__{
      phase: phase,
      element_id: element_id,
      reason: reason,
      details: details
    }
  end

  @doc """
  Formats the error for user display.
  """
  @spec format_message(t()) :: String.t()
  def format_message(%__MODULE__{} = error) do
    base = "Conversion error in phase #{inspect(error.phase)}"

    base =
      if error.element_id do
        base <> " for element #{error.element_id}"
      else
        base
      end

    base <> ": #{format_reason(error.reason)}"
  end

  @impl true
  @doc """
  Returns the exception message for logging and user-facing surfaces.
  """
  def message(%__MODULE__{} = error), do: format_message(error)

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  @doc """
  Creates an error for invalid element type.
  """
  @spec invalid_element_type(String.t() | nil, atom()) :: t()
  def invalid_element_type(element_id, type) do
    new(:element_type_validation,
      element_id: element_id,
      reason: "unknown element type: #{inspect(type)}",
      details: %{type: type}
    )
  end

  @doc """
  Creates an error for invalid binding source.
  """
  @spec invalid_binding_source(String.t() | nil, term()) :: t()
  def invalid_binding_source(element_id, source) do
    new(:binding_source_validation,
      element_id: element_id,
      reason: "invalid binding source: #{inspect(source)}",
      details: %{source: source}
    )
  end

  @doc """
  Creates an error for missing required field.
  """
  @spec missing_field(atom(), String.t() | nil, atom()) :: t()
  def missing_field(phase, element_id, field) do
    new(phase,
      element_id: element_id,
      reason: "missing required field: #{field}",
      details: %{field: field}
    )
  end

  @doc """
  Creates an error for validation failure.
  """
  @spec validation_failed(atom(), String.t() | nil, term()) :: t()
  def validation_failed(phase, element_id, validation_errors) do
    new(phase,
      element_id: element_id,
      reason: "validation failed",
      details: %{errors: validation_errors}
    )
  end
end
