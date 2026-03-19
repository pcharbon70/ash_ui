defmodule AshUI.Rendering.IURAdapter do
  @moduledoc """
  Adapter for converting Ash IUR to canonical unified_iur format.

  This module handles the conversion from Ash-internal IUR structures
  to the canonical IUR format that renderer packages consume.
  """

  alias AshUI.Compilation.IUR

  @doc """
  Converts an Ash IUR to canonical unified_iur Screen format.

  ## Options
    * `:telemetry` - Whether to emit telemetry events (default: true)

  ## Returns
    * `{:ok, canonical_iur}` - Successfully converted
    * `{:error, reason}` - Conversion failed
  """
  @spec to_canonical(IUR.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def to_canonical(%IUR{} = ash_iur, opts \\ []) do
    telemetry? = Keyword.get(opts, :telemetry, true)

    try do
      canonical = convert_iur(ash_iur)

      if telemetry? do
        :telemetry.execute(
          [:ash_ui, :rendering, :convert_success],
          %{count: 1},
          %{type: ash_iur.type}
        )
      end

      {:ok, canonical}
    rescue
      error ->
        if telemetry? do
          :telemetry.execute(
            [:ash_ui, :rendering, :convert_error],
            %{count: 1},
            %{type: ash_iur.type, error: inspect(error)}
          )
        end

        {:error, {:conversion_failed, error}}
    end
  end

  @doc """
  Checks if a renderer is compatible with the given IUR.

  ## Returns
    * `true` - Compatible
    * `false` - Not compatible
  """
  @spec compatible?(IUR.t(), atom()) :: boolean()
  def compatible?(%IUR{type: :screen}, :live_ui), do: true
  def compatible?(%IUR{type: :screen}, :web_ui), do: true
  def compatible?(%IUR{type: :screen}, :desktop_ui), do: true
  def compatible?(%IUR{}, _renderer), do: false

  # Convert Ash IUR to canonical format
  defp convert_iur(%IUR{type: :screen} = iur) do
    %{
      "type" => "screen",
      "id" => iur.id || generate_id(),
      "name" => iur.name,
      "layout" => convert_layout(iur.attributes["layout"]),
      "children" => Enum.map(iur.children, &convert_element/1),
      "bindings" => Enum.map(iur.bindings, &convert_binding/1),
      "metadata" => iur.metadata,
      "version" => iur.version
    }
  end

  defp convert_iur(%IUR{} = iur) do
    %{
      "type" => atom_to_string(iur.type),
      "id" => iur.id || generate_id(),
      "name" => iur.name,
      "attributes" => iur.attributes,
      "children" => Enum.map(iur.children, &convert_element/1),
      "metadata" => iur.metadata,
      "version" => iur.version
    }
  end

  # Convert element type to unified widget type
  defp convert_element(%IUR{} = element) do
    widget_type = map_element_type(element.type)

    %{
      "type" => widget_type,
      "id" => element.id || generate_id(),
      "name" => element.name,
      "props" => convert_props(element.props, element.type),
      "children" => Enum.map(element.children, &convert_element/1),
      "metadata" => element.metadata
    }
  end

  # Map Ash element types to unified widget types
  defp map_element_type(:text), do: "text"
  defp map_element_type(:button), do: "button"
  defp map_element_type(:textinput), do: "input"
  defp map_element_type(:textarea), do: "textarea"
  defp map_element_type(:select), do: "select"
  defp map_element_type(:checkbox), do: "checkbox"
  defp map_element_type(:radio), do: "radio"
  defp map_element_type(:switch), do: "switch"
  defp map_element_type(:slider), do: "slider"
  defp map_element_type(:row), do: "row"
  defp map_element_type(:column), do: "column"
  defp map_element_type(:grid), do: "grid"
  defp map_element_type(:stack), do: "stack"
  defp map_element_type(:card), do: "card"
  defp map_element_type(:list), do: "list"
  defp map_element_type(:table), do: "table"
  defp map_element_type(:image), do: "image"
  defp map_element_type(:icon), do: "icon"
  defp map_element_type(:divider), do: "divider"
  defp map_element_type(:spacer), do: "spacer"
  defp map_element_type(other), do: atom_to_string(other)

  defp atom_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp atom_to_string(other), do: to_string(other)

  # Convert props with name transformations
  defp convert_props(props, _element_type) when is_map(props) do
    Enum.into(props, %{}, fn {key, value} ->
      {convert_prop_name(key), convert_prop_value(value)}
    end)
  end

  defp convert_props(_, _), do: %{}

  # Convert prop names from camelCase to snake_case
  defp convert_prop_name(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> convert_camel_to_snake()
  end

  defp convert_prop_name(key) when is_binary(key), do: key
  defp convert_prop_name(key), do: to_string(key)

  defp convert_camel_to_snake(name) do
    Regex.replace(~r/([A-Z])/, name, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end

  defp convert_prop_value(value), do: value

  # Convert layout to canonical format
  defp convert_layout(nil), do: "column"
  defp convert_layout(:row), do: "row"
  defp convert_layout(:column), do: "column"
  defp convert_layout(:grid), do: "grid"
  defp convert_layout(:stack), do: "stack"
  defp convert_layout(other), do: atom_to_string(other)

  # Convert binding to canonical signal format
  defp convert_binding(binding) when is_map(binding) do
    signal_type = map_binding_type(binding["binding_type"])

    %{
      "id" => binding["id"],
      "type" => signal_type,
      "source" => convert_binding_source(binding["source"]),
      "target" => binding["target"],
      "transform" => binding["transform"] || %{},
      "element_id" => binding["element_id"],
      "metadata" => binding["metadata"] || %{}
    }
  end

  # Map binding types to signal types
  defp map_binding_type("value"), do: "bidirectional"
  defp map_binding_type("list"), do: "collection"
  defp map_binding_type("action"), do: "event"
  defp map_binding_type(:value), do: "bidirectional"
  defp map_binding_type(:list), do: "collection"
  defp map_binding_type(:action), do: "event"
  defp map_binding_type(other), do: to_string(other)

  # Convert binding source to canonical format
  defp convert_binding_source(source) when is_map(source) do
    source
  end

  defp convert_binding_source(source), do: %{"path" => to_string(source)}

  # Generate unique ID
  defp generate_id do
    UUID.uuid4()
  end
end
