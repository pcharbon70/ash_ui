defmodule AshUI.DSL.Builder do
  @moduledoc """
  Builder functions for creating unified-ui DSL structures.

  Provides helper functions for building unified-ui DSL
  that can be stored in Ash Resource attributes.
  """

  @type dsl_map :: %{
          type: String.t(),
          props: map(),
          children: [dsl_map()],
          signals: [map()]
        }

  @doc """
  Creates a root DSL element.

  The root element is the top-level container for a UI definition.

  ## Options
    * `:type` - The widget type (e.g., "row", "column", "text")
    * `:props` - Map of widget properties
    * `:children` - List of child DSL elements
    * `:signals` - List of signal definitions

  ## Examples

      AshUI.DSL.Builder.root("row", children: [
        AshUI.DSL.Builder.text("Hello, World!")
      ])
  """
  @spec root(String.t(), keyword()) :: dsl_map()
  def root(type, opts \\ []) do
    %{
      type: type,
      props: Keyword.get(opts, :props, %{}),
      children: Keyword.get(opts, :children, []),
      signals: Keyword.get(opts, :signals, [])
    }
  end

  @doc """
  Creates a row layout element.

  Rows arrange children horizontally.

  ## Examples

      row = AshUI.DSL.Builder.row(children: [
        AshUI.DSL.Builder.text("Left"),
        AshUI.DSL.Builder.text("Right")
      ])
  """
  @spec row(keyword()) :: dsl_map()
  def row(opts \\ []) when is_list(opts) do
    props = %{
      spacing: Keyword.get(opts, :spacing, 8),
      align: Keyword.get(opts, :align, :start),
      justify: Keyword.get(opts, :justify, :start)
    }

    root("row", Keyword.put(opts, :props, Map.merge(props, Keyword.get(opts, :props, %{}))))
  end

  @doc """
  Creates a column layout element.

  Columns arrange children vertically.

  ## Examples

      column = AshUI.DSL.Builder.column(children: [
        AshUI.DSL.Builder.text("Top"),
        AshUI.DSL.Builder.text("Bottom")
      ])
  """
  @spec column(keyword()) :: dsl_map()
  def column(opts \\ []) when is_list(opts) do
    props = %{
      spacing: Keyword.get(opts, :spacing, 8),
      align: Keyword.get(opts, :align, :start),
      justify: Keyword.get(opts, :justify, :start)
    }

    root("column", Keyword.put(opts, :props, Map.merge(props, Keyword.get(opts, :props, %{}))))
  end

  @doc """
  Creates a text widget element.

  ## Examples

      text = AshUI.DSL.Builder.text("Hello, World!", size: 16, color: "blue")
  """
  @spec text(String.t(), keyword()) :: dsl_map()
  def text(content, opts \\ []) when is_list(opts) do
    props = %{
      content: content,
      size: Keyword.get(opts, :size, 14),
      color: Keyword.get(opts, :color, "inherit"),
      weight: Keyword.get(opts, :weight, :normal),
      align: Keyword.get(opts, :align, :left)
    }

    root("text", props: props)
  end

  @doc """
  Creates a button widget element.

  ## Examples

      button = AshUI.DSL.Builder.button("Click Me", on_click: "save_action")
  """
  @spec button(String.t(), keyword()) :: dsl_map()
  def button(label, opts \\ []) when is_list(opts) do
    props = %{
      label: label,
      variant: Keyword.get(opts, :variant, :primary),
      size: Keyword.get(opts, :size, :medium),
      disabled: Keyword.get(opts, :disabled, false),
      on_click: Keyword.get(opts, :on_click)
    }

    signals =
      case Keyword.get(opts, :on_click) do
        nil -> []
        action -> [%{type: :event, target: "button", action: action}]
      end

    root("button", props: props, signals: signals)
  end

  @doc """
  Creates an input widget element.

  ## Examples

      input = AshUI.DSL.Builder.input("name", placeholder: "Enter name", value: "")
  """
  @spec input(String.t(), keyword()) :: dsl_map()
  def input(name, opts \\ []) when is_list(opts) do
    props = %{
      name: name,
      type: Keyword.get(opts, :type, :text),
      placeholder: Keyword.get(opts, :placeholder, ""),
      value: Keyword.get(opts, :value, ""),
      disabled: Keyword.get(opts, :disabled, false),
      required: Keyword.get(opts, :required, false)
    }

    signals =
      case Keyword.get(opts, :bind_to) do
        nil -> []
        binding -> [%{type: :bidirectional, target: name, source: binding}]
      end

    root("input", props: props, signals: signals)
  end

  @doc """
  Creates a container element with custom props.

  ## Examples

      container = AshUI.DSL.Builder.container("div", padding: 16, background: "white")
  """
  @spec container(String.t(), keyword()) :: dsl_map()
  def container(type, opts \\ []) when is_list(opts) do
    props = Enum.into(opts, %{})
    root(type, props: props, children: Keyword.get(opts, :children, []))
  end

  @doc """
  Adds a signal binding to an element.

  ## Examples

      element = AshUI.DSL.Builder.text("Hello")
      element = AshUI.DSL.Builder.add_signal(element, :bidirectional, "name", "User.name")
  """
  @spec add_signal(dsl_map(), atom(), String.t(), String.t()) :: dsl_map()
  def add_signal(element, type, target, source) do
    signal = %{
      type: type,
      target: target,
      source: source
    }

    Map.update(element, :signals, [signal], fn signals -> signals ++ [signal] end)
  end

  @doc """
  Merges multiple elements into a single DSL structure.

  ## Examples

      combined = AshUI.DSL.Builder.merge([
        AshUI.DSL.Builder.text("Hello"),
        AshUI.DSL.Builder.text("World")
      ])
  """
  @spec merge([dsl_map()]) :: dsl_map()
  def merge(elements) when is_list(elements) do
    root("fragment", children: elements)
  end

  @doc """
  Converts a DSL structure to a map for database storage.

  ## Examples

      dsl_map = AshUI.DSL.Builder.to_store(dsl_structure)
  """
  @spec to_store(dsl_map()) :: map()
  def to_store(dsl) when is_map(dsl) do
    # Recursively convert DSL to plain map
    dsl
    |> Map.update!(:children, &Enum.map(&1, fn child -> to_store(child) end))
    |> Map.update!(:signals, &Enum.map(&1, fn signal -> Map.new(signal) end))
    |> Map.update!(:props, &Map.new/1)
  end

  @doc """
  Converts stored map back to DSL structure.

  ## Examples

      dsl_structure = AshUI.DSL.Builder.from_store(stored_map)
  """
  @spec from_store(map()) :: dsl_map()
  def from_store(stored) when is_map(stored) do
    %{
      type: fetch_store_value(stored, :type),
      props: fetch_store_value(stored, :props, %{}) |> Map.new(),
      children:
        stored
        |> fetch_store_value(:children, [])
        |> Enum.map(&from_store/1),
      signals:
        stored
        |> fetch_store_value(:signals, [])
        |> Enum.map(&normalize_signal/1),
      metadata: fetch_store_value(stored, :metadata, %{})
    }
  end

  @doc """
  Validates a DSL structure against unified-ui format.

  ## Returns
    * `:ok` - Valid DSL
    * `{:error, errors}` - List of validation errors

  ## Examples

      case AshUI.DSL.Builder.validate(dsl) do
        :ok -> :valid
        {:error, errors} -> # handle errors
      end
  """
  @spec validate(dsl_map()) :: :ok | {:error, [String.t()]}
  def validate(dsl) do
    errors =
      []
      |> validate_type(dsl)
      |> validate_children(dsl)
      |> validate_signals(dsl)
      |> validate_props(dsl)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp fetch_store_value(map, key, default \\ nil) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp normalize_signal(signal) when is_map(signal) do
    Enum.into(signal, %{}, fn {key, value} ->
      {normalize_signal_key(key), value}
    end)
  end

  defp normalize_signal(signal), do: signal

  defp normalize_signal_key("type"), do: :type
  defp normalize_signal_key("target"), do: :target
  defp normalize_signal_key("source"), do: :source
  defp normalize_signal_key("transform"), do: :transform
  defp normalize_signal_key("action"), do: :action
  defp normalize_signal_key(key), do: key

  # Private validation functions

  defp validate_type(errors, %{type: type}) when is_binary(type), do: errors
  defp validate_type(errors, _), do: ["Missing or invalid type field" | errors]

  defp validate_children(errors, %{children: children}) when is_list(children),
    do: errors

  defp validate_children(errors, _), do: ["Children must be a list" | errors]

  defp validate_signals(errors, %{signals: signals}) when is_list(signals), do: errors
  defp validate_signals(errors, _), do: ["Signals must be a list" | errors]

  defp validate_props(errors, %{props: props}) when is_map(props), do: errors
  defp validate_props(errors, _), do: ["Props must be a map" | errors]
end
