defmodule AshUI.Compiler.Extensions do
  @moduledoc """
  Custom widget and layout registration for unified-ui compiler.

  Allows registration of custom unified-ui widgets and layouts
  that extend the built-in catalog.
  """

  @type widget_def :: %{
          type: String.t(),
          module: module(),
          props: [map()],
          validate: (map() -> :ok | {:error, term()}),
          compile: (map() -> map())
        }

  @type layout_def :: %{
          type: String.t(),
          module: module(),
          props: [map()],
          validate: (map() -> :ok | {:error, term()}),
          compile: (map() -> map())
        }

  @doc """
  Registers a custom widget type.

  ## Parameters
    * `type` - Widget type identifier (e.g., "custom:calendar")
    * `definition` - Widget definition map

  ## Definition Keys
    * `:module` - Module implementing the widget
    * `:props` - List of property definitions
    * `:validate` - Function to validate widget props
    * `:compile` - Function to compile widget to IUR

  ## Examples

      AshUI.Compiler.Extensions.register_widget("custom:calendar", %{
        module: MyApp.UI.Calendar,
        props: [
          %{name: :selected_date, type: :date, required: false},
          %{name: :on_change, type: :action, required: false}
        ],
        validate: fn props -> :ok end,
        compile: fn props -> %{type: "calendar", props: props} end
      })
  """
  @spec register_widget(String.t(), widget_def()) :: :ok | {:error, term()}
  def register_widget(type, definition) when is_binary(type) and is_map(definition) do
    with :ok <- validate_widget_definition(definition),
         :ok <- store_widget(type, definition) do
      :ok
    end
  end

  @doc """
  Registers a custom layout type.

  ## Parameters
    * `type` - Layout type identifier (e.g., "custom:grid")
    * `definition` - Layout definition map

  ## Definition Keys
    * `:module` - Module implementing the layout
    * `:props` - List of property definitions
    * `:validate` - Function to validate layout props
    * `:compile` - Function to compile layout to IUR

  ## Examples

      AshUI.Compiler.Extensions.register_layout("custom:masonry", %{
        module: MyApp.UI.Masonry,
        props: [
          %{name: :columns, type: :integer, default: 3},
          %{name: :gap, type: :integer, default: 8}
        ],
        validate: fn props -> :ok end,
        compile: fn props, children -> %{type: "masonry", props: props, children: children} end
      })
  """
  @spec register_layout(String.t(), layout_def()) :: :ok | {:error, term()}
  def register_layout(type, definition) when is_binary(type) and is_map(definition) do
    with :ok <- validate_layout_definition(definition),
         :ok <- store_layout(type, definition) do
      :ok
    end
  end

  @doc """
  Gets all registered widgets.

  ## Examples

      widgets = AshUI.Compiler.Extensions.registered_widgets()
  """
  @spec registered_widgets() :: [widget_def()]
  def registered_widgets do
    try do
      :ets.tab2list(:ash_ui_widgets)
      |> Enum.map(fn {_type, def} -> def end)
    rescue
      ArgumentError -> []
    end
  end

  @doc """
  Gets all registered layouts.

  ## Examples

      layouts = AshUI.Compiler.Extensions.registered_layouts()
  """
  @spec registered_layouts() :: [layout_def()]
  def registered_layouts do
    try do
      :ets.tab2list(:ash_ui_layouts)
      |> Enum.map(fn {_type, def} -> def end)
    rescue
      ArgumentError -> []
    end
  end

  @doc """
  Looks up a widget definition by type.

  ## Examples

      {:ok, widget} = AshUI.Compiler.Extensions.get_widget("custom:calendar")
  """
  @spec get_widget(String.t()) :: {:ok, widget_def()} | {:error, :not_found}
  def get_widget(type) do
    try do
      case :ets.lookup(:ash_ui_widgets, type) do
        [{^type, definition}] -> {:ok, definition}
        [] -> {:error, :not_found}
      end
    rescue
      ArgumentError -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a layout definition by type.

  ## Examples

      {:ok, layout} = AshUI.Compiler.Extensions.get_layout("custom:masonry")
  """
  @spec get_layout(String.t()) :: {:ok, layout_def()} | {:error, :not_found}
  def get_layout(type) do
    try do
      case :ets.lookup(:ash_ui_layouts, type) do
        [{^type, definition}] -> {:ok, definition}
        [] -> {:error, :not_found}
      end
    rescue
      ArgumentError -> {:error, :not_found}
    end
  end

  @doc """
  Checks if a widget type is registered.

  ## Examples

      AshUI.Compiler.Extensions.widget_registered?("custom:calendar")
  """
  @spec widget_registered?(String.t()) :: boolean()
  def widget_registered?(type) do
    case get_widget(type) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Checks if a layout type is registered.

  ## Examples

      AshUI.Compiler.Extensions.layout_registered?("custom:masonry")
  """
  @spec layout_registered?(String.t()) :: boolean()
  def layout_registered?(type) do
    case get_layout(type) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Compiles a custom widget instance.

  ## Examples

      {:ok, iur} = AshUI.Compiler.Extensions.compile_widget("custom:calendar", props)
  """
  @spec compile_widget(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def compile_widget(type, props) when is_map(props) do
    with {:ok, definition} <- get_widget(type),
         :ok <- validate_widget_props(definition, props),
         compiled <- definition.compile.(props) do
      {:ok, compiled}
    end
  end

  @doc """
  Compiles a custom layout instance.

  ## Examples

      {:ok, iur} = AshUI.Compiler.Extensions.compile_layout("custom:masonry", props, children)
  """
  @spec compile_layout(String.t(), map(), [map()]) :: {:ok, map()} | {:error, term()}
  def compile_layout(type, props, children \\ []) when is_map(props) and is_list(children) do
    with {:ok, definition} <- get_layout(type),
         :ok <- validate_layout_props(definition, props),
         compiled <- definition.compile.(props, children) do
      {:ok, compiled}
    end
  end

  @doc """
  Unregisters a widget type.

  ## Examples

      AshUI.Compiler.Extensions.unregister_widget("custom:calendar")
  """
  @spec unregister_widget(String.t()) :: :ok
  def unregister_widget(type) do
    try do
      :ets.delete(:ash_ui_widgets, type)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @doc """
  Unregisters a layout type.

  ## Examples

      AshUI.Compiler.Extensions.unregister_layout("custom:masonry")
  """
  @spec unregister_layout(String.t()) :: :ok
  def unregister_layout(type) do
    try do
      :ets.delete(:ash_ui_layouts, type)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @doc """
  Initializes the extension registries.

  Called during application startup.
  """
  @spec init() :: :ok
  def init do
    try do
      :ets.new(:ash_ui_widgets, [:named_table, :public, read_concurrency: true])
      :ets.new(:ash_ui_layouts, [:named_table, :public, read_concurrency: true])
    rescue
      ArgumentError ->
        # Tables already exist
        :ok
    end

    :ok
  end

  # Private functions

  defp validate_widget_definition(definition) do
    required_keys = [:module, :props, :validate, :compile]
    has_required = Enum.all?(required_keys, &Map.has_key?(definition, &1))

    if has_required do
      :ok
    else
      {:error, {:invalid_definition, "Missing required keys: #{inspect(required_keys -- Map.keys(definition))}"}}
    end
  end

  defp validate_layout_definition(definition) do
    required_keys = [:module, :props, :validate, :compile]
    has_required = Enum.all?(required_keys, &Map.has_key?(definition, &1))

    if has_required do
      :ok
    else
      {:error, {:invalid_definition, "Missing required keys: #{inspect(required_keys -- Map.keys(definition))}"}}
    end
  end

  defp store_widget(type, definition) do
    ensure_tables()
    :ets.insert(:ash_ui_widgets, {type, definition})
    :ok
  end

  defp store_layout(type, definition) do
    ensure_tables()
    :ets.insert(:ash_ui_layouts, {type, definition})
    :ok
  end

  defp ensure_tables do
    init()
  end

  defp validate_widget_props(definition, props) do
    case definition.validate.(props) do
      :ok -> :ok
      error -> error
    end
  end

  defp validate_layout_props(definition, props) do
    case definition.validate.(props) do
      :ok -> :ok
      error -> error
    end
  end

  @doc """
  Gets available widget types (built-in and custom).

  ## Examples

      types = AshUI.Compiler.Extensions.available_widget_types()
  """
  @spec available_widget_types() :: [String.t()]
  def available_widget_types do
    built_in = ["text", "button", "input", "checkbox", "select", "image", "spacer"]
    custom = Enum.map(registered_widgets(), & & &1.type)

    built_in ++ custom
  end

  @doc """
  Gets available layout types (built-in and custom).

  ## Examples

      types = AshUI.Compiler.Extensions.available_layout_types()
  """
  @spec available_layout_types() :: [String.t()]
  def available_layout_types do
    built_in = ["row", "column", "grid", "stack", "fragment", "container"]
    custom = Enum.map(registered_layouts(), & & &1.type)

    built_in ++ custom
  end

  @doc """
  Validates a widget against the unified-ui spec.

  ## Returns
    * `:ok` - Valid widget
    * `{:error, errors}` - List of validation errors

  ## Examples

      case AshUI.Compiler.Extensions.validate_widget_spec(widget) do
        :ok -> :valid
        {:error, errors} -> # handle errors
      end
  """
  @spec validate_widget_spec(widget_def()) :: :ok | {:error, [String.t()]}
  def validate_widget_spec(definition) do
    errors =
      []
      |> validate_widget_props_spec(definition)
      |> validate_widget_module(definition)
      |> validate_widget_compile(definition)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp validate_widget_props_spec(definition, errors) do
    props = definition.props || []

    Enum.reduce(props, errors, fn prop_spec, acc ->
      case validate_prop_spec(prop_spec) do
        :ok -> acc
        {:error, error} -> [error | acc]
      end
    end)
  end

  defp validate_prop_spec(prop_spec) do
    required = [:name, :type]
    has_required = Enum.all?(required, &Map.has_key?(prop_spec, &1))

    if has_required do
      :ok
    else
      {:error, "Invalid prop spec: #{inspect(prop_spec)}"}
    end
  end

  defp validate_widget_module(definition, errors) do
    if Code.ensure_loaded?(definition.module) do
      errors
    else
      ["Module #{inspect(definition.module)} not loaded" | errors]
    end
  end

  defp validate_widget_compile(definition, errors) do
    if is_function(definition.compile) do
      errors
    else
      ["Widget must have a compile function" | errors]
    end
  end

  @doc """
  Validates a layout against the unified-ui spec.

  ## Returns
    * `:ok` - Valid layout
    * `{:error, errors}` - List of validation errors
  """
  @spec validate_layout_spec(layout_def()) :: :ok | {:error, [String.t()]}
  def validate_layout_spec(definition) do
    errors =
      []
      |> validate_layout_props_spec(definition)
      |> validate_layout_module(definition)
      |> validate_layout_compile(definition)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp validate_layout_props_spec(definition, errors) do
    props = definition.props || []

    Enum.reduce(props, errors, fn prop_spec, acc ->
      case validate_prop_spec(prop_spec) do
        :ok -> acc
        {:error, error} -> [error | acc]
      end
    end)
  end

  defp validate_layout_module(definition, errors) do
    if Code.ensure_loaded?(definition.module) do
      errors
    else
      ["Module #{inspect(definition.module)} not loaded" | errors]
    end
  end

  defp validate_layout_compile(definition, errors) do
    if is_function(definition.compile) do
      errors
    else
      ["Layout must have a compile function" | errors]
    end
  end
end
