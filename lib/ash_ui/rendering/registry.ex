defmodule AshUI.Rendering.Registry do
  @moduledoc """
  Registry for tracking and managing available renderer packages.

  This module provides functionality to:
  - Detect available renderer packages (live_ui, web_ui, desktop_ui)
  - Register renderers at application startup
  - Query available renderers
  - Get renderer modules by type
  """

  use GenServer

  @doc """
  Starts the renderer registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Lists all available renderers.

  ## Returns
    * `[%{type: atom(), module: module(), available: boolean()}]` - List of renderers
  """
  @spec list_renderers() :: [map()]
  def list_renderers do
    GenServer.call(__MODULE__, :list_renderers)
  end

  @doc """
  Gets the renderer module for a given renderer type.

  ## Parameters
    * `type` - Renderer type: `:liveview`, `:html`, or `:desktop`

  ## Returns
    * `{:ok, module()}` - Renderer module found
    * `{:error, :not_available}` - Renderer not available
    * `{:error, :not_found}` - Renderer type not found
  """
  @spec get_renderer(atom()) :: {:ok, module()} | {:error, atom()}
  def get_renderer(:liveview) do
    GenServer.call(__MODULE__, {:get_renderer, :liveview})
  end

  def get_renderer(:html) do
    GenServer.call(__MODULE__, {:get_renderer, :html})
  end

  def get_renderer(:desktop) do
    GenServer.call(__MODULE__, {:get_renderer, :desktop})
  end

  def get_renderer(_other) do
    {:error, :not_found}
  end

  @doc """
  Checks if a renderer type is available.

  ## Parameters
    * `type` - Renderer type: `:liveview`, `:html`, or `:desktop`

  ## Returns
    * `true` - Renderer is available
    * `false` - Renderer is not available
  """
  @spec renderer_available?(atom()) :: boolean()
  def renderer_available?(:liveview) do
    case get_renderer(:liveview) do
      {:ok, _module} -> true
      _ -> false
    end
  end

  def renderer_available?(:html) do
    case get_renderer(:html) do
      {:ok, _module} -> true
      _ -> false
    end
  end

  def renderer_available?(:desktop) do
    case get_renderer(:desktop) do
      {:ok, _module} -> true
      _ -> false
    end
  end

  def renderer_available?(_other), do: false

  @doc """
  Refreshes the renderer registry by checking availability again.

  ## Returns
    * `:ok` - Registry refreshed
  """
  @spec refresh() :: :ok
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  @doc """
  Gets the default renderer for the current environment.

  ## Returns
    * `{:ok, type, module()}` - Default renderer type and module
    * `{:error, :no_renderer}` - No renderer available
  """
  @spec default_renderer() :: {:ok, atom(), module()} | {:error, atom()}
  def default_renderer do
    configured = Application.get_env(:ash_ui, :rendering, [])
    default = Keyword.get(configured, :default_renderer, :liveview)

    case get_renderer(default) do
      {:ok, module} -> {:ok, default, module}
      {:error, :not_available} -> find_fallback_renderer()
      error -> error
    end
  end

  # Server Callbacks

  @impl true
  @doc """
  GenServer callback to initialize the renderer registry.

  Detects all available renderer packages and stores their information.
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
  GenServer callback for synchronous requests.

  Supports:
  - `:list_renderers` - Returns list of all registered renderers
  - `{:get_renderer, type}` - Returns renderer module for given type
  - `{:renderer_available?, type}` - Checks if renderer is available
  - `:default_renderer` - Returns the default renderer
  """
  def handle_call(:list_renderers, _from, state) do
    renderers =
      state.renderers
      |> Enum.map(fn {type, info} ->
        %{
          type: type,
          module: info.module,
          available: info.available,
          description: info.description
        }
      end)

    {:reply, renderers, state}
  end

  @impl true
  def handle_call({:get_renderer, type}, _from, state) do
    case Map.get(state.renderers, type) do
      %{module: module} ->
        # Always return the module - it will be either the external renderer
        # or the AshUI adapter with fallback implementation
        {:reply, {:ok, module}, state}

      nil ->
        {:reply, {:error, :not_found}, state}
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

  # Private Functions

  # Detect available renderer packages
  defp detect_renderers do
    %{
      liveview: detect_live_ui(),
      html: detect_web_ui(),
      desktop: detect_desktop_ui()
    }
  end

  # Detect LiveUI renderer
  defp detect_live_ui do
    %{
      module: try_live_ui_module(),
      available: Code.ensure_loaded?(LiveUI.Renderer),
      description: "Phoenix LiveView renderer (live_ui)"
    }
  end

  # Detect WebUI renderer
  defp detect_web_ui do
    %{
      module: try_web_ui_module(),
      available: Code.ensure_loaded?(WebUI.Renderer),
      description: "Static HTML renderer (web_ui)"
    }
  end

  # Detect DesktopUI renderer
  defp detect_desktop_ui do
    %{
      module: try_desktop_ui_module(),
      available: Code.ensure_loaded?(DesktopUI.Renderer),
      description: "Native desktop renderer (desktop_ui)"
    }
  end

  # Try to get LiveUI module, return placeholder if not available
  defp try_live_ui_module do
    if Code.ensure_loaded?(LiveUI.Renderer) do
      LiveUI.Renderer
    else
      AshUI.Rendering.LiveUIAdapter
    end
  end

  # Try to get WebUI module, return placeholder if not available
  defp try_web_ui_module do
    if Code.ensure_loaded?(WebUI.Renderer) do
      WebUI.Renderer
    else
      AshUI.Rendering.WebUIAdapter
    end
  end

  # Try to get DesktopUI module, return placeholder if not available
  defp try_desktop_ui_module do
    if Code.ensure_loaded?(DesktopUI.Renderer) do
      DesktopUI.Renderer
    else
      AshUI.Rendering.DesktopUIAdapter
    end
  end

  # Find fallback renderer when default is unavailable
  defp find_fallback_renderer do
    configured = Application.get_env(:ash_ui, :rendering, [])
    fallback = Keyword.get(configured, :fallback_renderer)

    if fallback do
      case get_renderer(fallback) do
        {:ok, module} -> {:ok, fallback, module}
        error -> error
      end
    else
      # Try to find any available renderer
      cond do
        renderer_available?(:liveview) ->
          {:ok, :liveview, elem(get_renderer(:liveview), 1)}

        renderer_available?(:html) ->
          {:ok, :html, elem(get_renderer(:html), 1)}

        renderer_available?(:desktop) ->
          {:ok, :desktop, elem(get_renderer(:desktop), 1)}

        true ->
          {:error, :no_renderer}
      end
    end
  end
end
