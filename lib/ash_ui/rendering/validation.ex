defmodule AshUI.Rendering.Validation do
  @moduledoc """
  Validation functions for IUR conversion stages.

  Provides validation at each conversion stage with detailed error reporting.
  """

  alias AshUI.Compilation.IUR
  alias AshUI.Rendering.ConversionError

  @doc """
  Validates an Ash IUR before canonical conversion.

  ## Returns
    * `:ok` - Valid IUR
    * `{:error, ConversionError.t()}` - Validation failed
  """
  @spec validate_ash_iur(IUR.t()) :: :ok | {:error, ConversionError.t()}
  def validate_ash_iur(%IUR{type: nil}) do
    {:error, ConversionError.missing_field(:ash_iur_validation, nil, :type)}
  end

  def validate_ash_iur(%IUR{type: type}) when not is_atom(type) do
    {:error,
     ConversionError.new(:ash_iur_validation,
       reason: "type must be an atom, got: #{inspect(type)}"
     )}
  end

  def validate_ash_iur(%IUR{} = iur) do
    with :ok <- validate_children(iur),
         :ok <- validate_bindings(iur) do
      :ok
    end
  end

  # Validate children have valid structure
  defp validate_children(%IUR{children: children}) do
    Enum.reduce_while(children, :ok, fn child, _acc ->
      case validate_child(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_child(%IUR{type: nil} = child) do
    {:error, ConversionError.missing_field(:child_validation, child.id, :type)}
  end

  defp validate_child(%IUR{type: type}) when not is_atom(type) do
    {:error,
     ConversionError.new(:child_validation,
       reason: "child type must be an atom, got: #{inspect(type)}"
     )}
  end

  defp validate_child(_), do: :ok

  # Validate bindings have valid structure
  defp validate_bindings(%IUR{bindings: bindings}) do
    Enum.reduce_while(bindings, :ok, fn binding, _acc ->
      case validate_binding(binding) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_binding(binding) when is_map(binding) do
    cond do
      !Map.has_key?(binding, "source") && !Map.has_key?(binding, :source) ->
        {:error, ConversionError.missing_field(:binding_validation, binding["id"], :source)}

      !Map.has_key?(binding, "target") && !Map.has_key?(binding, :target) ->
        {:error, ConversionError.missing_field(:binding_validation, binding["id"], :target)}

      true ->
        :ok
    end
  end

  @doc """
  Validates canonical IUR structure after conversion.

  ## Returns
    * `:ok` - Valid canonical IUR
    * `{:error, ConversionError.t()}` - Validation failed
  """
  @spec validate_canonical_iur(map()) :: :ok | {:error, ConversionError.t()}
  def validate_canonical_iur(canonical_iur) when is_map(canonical_iur) do
    with :ok <- validate_canonical_root(canonical_iur),
         :ok <- validate_canonical_children(canonical_iur) do
      :ok
    end
  end

  defp validate_canonical_root(iur) do
    case Map.get(iur, "type") do
      nil ->
        {:error, ConversionError.missing_field(:canonical_validation, nil, "type")}

      type when is_binary(type) ->
        :ok

      type ->
        {:error,
         ConversionError.new(:canonical_validation,
           reason: "type must be a string, got: #{inspect(type)}"
         )}
    end
  end

  defp validate_canonical_children(%{"children" => children}) when is_list(children) do
    Enum.reduce_while(children, :ok, fn child, _acc ->
      case validate_canonical_child(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_canonical_children(_), do: :ok

  defp validate_canonical_child(child) when is_map(child) do
    if Map.has_key?(child, "type") do
      :ok
    else
      id = Map.get(child, "id", "unknown")
      {:error, ConversionError.missing_field(:canonical_child_validation, id, "type")}
    end
  end

  @doc """
  Collects all validation errors without stopping at first failure.

  ## Returns
    * `{:ok, []}` - No errors
    * `{:error, [ConversionError.t()]}` - List of errors
  """
  @spec validate_all(IUR.t()) :: {:ok, []} | {:error, [ConversionError.t()]}
  def validate_all(%IUR{} = iur) do
    errors =
      []
      |> collect_child_errors(iur.children, iur)
      |> collect_binding_errors(iur.bindings, iur)
      |> collect_attribute_errors(iur)

    if errors == [] do
      {:ok, []}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp collect_child_errors(errors, children, parent_iur) do
    Enum.reduce(children, errors, fn child, acc ->
      case validate_child(child) do
        :ok -> acc
        {:error, error} -> [error | acc]
      end
    end)
  end

  defp collect_binding_errors(errors, bindings, _parent_iur) do
    Enum.reduce(bindings, errors, fn binding, acc ->
      case validate_binding(binding) do
        :ok -> acc
        {:error, error} -> [error | acc]
      end
    end)
  end

  defp collect_attribute_errors(errors, %IUR{attributes: attrs}) do
    required_attrs = [:type]

    Enum.reduce(required_attrs, errors, fn attr, acc ->
      if Map.has_key?(attrs, attr) or Map.has_key?(attrs, Atom.to_string(attr)) do
        acc
      else
        [ConversionError.missing_field(:attribute_validation, nil, attr) | acc]
      end
    end)
  end

  @doc """
  Provides detailed error location information.

  ## Returns
    * A map with location details for error reporting
  """
  @spec error_location(ConversionError.t(), IUR.t()) :: map()
  def error_location(%ConversionError{element_id: id}, _iur) when not is_nil(id) do
    %{
      "location" => "element",
      "element_id" => id,
      "suggestion" => "Check the element definition for #{id}"
    }
  end

  def error_location(%ConversionError{phase: phase}, %IUR{id: id, name: name}) do
    %{
      "location" => "root",
      "screen_id" => id,
      "screen_name" => name,
      "phase" => phase,
      "suggestion" => "Check the #{phase} phase for screen '#{name || id}'"
    }
  end
end
