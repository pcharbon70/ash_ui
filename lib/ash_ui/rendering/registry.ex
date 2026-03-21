defmodule AshUI.Rendering.Registry do
  @moduledoc """
  Registry for tracking renderer package availability and adapter fallback state.

  The registry keeps two truths separate:
  - whether the external renderer package is installed
  - whether Ash UI can still render via its in-repo adapter fallback
  """

  use GenServer

  @renderer_types [:liveview, :html, :desktop]

  @doc """
  Starts the renderer registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Lists all known renderers with their availability and fallback mode.
  """
  @spec list_renderers(keyword()) :: [map()]
  def list_renderers(opts \\ []) do
    GenServer.call(__MODULE__, {:list_renderers, opts})
  end

  @doc """
  Returns renderer status information for a given type.

  The returned map always reflects:
  - `:available` - whether the external package is present
  - `:renderable` - whether Ash UI can render with the current fallback policy
  - `:mode` - `:external`, `:adapter_fallback`, or `:unavailable`
  """
  @spec renderer_info(atom(), keyword()) :: {:ok, map()} | {:error, atom()}
  def renderer_info(type, opts \\ [])

  def renderer_info(type, opts) when type in @renderer_types do
    GenServer.call(__MODULE__, {:renderer_info, type, opts})
  end

  def renderer_info(_other, _opts), do: {:error, :not_found}

  @doc """
  Resolves the renderer to use for a given type.

  ## Options
    * `:allow_adapter_fallback` - allow in-repo adapter fallback when the
      external package is not installed. Defaults to config.
  """
  @spec resolve_renderer(atom(), keyword()) :: {:ok, map()} | {:error, atom()}
  def resolve_renderer(type, opts \\ [])

  def resolve_renderer(type, opts) when type in @renderer_types do
    GenServer.call(__MODULE__, {:resolve_renderer, type, opts})
  end

  def resolve_renderer(_other, _opts), do: {:error, :not_found}

  @doc """
  Gets the renderer module for a given renderer type.
  """
  @spec get_renderer(atom()) :: {:ok, module()} | {:error, atom()}
  def get_renderer(type) do
    get_renderer(type, [])
  end

  @doc """
  Gets the renderer module for a given type using the provided fallback policy.
  """
  @spec get_renderer(atom(), keyword()) :: {:ok, module()} | {:error, atom()}
  def get_renderer(type, opts) do
    case resolve_renderer(type, opts) do
      {:ok, info} -> {:ok, info.module}
      error -> error
    end
  end

  @doc """
  Checks whether the external renderer package is installed.
  """
  @spec renderer_available?(atom()) :: boolean()
  def renderer_available?(type) do
    case renderer_info(type) do
      {:ok, info} -> info.available
      _ -> false
    end
  end

  @doc """
  Checks whether Ash UI can render with the given renderer type.
  """
  @spec renderer_renderable?(atom(), keyword()) :: boolean()
  def renderer_renderable?(type, opts \\ []) do
    case resolve_renderer(type, opts) do
      {:ok, _info} -> true
      _ -> false
    end
  end

  @doc """
  Refreshes the renderer registry by checking availability again.
  """
  @spec refresh() :: :ok
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  @doc """
  Gets the default renderer for the current environment.
  """
  @spec default_renderer(keyword()) :: {:ok, atom(), module()} | {:error, atom()}
  def default_renderer(opts \\ []) do
    configured = rendering_config()

    default =
      Keyword.get(opts, :default_renderer, Keyword.get(configured, :default_renderer, :liveview))

    case resolve_renderer(default, opts) do
      {:ok, info} ->
        {:ok, default, info.module}

      {:error, :not_available} ->
        find_fallback_renderer(Keyword.put(opts, :exclude, default))

      error ->
        error
    end
  end

  @impl true
  @doc """
  Initializes the registry state with the current renderer availability snapshot.
  """
  def init(_opts) do
    state = %{
      renderers: detect_renderers(),
      initialized_at: System.system_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  @doc """
  Handles registry reads and refresh requests.
  """
  def handle_call({:list_renderers, opts}, _from, state) do
    renderers =
      state.renderers
      |> Enum.map(fn {type, info} -> public_renderer_info(type, info, opts) end)

    {:reply, renderers, state}
  end

  @impl true
  def handle_call({:renderer_info, type, opts}, _from, state) do
    case Map.get(state.renderers, type) do
      nil ->
        {:reply, {:error, :not_found}, state}

      info ->
        {:reply, {:ok, public_renderer_info(type, info, opts)}, state}
    end
  end

  @impl true
  def handle_call({:resolve_renderer, type, opts}, _from, state) do
    case Map.get(state.renderers, type) do
      nil ->
        {:reply, {:error, :not_found}, state}

      info ->
        renderer_info = public_renderer_info(type, info, opts)

        if renderer_info.renderable do
          {:reply, {:ok, renderer_info}, state}
        else
          {:reply, {:error, :not_available}, state}
        end
    end
  end

  @impl true
  def handle_call(:refresh, _from, _state) do
    new_state = %{
      renderers: detect_renderers(),
      initialized_at: System.system_time(:millisecond)
    }

    {:reply, :ok, new_state}
  end

  defp detect_renderers do
    %{
      liveview:
        detect_renderer(
          LiveUI.Renderer,
          AshUI.Rendering.LiveUIAdapter,
          "Phoenix LiveView renderer (live_ui)"
        ),
      html:
        detect_renderer(
          WebUI.Renderer,
          AshUI.Rendering.WebUIAdapter,
          "Static HTML renderer (web_ui)"
        ),
      desktop:
        detect_renderer(
          DesktopUI.Renderer,
          AshUI.Rendering.DesktopUIAdapter,
          "Native desktop renderer (desktop_ui)"
        )
    }
  end

  defp detect_renderer(external_module, adapter_module, description) do
    %{
      external_module: external_module,
      adapter_module: adapter_module,
      external_available: Code.ensure_loaded?(external_module),
      adapter_available: Code.ensure_loaded?(adapter_module),
      description: description
    }
  end

  defp public_renderer_info(type, info, opts) do
    allow_adapter_fallback = adapter_fallback_enabled?(opts)

    {module, mode, renderable} =
      cond do
        info.external_available ->
          {info.external_module, :external, true}

        allow_adapter_fallback and info.adapter_available ->
          {info.adapter_module, :adapter_fallback, true}

        true ->
          {nil, :unavailable, false}
      end

    %{
      type: type,
      module: module,
      external_module: info.external_module,
      adapter_module: info.adapter_module,
      available: info.external_available,
      renderable: renderable,
      mode: mode,
      description: info.description
    }
  end

  defp find_fallback_renderer(opts) do
    configured = rendering_config()

    requested_fallback =
      Keyword.get(opts, :fallback_renderer, Keyword.get(configured, :fallback_renderer))

    exclude = excluded_types(opts)

    with {:ok, fallback} <- validate_requested_fallback(requested_fallback, exclude),
         {:ok, info} <- resolve_renderer(fallback, fallback_opts(opts)) do
      {:ok, fallback, info.module}
    else
      {:error, :skip_requested_fallback} ->
        find_first_renderable(exclude, fallback_opts(opts))

      {:error, :not_available} ->
        find_first_renderable(exclude, fallback_opts(opts))

      {:error, :no_requested_fallback} ->
        find_first_renderable(exclude, fallback_opts(opts))

      error ->
        error
    end
  end

  defp find_first_renderable(exclude, opts) do
    @renderer_types
    |> Enum.reject(&(&1 in exclude))
    |> Enum.find_value({:error, :no_renderer}, fn type ->
      case resolve_renderer(type, opts) do
        {:ok, info} -> {:ok, type, info.module}
        _ -> false
      end
    end)
  end

  defp validate_requested_fallback(nil, _exclude), do: {:error, :no_requested_fallback}

  defp validate_requested_fallback(fallback, exclude) when fallback in @renderer_types do
    if fallback in exclude do
      {:error, :skip_requested_fallback}
    else
      {:ok, fallback}
    end
  end

  defp validate_requested_fallback(_fallback, _exclude), do: {:error, :not_found}

  defp excluded_types(opts) do
    opts
    |> Keyword.get(:exclude, [])
    |> List.wrap()
  end

  defp fallback_opts(opts) do
    allow_adapter_fallback =
      Keyword.get(
        opts,
        :fallback_allow_adapter_fallback,
        Keyword.get(opts, :allow_adapter_fallback, adapter_fallback_enabled?([]))
      )

    Keyword.put(opts, :allow_adapter_fallback, allow_adapter_fallback)
  end

  defp adapter_fallback_enabled?(opts) do
    configured = rendering_config()

    Keyword.get(
      opts,
      :allow_adapter_fallback,
      Keyword.get(configured, :allow_adapter_fallback, true)
    )
  end

  defp rendering_config do
    Application.get_env(:ash_ui, :rendering, [])
  end
end
