defmodule AshUI.Compiler do
  @moduledoc """
  Compiler that converts Ash Resources to IUR structures.

  This module handles the compilation of Ash UI resources (Screen, Element, Binding)
  into the internal IUR (Intermediate UI Representation) format.

  Phase 6 adds unified-ui compiler integration with caching.
  """

  require Ash.Query
  require Logger

  alias AshUI.Compilation.IUR
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding
  alias AshUI.DSL.Storage
  alias AshUI.Telemetry

  @type compile_result :: {:ok, IUR.t()} | {:error, term()}

  @doc """
  Compiles a screen resource to an IUR structure.

  ## Options
    * `:load_elements` - Whether to load associated elements (default: true)
    * `load_bindings` - Whether to load associated bindings (default: true)
    * `use_cache` - Whether to use compilation cache (default: true)
    * `:actor` - Actor for authorization
    * `:tenant` - Tenant for multi-tenancy
  """
  @spec compile(Screen.t() | String.t() | integer(), keyword()) :: compile_result()
  def compile(screen, opts \\ [])

  def compile(screen_id, opts) when is_binary(screen_id) or is_integer(screen_id) do
    started_at = System.monotonic_time()
    metadata = compile_metadata(screen_id, opts)
    Telemetry.emit(:compilation, :compile_start, %{count: 1}, metadata)

    result = do_compile_by_id(screen_id, opts)

    emit_compile_telemetry(result, started_at, metadata)
  end

  def compile(%Screen{} = screen, opts) do
    started_at = System.monotonic_time()
    metadata = compile_metadata(screen, opts)
    Telemetry.emit(:compilation, :compile_start, %{count: 1}, metadata)

    result = do_compile_screen(screen, opts)

    emit_compile_telemetry(result, started_at, metadata)
  end

  @doc """
  Compiles a screen from unified_dsl attribute.

  ## Examples

      {:ok, iur} = AshUI.Compiler.compile_from_unified_dsl(screen)
  """
  @spec compile_from_unified_dsl(Screen.t(), keyword()) :: compile_result()
  def compile_from_unified_dsl(screen, opts \\ [])

  def compile_from_unified_dsl(%Screen{unified_dsl: dsl} = screen, _opts) when is_map(dsl) do
    with {:ok, validated_dsl} <- validate_dsl(dsl),
         {:ok, ash_iur} <- compile_to_ash_iur(screen, validated_dsl),
         :ok <- IUR.validate(ash_iur) do
      {:ok, ash_iur}
    end
  end

  @doc """
  Compiles multiple screens in batch.

  ## Examples

      {:ok, results} = AshUI.Compiler.compile_batch(["screen-1", "screen-2"])
  """
  @spec compile_batch([String.t() | integer()], keyword()) :: {:ok, map()} | {:error, term()}
  def compile_batch(screen_ids, opts \\ []) when is_list(screen_ids) do
    results =
      Enum.reduce(screen_ids, %{}, fn screen_id, acc ->
        case compile(screen_id, opts) do
          {:ok, iur} -> Map.put(acc, screen_id, iur)
          {:error, _reason} -> acc
        end
      end)

    {:ok, results}
  end

  @doc """
  Invalidates compilation cache for a screen.

  ## Examples

      AshUI.Compiler.invalidate_cache("screen-1")
  """
  @spec invalidate_cache(String.t() | integer()) :: :ok
  def invalidate_cache(screen_id) do
    cache_key = build_cache_key_from_id(screen_id)
    delete_from_cache(cache_key)
    :ok
  end

  @doc """
  Clears entire compilation cache.

  ## Examples

      AshUI.Compiler.clear_cache()
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    try do
      :ets.delete_all_objects(:ash_ui_compiler_cache)
    rescue
      ArgumentError -> :ok
    end

    reset_cache_stats()

    :ok
  end

  @doc """
  Gets cache statistics.

  ## Examples

      stats = AshUI.Compiler.cache_stats()
      # => %{size: 10, hits: 100, misses: 5}
  """
  @spec cache_stats() :: map()
  def cache_stats do
    size =
      case :ets.info(:ash_ui_compiler_cache, :size) do
        :undefined -> 0
        info when is_integer(info) -> info
      end

    %{size: size, hits: get_hit_count(), misses: get_miss_count()}
  end

  @doc """
  Initializes the compiler cache.

  Called during application startup.
  """
  @spec init_cache() :: :ok
  def init_cache do
    try do
      :ets.new(
        :ash_ui_compiler_cache,
        [:named_table, :public, read_concurrency: true, write_concurrency: true]
      )
    rescue
      ArgumentError ->
        # Table already exists
        :ok
    end

    :ok
  end

  # Private functions

  defp do_compile_by_id(screen_id, opts) do
    use_cache = Keyword.get(opts, :use_cache, true)

    with {:ok, screen} <- load_screen(screen_id, opts) do
      cache_key = build_cache_key(screen)

      case maybe_get_cached(cache_key, use_cache) do
        {:ok, cached_iur, :cached} ->
          {:ok, cached_iur}

        :cache_miss ->
          compile_and_cache(screen, cache_key, opts)
      end
    end
  end

  defp do_compile_screen(%Screen{} = screen, opts) do
    use_cache = Keyword.get(opts, :use_cache, true)
    load_elements? = Keyword.get(opts, :load_elements, true)
    load_bindings? = Keyword.get(opts, :load_bindings, true)

    cache_key = build_cache_key(screen)

    case maybe_get_cached(cache_key, use_cache) do
      {:ok, cached_iur, :cached} ->
        {:ok, cached_iur}

      :cache_miss ->
        if use_cache do
          compile_and_cache(screen, cache_key, opts)
        else
          compile_screen_uncached(screen, load_elements?, load_bindings?, opts)
        end
    end
  end

  defp compile_screen_uncached(%Screen{} = screen, load_elements?, load_bindings?, opts) do
    if should_compile_from_unified_dsl?(screen) do
      compile_from_unified_dsl(screen, opts)
    else
      compile_from_resources(screen, load_elements?, load_bindings?)
    end
  end

  defp load_screen(screen_id, opts) do
    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    case Ash.get(Screen, screen_id, actor: actor, tenant: tenant) do
      {:ok, screen} -> {:ok, screen}
      {:error, reason} -> {:error, {:screen_not_found, reason}}
    end
  end

  defp compile_from_resources(%Screen{} = screen, load_elements?, load_bindings?) do
    # Build root IUR from screen
    root_iur =
      IUR.new(:screen,
        id: screen.id,
        name: screen.name,
        attributes: %{
          "layout" => screen.layout,
          "route" => screen.route,
          "unified_dsl" => screen.unified_dsl
        },
        metadata: screen.metadata,
        version: "v#{screen.version}"
      )

    # Load and compile children elements
    root_iur =
      if load_elements? do
        case load_elements(screen) do
          {:ok, elements} -> compile_elements(root_iur, elements)
          {:error, _} -> root_iur
        end
      else
        root_iur
      end

    # Load and compile bindings
    root_iur =
      if load_bindings? do
        case load_bindings(screen) do
          {:ok, bindings} -> compile_bindings(root_iur, bindings)
          {:error, _} -> root_iur
        end
      else
        root_iur
      end

    # Validate the compiled IUR
    case IUR.validate(root_iur) do
      :ok -> {:ok, root_iur}
      error -> error
    end
  end

  defp build_cache_key(%Screen{} = screen) do
    version = Map.get(screen, :version, 1)
    "screen:#{screen.id}:v#{version}"
  end

  defp build_cache_key_from_id(screen_id) do
    "screen:#{screen_id}:v1"
  end

  defp maybe_get_cached(cache_key, true) do
    case get_from_cache(cache_key) do
      {:ok, iur} ->
        increment_hit_count()
        {:ok, iur, :cached}

      :miss ->
        increment_miss_count()
        :cache_miss
    end
  end

  defp maybe_get_cached(_cache_key, false), do: :cache_miss

  defp emit_compile_telemetry(result, started_at, metadata) do
    duration = System.monotonic_time() - started_at

    case result do
      {:ok, _compiled} = success ->
        Telemetry.emit(
          :compilation,
          :compile_end,
          %{count: 1, duration: duration},
          Map.put(metadata, :status, :ok)
        )

        success

      {:error, reason} = error ->
        error_metadata = Map.merge(metadata, %{status: :error, error: inspect(reason)})

        Telemetry.emit(
          :compilation,
          :compile_error,
          %{count: 1, duration: duration},
          error_metadata
        )

        error
    end
  end

  defp compile_metadata(%Screen{} = screen, opts) do
    %{
      resource_id: screen.id,
      resource_type: :screen,
      screen_id: screen.id,
      cache: Keyword.get(opts, :use_cache, true)
    }
  end

  defp compile_metadata(screen_id, opts) do
    %{
      resource_id: screen_id,
      resource_type: :screen,
      screen_id: screen_id,
      cache: Keyword.get(opts, :use_cache, true)
    }
  end

  defp get_from_cache(cache_key) do
    try do
      case :ets.lookup(:ash_ui_compiler_cache, cache_key) do
        [{^cache_key, iur, _timestamp}] -> {:ok, iur}
        [] -> :miss
      end
    rescue
      ArgumentError -> :miss
    end
  end

  defp delete_from_cache(cache_key) do
    try do
      :ets.delete(:ash_ui_compiler_cache, cache_key)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  defp compile_and_cache(screen, cache_key, opts) do
    with {:ok, iur} <- compile(screen, Keyword.put(opts, :use_cache, false)),
         :ok <- store_in_cache(cache_key, iur) do
      {:ok, iur}
    end
  end

  defp store_in_cache(cache_key, iur) do
    try do
      :ets.insert(
        :ash_ui_compiler_cache,
        {cache_key, iur, System.system_time(:second)}
      )
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  defp validate_dsl(dsl) do
    normalized_dsl = AshUI.DSL.Builder.from_store(dsl)

    case Storage.validate_write(normalized_dsl) do
      :ok -> {:ok, normalized_dsl}
      {:error, errors} -> {:error, {:invalid_dsl, errors}}
    end
  end

  defp compile_to_ash_iur(%Screen{} = screen, dsl) do
    children = [compile_dsl_node(dsl, screen.id, [0])]
    bindings = compile_dsl_bindings(dsl, screen.id, [0])

    root_iur =
      IUR.new(:screen,
        id: screen.id,
        name: screen.name,
        attributes: %{
          "layout" => screen.layout,
          "route" => screen.route,
          "unified_dsl" => screen.unified_dsl
        },
        children: children,
        bindings: bindings,
        metadata: screen.metadata,
        version: "v#{screen.version || 1}"
      )

    {:ok, root_iur}
  end

  # Load elements associated with a screen
  defp load_elements(%Screen{id: screen_id}) do
    elements =
      Element
      |> Ash.Query.new()
      |> Ash.Query.filter(screen_id == ^screen_id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!(domain: AshUI.Domain)

    {:ok, elements}
  rescue
    error -> {:error, error}
  end

  # Load bindings associated with a screen
  defp load_bindings(%Screen{id: screen_id}) do
    bindings =
      Binding
      |> Ash.Query.new()
      |> Ash.Query.filter(screen_id == ^screen_id)
      |> Ash.read!(domain: AshUI.Domain)

    {:ok, bindings}
  rescue
    error -> {:error, error}
  end

  # Compile elements into IUR children
  defp compile_elements(root_iur, elements) do
    compiled_children =
      Enum.map(elements, fn element ->
        compile_element(element)
      end)

    %{root_iur | children: compiled_children}
  end

  # Compile a single element to IUR
  defp compile_element(%Element{} = element) do
    IUR.new(element.type,
      id: element.id,
      name: element.props["name"] || "element_#{element.id}",
      attributes: Map.put(element.props, "position", element.position),
      metadata: element.metadata,
      version: "v#{element.version || 1}"
    )
  end

  # Compile bindings into IUR bindings
  defp compile_bindings(root_iur, bindings) do
    compiled_bindings =
      Enum.map(bindings, fn binding ->
        compile_binding(binding)
      end)

    %{root_iur | bindings: compiled_bindings}
  end

  # Compile a single binding to IUR format
  defp compile_binding(%Binding{} = binding) do
    %{
      "id" => binding.id,
      "source" => binding.source,
      "target" => binding.target,
      "binding_type" => binding.binding_type,
      "transform" => binding.transform,
      "element_id" => binding.element_id,
      "screen_id" => binding.screen_id,
      "metadata" => binding.metadata
    }
  end

  # Cache statistics helpers

  defp get_hit_count do
    case :ets.whereis(:ash_ui_cache_stats) do
      :undefined ->
        0

      _ ->
        case :ets.lookup(:ash_ui_cache_stats, :hits) do
          [{:hits, count}] -> count
          [{:hits, count, _}] -> count
          [] -> 0
        end
    end
  end

  defp get_miss_count do
    case :ets.whereis(:ash_ui_cache_stats) do
      :undefined ->
        0

      _ ->
        case :ets.lookup(:ash_ui_cache_stats, :misses) do
          [{:misses, count}] -> count
          [{:misses, count, _}] -> count
          [] -> 0
        end
    end
  end

  defp increment_hit_count do
    ensure_stats_table()
    :ets.update_counter(:ash_ui_cache_stats, :hits, {2, 1}, {1, 0, 1})
  end

  defp increment_miss_count do
    ensure_stats_table()
    :ets.update_counter(:ash_ui_cache_stats, :misses, {2, 1}, {1, 0, 1})
  end

  defp reset_cache_stats do
    case :ets.whereis(:ash_ui_cache_stats) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(:ash_ui_cache_stats)
    end
  end

  defp ensure_stats_table do
    try do
      :ets.new(:ash_ui_cache_stats, [:named_table, :public])
    rescue
      ArgumentError -> :ok
    end
  end

  defp should_compile_from_unified_dsl?(%Screen{unified_dsl: dsl}) when is_map(dsl) do
    dsl
    |> AshUI.DSL.Builder.from_store()
    |> Map.get(:type)
    |> case do
      nil -> false
      "screen" -> false
      _ -> true
    end
  end

  defp should_compile_from_unified_dsl?(_screen), do: false

  defp compile_dsl_node(dsl, screen_id, path) do
    children =
      dsl
      |> Map.get(:children, [])
      |> Enum.with_index()
      |> Enum.map(fn {child, index} ->
        compile_dsl_node(child, screen_id, path ++ [index])
      end)

    type = widget_type_to_iur_type(Map.get(dsl, :type))
    props = Map.get(dsl, :props, %{})

    IUR.new(type,
      id: dsl_node_id(screen_id, path),
      name: props[:name] || props["name"] || "#{Map.get(dsl, :type)}_#{Enum.join(path, "_")}",
      attributes: props,
      props: props,
      children: children,
      metadata: Map.get(dsl, :metadata, %{})
    )
  end

  defp compile_dsl_bindings(dsl, screen_id, path) do
    element_id = dsl_node_id(screen_id, path)

    local_bindings =
      dsl
      |> Map.get(:signals, [])
      |> Enum.with_index()
      |> Enum.map(fn {signal, index} ->
        compile_signal_binding(signal, screen_id, element_id, index)
      end)

    child_bindings =
      dsl
      |> Map.get(:children, [])
      |> Enum.with_index()
      |> Enum.flat_map(fn {child, index} ->
        compile_dsl_bindings(child, screen_id, path ++ [index])
      end)

    local_bindings ++ child_bindings
  end

  defp compile_signal_binding(signal, screen_id, element_id, index) do
    %{
      "id" => "#{element_id}:signal:#{index}",
      "source" => signal_source(signal),
      "target" => Map.get(signal, :target),
      "binding_type" => signal_type_to_binding_type(Map.get(signal, :type)),
      "transform" => Map.get(signal, :transform, %{}),
      "element_id" => element_id,
      "screen_id" => screen_id,
      "metadata" => %{}
    }
  end

  defp signal_source(%{source: %{} = source}), do: source

  defp signal_source(%{source: source}) when is_binary(source) do
    case String.split(source, ".", parts: 2) do
      [resource, field] -> %{"resource" => resource, "field" => field}
      _ -> %{"value" => source}
    end
  end

  defp signal_source(%{action: action}) when is_binary(action), do: %{"action" => action}
  defp signal_source(_signal), do: %{}

  defp signal_type_to_binding_type(:event), do: :event
  defp signal_type_to_binding_type(:bidirectional), do: :bidirectional
  defp signal_type_to_binding_type(:collection), do: :collection
  defp signal_type_to_binding_type(type), do: type || :value

  defp dsl_node_id(screen_id, path) do
    path_suffix = Enum.join(path, "-")
    "#{screen_id}:dsl:#{path_suffix}"
  end

  defp widget_type_to_iur_type("row"), do: :row
  defp widget_type_to_iur_type("column"), do: :column
  defp widget_type_to_iur_type("grid"), do: :grid
  defp widget_type_to_iur_type("stack"), do: :stack
  defp widget_type_to_iur_type("fragment"), do: :fragment
  defp widget_type_to_iur_type("container"), do: :container
  defp widget_type_to_iur_type("text"), do: :text
  defp widget_type_to_iur_type("button"), do: :button
  defp widget_type_to_iur_type("input"), do: :textinput
  defp widget_type_to_iur_type("checkbox"), do: :checkbox
  defp widget_type_to_iur_type("select"), do: :select
  defp widget_type_to_iur_type("image"), do: :image
  defp widget_type_to_iur_type("spacer"), do: :spacer

  defp widget_type_to_iur_type(type) when is_binary(type) do
    if String.starts_with?(type, "custom:"), do: :custom, else: :fragment
  end

  defp widget_type_to_iur_type(_type), do: :fragment
end
