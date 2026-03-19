defmodule AshUI.Compiler do
  @moduledoc """
  Compiler that converts Ash Resources to IUR structures.

  This module handles the compilation of Ash UI resources (Screen, Element, Binding)
  into the internal IUR (Intermediate UI Representation) format.

  Phase 6 adds unified-ui compiler integration with caching.
  """

  require Logger

  alias AshUI.Compilation.IUR
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding
  alias AshUI.DSL.Storage
  alias AshUI.Rendering.IURAdapter

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
    use_cache = Keyword.get(opts, :use_cache, true)

    with {:ok, screen} <- load_screen(screen_id, opts),
         {:ok, cache_key} <- build_cache_key(screen),
         {:ok, cached_iur} <- maybe_get_cached(cache_key, use_cache) do
      {:ok, cached_iur}
    else
      :cache_miss ->
        compile_and_cache(screen, cache_key, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def compile(%Screen{} = screen, opts) do
    load_elements? = Keyword.get(opts, :load_elements, true)
    load_bindings? = Keyword.get(opts, :load_bindings, true)

    # If unified_dsl is present, use unified-ui compilation path
    if Map.has_key?(screen, :unified_dsl) and map_size(screen.unified_dsl || %{}) > 0 do
      compile_from_unified_dsl(screen, opts)
    else
      compile_from_resources(screen, load_elements?, load_bindings?)
    end
  end

  @doc """
  Compiles a screen from unified_dsl attribute.

  ## Examples

      {:ok, iur} = AshUI.Compiler.compile_from_unified_dsl(screen)
  """
  @spec compile_from_unified_dsl(Screen.t(), keyword()) :: compile_result()
  def compile_from_unified_dsl(%Screen{unified_dsl: dsl} = screen, opts) when is_map(dsl) do
    with {:ok, validated_dsl} <- validate_dsl(dsl),
         {:ok, ash_iur} <- compile_to_ash_iur(validated_dsl),
         {:ok, canonical_iur} <- convert_to_canonical(ash_iur, screen),
         :ok <- IUR.validate(canonical_iur) do
      {:ok, canonical_iur}
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
    try do
      info = :ets.table_info(:ash_ui_compiler_cache, :size)
      %{size: info, hits: get_hit_count(), misses: get_miss_count()}
    rescue
      ArgumentError -> %{size: 0, hits: 0, misses: 0}
    end
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
    case Storage.validate_write(dsl) do
      :ok -> {:ok, AshUI.DSL.Builder.from_store(dsl)}
      {:error, errors} -> {:error, {:invalid_dsl, errors}}
    end
  end

  defp compile_to_ash_iur(dsl) do
    # In production, would call unified-ui compiler
    # For now, create a simple Ash IUR structure
    iur = %{
      type: dsl.type,
      props: dsl.props,
      children: Enum.map(dsl.children || [], &compile_to_ash_iur/1),
      signals: dsl.signals || [],
      metadata: dsl.metadata || %{}
    }

    {:ok, iur}
  end

  defp convert_to_canonical(ash_iur, screen) do
    # Merge screen metadata with compiled IUR
    base_iur = Map.put(ash_iur, :screen_id, screen.id)
    base_iur = Map.put(base_iur, :screen_name, screen.name)

    IURAdapter.to_canonical(base_iur)
  end

  # Load elements associated with a screen
  defp load_elements(%Screen{id: screen_id}) do
    elements =
      AshUI.Domain.read!(Element,
        filter: [screen_id: screen_id],
        sort: [position: :asc]
      )

    {:ok, elements}
  rescue
    error -> {:error, error}
  end

  # Load bindings associated with a screen
  defp load_bindings(%Screen{id: screen_id}) do
    bindings =
      AshUI.Domain.read!(Binding,
        filter: [screen_id: screen_id]
      )

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
      :undefined -> 0
      _ ->
        case :ets.lookup(:ash_ui_cache_stats, :hits) do
          [{:hits, count}] -> count
          [] -> 0
        end
    end
  end

  defp get_miss_count do
    case :ets.whereis(:ash_ui_cache_stats) do
      :undefined -> 0
      _ ->
        case :ets.lookup(:ash_ui_cache_stats, :misses) do
          [{:misses, count}] -> count
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

  defp ensure_stats_table do
    try do
      :ets.new(:ash_ui_cache_stats, [:named_table, :public])
    rescue
      ArgumentError -> :ok
    end
  end
end
