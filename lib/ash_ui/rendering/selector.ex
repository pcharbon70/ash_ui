defmodule AshUI.Rendering.Selector do
  @moduledoc """
  Runtime renderer selection based on request context and configuration.

  This selector understands the difference between:
  - a real external renderer package being installed
  - Ash UI using its in-repo adapter fallback for that renderer type
  """

  require Logger

  alias AshUI.Rendering.Registry
  alias AshUI.Telemetry

  @renderer_types [:liveview, :html, :desktop]

  @doc """
  Selects an appropriate renderer based on request context.

  ## Options
    * `:renderer` - explicit renderer override
    * `:ignore_headers` - ignore `x-renderer`
    * `:allow_adapter_fallback` - allow adapter fallback for the selected type
  """
  @spec select_for_request(Plug.Conn.t() | map(), keyword()) ::
          {:ok, atom(), module()} | {:error, term()}
  def select_for_request(conn_or_map, opts \\ []) do
    with {:ok, renderer_type} <- select_renderer_type(conn_or_map, opts) do
      get_renderer_with_validation(renderer_type, opts)
    end
  end

  @doc """
  Selects a renderer with fallback support.

  The fourth tuple value indicates whether a fallback path was used. That is
  true when either:
  - an adapter fallback handled the selected renderer type
  - selection switched to a different fallback renderer type
  """
  @spec select_with_fallback(Plug.Conn.t() | map(), keyword()) ::
          {:ok, atom(), module(), boolean()} | {:error, term()}
  def select_with_fallback(conn_or_map, opts \\ []) do
    with {:ok, requested_type} <- select_renderer_type(conn_or_map, opts) do
      case Registry.resolve_renderer(requested_type, opts) do
        {:ok, info} ->
          fallback_used = info.mode == :adapter_fallback

          maybe_record_fallback(
            requested_type,
            requested_type,
            info,
            :adapter_fallback,
            fallback_used
          )

          {:ok, requested_type, info.module, fallback_used}

        {:error, :not_available} ->
          case resolve_fallback_renderer(Keyword.put(opts, :exclude, requested_type)) do
            {:ok, fallback_type, fallback_info} ->
              record_fallback(requested_type, fallback_type, fallback_info, :alternative_renderer)
              {:ok, fallback_type, fallback_info.module, true}

            {:error, :no_fallback} ->
              {:error, {:renderer_not_available, requested_type}}

            error ->
              error
          end

        {:error, :not_found} ->
          {:error, {:renderer_not_found, requested_type}}
      end
    else
      {:error, {:unknown_renderer, _unknown} = reason} ->
        context_opts = Keyword.put(opts, :ignore_headers, true)

        case select_for_request(conn_or_map, context_opts) do
          {:ok, fallback_type, module} ->
            {:ok, fallback_info} = Registry.renderer_info(fallback_type, context_opts)
            record_fallback(:unknown, fallback_type, fallback_info, reason)
            {:ok, fallback_type, module, true}

          {:error, _context_reason} ->
            case resolve_fallback_renderer(opts) do
              {:ok, fallback_type, fallback_info} ->
                record_fallback(:unknown, fallback_type, fallback_info, reason)
                {:ok, fallback_type, fallback_info.module, true}

              _ ->
                {:error, reason}
            end
        end

      error ->
        error
    end
  end

  @doc """
  Detects if a request is a LiveView request.
  """
  @spec liveview_request?(Plug.Conn.t() | map()) :: boolean()
  def liveview_request?(conn_or_map) do
    has_live_header = has_header?(conn_or_map, "accepts", ["text/vnd.phoenix.live-view"])
    has_live_param = has_param?(conn_or_map, "_format", ["live", "liveview"])
    has_live_session = has_session_key?(conn_or_map, "__phoenix_flash__")

    has_live_header or has_live_param or has_live_session
  end

  @doc """
  Detects if a request is a standard HTTP request.
  """
  @spec http_request?(Plug.Conn.t() | map()) :: boolean()
  def http_request?(conn_or_map) do
    not liveview_request?(conn_or_map) and
      has_header?(conn_or_map, "accept", ["text/html", "application/xhtml+xml"])
  end

  @doc """
  Gets the fallback renderer from options or configuration.
  """
  @spec get_fallback_renderer(keyword()) :: {:ok, atom(), module()} | {:error, atom()}
  def get_fallback_renderer(opts \\ []) do
    case resolve_fallback_renderer(opts) do
      {:ok, renderer_type, info} -> {:ok, renderer_type, info.module}
      error -> error
    end
  end

  @doc """
  Gets renderer for a specific environment.
  """
  @spec select_for_environment(atom(), keyword()) :: {:ok, atom(), module()} | {:error, term()}
  def select_for_environment(env, opts \\ [])

  def select_for_environment(env, opts) when env in [:dev, :test, :prod] do
    configured = Application.get_env(:ash_ui, :rendering, [])
    env_renderers = Keyword.get(configured, :env_renderers, %{})

    case Map.get(env_renderers, env) do
      nil ->
        default = Keyword.get(configured, :default_renderer, :liveview)
        get_renderer_with_validation(default, opts)

      renderer_type ->
        get_renderer_with_validation(renderer_type, opts)
    end
  end

  def select_for_environment(_env, _opts) do
    {:error, :invalid_environment}
  end

  defp select_renderer_type(conn_or_map, opts) do
    cond do
      Keyword.has_key?(opts, :renderer) ->
        {:ok, Keyword.fetch!(opts, :renderer)}

      not Keyword.get(opts, :ignore_headers, false) ->
        case get_renderer_from_header(conn_or_map) do
          {:ok, renderer} -> {:ok, renderer}
          {:error, :no_header} -> select_from_context(conn_or_map)
          error -> error
        end

      true ->
        select_from_context(conn_or_map)
    end
  end

  defp select_from_context(conn_or_map) do
    cond do
      liveview_request?(conn_or_map) ->
        {:ok, :liveview}

      http_request?(conn_or_map) ->
        {:ok, :html}

      true ->
        configured = Application.get_env(:ash_ui, :rendering, [])
        {:ok, Keyword.get(configured, :default_renderer, :liveview)}
    end
  end

  defp resolve_fallback_renderer(opts) do
    configured = Application.get_env(:ash_ui, :rendering, [])

    requested_fallback =
      Keyword.get(opts, :fallback_renderer, Keyword.get(configured, :fallback_renderer))

    exclude = excluded_types(opts)

    with {:ok, fallback} <- validate_requested_fallback(requested_fallback, exclude),
         {:ok, info} <- Registry.resolve_renderer(fallback, fallback_opts(opts)) do
      {:ok, fallback, info}
    else
      {:error, :skip_requested_fallback} ->
        find_first_fallback(exclude, fallback_opts(opts))

      {:error, :not_available} ->
        find_first_fallback(exclude, fallback_opts(opts))

      {:error, :no_requested_fallback} ->
        find_first_fallback(exclude, fallback_opts(opts))

      {:error, :not_found} ->
        {:error, :no_fallback}

      error ->
        error
    end
  end

  defp find_first_fallback(exclude, opts) do
    @renderer_types
    |> Enum.reject(&(&1 in exclude))
    |> Enum.find_value({:error, :no_fallback}, fn type ->
      case Registry.resolve_renderer(type, opts) do
        {:ok, info} -> {:ok, type, info}
        _ -> false
      end
    end)
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

  defp get_renderer_with_validation(renderer_type, opts) do
    case Registry.resolve_renderer(renderer_type, opts) do
      {:ok, info} ->
        {:ok, renderer_type, info.module}

      {:error, :not_available} ->
        {:error, {:renderer_not_available, renderer_type}}

      {:error, :not_found} ->
        {:error, {:renderer_not_found, renderer_type}}
    end
  end

  defp has_header?(conn_or_map, header_name, values) do
    header_value = get_request_header(conn_or_map, header_name)

    if is_binary(header_value) do
      if values == [] do
        true
      else
        Enum.any?(values, fn value ->
          String.contains?(String.downcase(header_value), value)
        end)
      end
    else
      false
    end
  end

  defp has_param?(conn_or_map, param_name, values) do
    param_value = get_request_param(conn_or_map, param_name)

    if param_value do
      if values == [] do
        true
      else
        param_value in values
      end
    else
      false
    end
  end

  defp has_session_key?(conn_or_map, key) do
    session = get_request_session(conn_or_map)
    is_map(session) and Map.has_key?(session, key)
  end

  defp get_request_header(%Plug.Conn{} = conn, header_name) do
    conn
    |> Plug.Conn.get_req_header(header_name)
    |> case do
      [value | _] when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp get_request_header(map, header_name) when is_map(map) do
    headers = Map.get(map, :headers) || Map.get(map, "headers") || %{}

    Map.get(headers, header_name) ||
      safe_get_atom_key(headers, header_name) ||
      Map.get(headers, "http-#{String.downcase(header_name)}")
  end

  defp get_request_param(%Plug.Conn{} = conn, param_name) do
    params = conn.params || %{}
    Map.get(params, param_name)
  end

  defp get_request_param(map, param_name) when is_map(map) do
    params = Map.get(map, :params) || Map.get(map, "params") || %{}
    Map.get(params, param_name)
  end

  defp get_request_session(%Plug.Conn{} = conn) do
    Map.get(conn.assigns, :session) || %{}
  end

  defp get_request_session(map) when is_map(map) do
    Map.get(map, :session) || Map.get(map, "session") || %{}
  end

  defp safe_get_atom_key(map, key) do
    Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> nil
  end

  defp excluded_types(opts) do
    opts
    |> Keyword.get(:exclude, [])
    |> List.wrap()
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

  defp fallback_opts(opts) do
    allow_adapter_fallback =
      Keyword.get(
        opts,
        :fallback_allow_adapter_fallback,
        Keyword.get(opts, :allow_adapter_fallback, adapter_fallback_enabled?())
      )

    Keyword.put(opts, :allow_adapter_fallback, allow_adapter_fallback)
  end

  defp adapter_fallback_enabled? do
    Application.get_env(:ash_ui, :rendering, [])
    |> Keyword.get(:allow_adapter_fallback, true)
  end

  defp maybe_record_fallback(_requested, _selected, _info, _reason, false), do: :ok

  defp maybe_record_fallback(requested, selected, info, reason, true) do
    record_fallback(requested, selected, info, reason)
  end

  defp record_fallback(requested, selected, info, reason) do
    metadata = %{
      renderer: :fallback,
      status: :ok,
      requested_renderer: requested,
      selected_renderer: selected,
      resolved_mode: info.mode,
      fallback_reason: reason
    }

    Logger.warning(
      "Renderer fallback engaged: requested=#{inspect(requested)} selected=#{inspect(selected)} " <>
        "mode=#{inspect(info.mode)} reason=#{inspect(reason)}"
    )

    Telemetry.execute([:ash_ui, :render, :fallback], %{count: 1}, metadata)
    :ok
  end
end
