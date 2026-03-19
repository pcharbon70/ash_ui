defmodule AshUI.Rendering.Selector do
  @moduledoc """
  Runtime renderer selection based on request context and configuration.

  This module provides automatic renderer selection based on:
  - Request type (LiveView request → live_ui, HTTP request → web_ui)
  - Explicit renderer override
  - Fallback configuration
  - Per-environment configuration

  ## Examples

      # Auto-select renderer based on request
      {:ok, renderer} = Selector.select_for_request(conn)

      # Override renderer explicitly
      {:ok, renderer} = Selector.select_for_request(conn, renderer: :html)

      # Select with fallback
      {:ok, renderer, from_cache} = Selector.select_with_fallback(conn)
  """

  alias AshUI.Rendering.Registry

  @doc """
  Selects appropriate renderer based on request context.

  ## Parameters
    * `conn` - Phoenix connection or request context
    * `opts` - Options

  ## Options
    * `:renderer` - Explicit renderer override (:liveview, :html, :desktop)
    * `:ignore_headers` - Ignore X-Renderer header (default: false)

  ## Returns
    * `{:ok, renderer_type, module}` - Selected renderer and module
    * `{:error, reason}` - Selection failed
  """
  @spec select_for_request(Plug.Conn.t() | map(), keyword()) ::
    {:ok, atom(), module()} | {:error, term()}
  def select_for_request(conn_or_map, opts \\ []) do
    cond do
      # Explicit renderer override takes precedence
      Keyword.has_key?(opts, :renderer) ->
        renderer = Keyword.get(opts, :renderer)
        get_renderer_with_validation(renderer)

      # Check for X-Renderer header (if not ignored)
      not Keyword.get(opts, :ignore_headers, false) ->
        case get_renderer_from_header(conn_or_map) do
          {:ok, renderer} -> get_renderer_with_validation(renderer)
          _error -> select_from_context(conn_or_map, opts)
        end

      # Auto-detect from context
      true ->
        select_from_context(conn_or_map, opts)
    end
  end

  @doc """
  Selects renderer with fallback support.

  ## Parameters
    * `conn` - Phoenix connection or request context
    * `opts` - Options

  ## Returns
    * `{:ok, renderer_type, module, from_cache}` - Renderer and cache status
    * `{:error, reason}` - All renderers unavailable
  """
  @spec select_with_fallback(Plug.Conn.t() | map(), keyword()) ::
    {:ok, atom(), module(), boolean()} | {:error, term()}
  def select_with_fallback(conn_or_map, opts \\ []) do
    case select_for_request(conn_or_map, opts) do
      {:ok, renderer_type, module} ->
        {:ok, renderer_type, module, false}

      {:error, _reason} ->
        # Try fallback renderer
        case get_fallback_renderer() do
          {:ok, renderer_type, module} ->
            {:ok, renderer_type, module, true}

          error ->
            error
        end
    end
  end

  @doc """
  Detects if request is a LiveView request.

  ## Parameters
    * `conn_or_map` - Phoenix connection or request context

  ## Returns
    * `true` - Request is LiveView
    * `false` - Request is not LiveView
  """
  @spec liveview_request?(Plug.Conn.t() | map()) :: boolean()
  def liveview_request?(conn_or_map) do
    # Check for LiveView indicators
    has_live_header = has_header?(conn_or_map, "accepts", ["text/vnd.phoenix.live-view"])
    has_live_param = has_param?(conn_or_map, "_format", ["live", "liveview"])
    has_live_session = has_session_key?(conn_or_map, "__phoenix_flash__")

    has_live_header or has_live_param or has_live_session
  end

  @doc """
  Detects if request is a standard HTTP request.

  ## Parameters
    * `conn_or_map` - Phoenix connection or request context

  ## Returns
    * `true` - Request is standard HTTP
    * `false` - Request is not standard HTTP
  """
  @spec http_request?(Plug.Conn.t() | map()) :: boolean()
  def http_request?(conn_or_map) do
    # If it's not explicitly LiveView and has HTML accept, treat as HTTP
    not liveview_request?(conn_or_map) and
      has_header?(conn_or_map, "accept", ["text/html", "application/xhtml+xml"])
  end

  @doc """
  Gets the fallback renderer from configuration.

  ## Returns
    * `{:ok, renderer_type, module}` - Fallback renderer
    * `{:error, :no_fallback}` - No fallback configured
  """
  @spec get_fallback_renderer() :: {:ok, atom(), module()} | {:error, atom()}
  def get_fallback_renderer do
    configured = Application.get_env(:ash_ui, :rendering, [])
    fallback = Keyword.get(configured, :fallback_renderer)

    if fallback do
      get_renderer_with_validation(fallback)
    else
      # Auto-select fallback
      cond do
        Registry.renderer_available?(:html) ->
          get_renderer_with_validation(:html)

        Registry.renderer_available?(:liveview) ->
          get_renderer_with_validation(:liveview)

        Registry.renderer_available?(:desktop) ->
          get_renderer_with_validation(:desktop)

        true ->
          {:error, :no_fallback}
      end
    end
  end

  # Private Functions

  defp select_from_context(conn_or_map, opts) do
    cond do
      liveview_request?(conn_or_map) ->
        get_renderer_with_validation(:liveview)

      http_request?(conn_or_map) ->
        get_renderer_with_validation(:html)

      # Default to configured default renderer
      true ->
        configured = Application.get_env(:ash_ui, :rendering, [])
        default = Keyword.get(configured, :default_renderer, :liveview)
        get_renderer_with_validation(default)
    end
  end

  defp get_renderer_from_header(conn_or_map) do
    case get_request_header(conn_or_map, "x-renderer") do
      nil -> {:error, :no_header}
      "liveview" -> {:ok, :liveview}
      "live" -> {:ok, :liveview}
      "html" -> {:ok, :html}
      "web" -> {:ok, :html}
      "desktop" -> {:ok, :desktop}
      "native" -> {:ok, :desktop}
      unknown -> {:error, {:unknown_renderer, unknown}}
    end
  end

  defp get_renderer_with_validation(renderer_type) do
    case Registry.get_renderer(renderer_type) do
      {:ok, module} ->
        {:ok, renderer_type, module}

      {:error, :not_available} ->
        {:error, {:renderer_not_available, renderer_type}}

      {:error, :not_found} ->
        {:error, {:renderer_not_found, renderer_type}}
    end
  end

  defp has_header?(conn_or_map, header_name, values \\ []) do
    header_value = get_request_header(conn_or_map, header_name)

    if is_binary(header_value) do
      if length(values) > 0 do
        Enum.any?(values, fn value ->
          String.contains?(String.downcase(header_value), value)
        end)
      else
        true
      end
    else
      false
    end
  end

  defp has_param?(conn_or_map, param_name, values \\ []) do
    param_value = get_request_param(conn_or_map, param_name)

    if param_value do
      if length(values) > 0 do
        param_value in values
      else
        true
      end
    else
      false
    end
  end

  defp has_session_key?(conn_or_map, key) do
    session = get_request_session(conn_or_map)
    is_map(session) and Map.has_key?(session, key)
  end

  # Generic request header extraction
  defp get_request_header(%Plug.Conn{} = conn, header_name) do
    # Try to get from various locations in Plug.Conn
    conn
    |> Plug.Conn.get_req_header(header_name)
    |> case do
      "" -> nil
      val -> val
    end
  end

  defp get_request_header(map, header_name) when is_map(map) do
    # Try to get from request headers map
    headers = Map.get(map, :headers) || Map.get(map, "headers") || %{}

    # Try both string and atom keys
    Map.get(headers, header_name) ||
      try do
        Map.get(headers, String.to_atom(header_name))
      rescue
        _ -> nil
      end ||
      Map.get(headers, "http-#{String.downcase(header_name)}")
  end

  # Generic request param extraction
  defp get_request_param(%Plug.Conn{} = conn, param_name) do
    params = conn.params || %{}
    Map.get(params, param_name)
  end

  defp get_request_param(map, param_name) when is_map(map) do
    params = Map.get(map, :params) || Map.get(map, "params") || %{}
    Map.get(params, param_name)
  end

  # Generic session extraction
  defp get_request_session(%Plug.Conn{} = conn) do
    Map.get(conn.assigns, :session) || %{}
  end

  defp get_request_session(map) when is_map(map) do
    Map.get(map, :session) || Map.get(map, "session") || %{}
  end

  @doc """
  Gets renderer for specific environment.

  ## Parameters
    * `env` - Environment atom (:dev, :test, :prod)

  ## Returns
    * `{:ok, renderer_type, module}` - Environment-specific renderer
    * `{:error, reason}` - Selection failed
  """
  @spec select_for_environment(atom()) :: {:ok, atom(), module()} | {:error, term()}
  def select_for_environment(env) when env in [:dev, :test, :prod] do
    configured = Application.get_env(:ash_ui, :rendering, [])
    env_renderers = Keyword.get(configured, :env_renderers, %{})

    case Map.get(env_renderers, env) do
      nil ->
        # Fall back to default renderer
        default = Keyword.get(configured, :default_renderer, :liveview)
        get_renderer_with_validation(default)

      renderer_type ->
        get_renderer_with_validation(renderer_type)
    end
  end

  def select_for_environment(_env) do
    {:error, :invalid_environment}
  end
end
