defmodule AshUI.Telemetry do
  @moduledoc """
  Central telemetry helpers and default metrics handlers for Ash UI.

  This module defines the canonical event catalog for Phase 8 observability,
  emits normalized telemetry payloads, and keeps lightweight in-memory metrics
  that local dashboards and tests can query.
  """

  use GenServer

  @metrics_table :ash_ui_telemetry_metrics
  @default_handler_id "ash-ui-default-telemetry"
  @sensitive_keys [
    :email,
    "email",
    :name,
    "name",
    :password,
    "password",
    :token,
    "token",
    :secret,
    "secret"
  ]

  @common_metadata [
    :resource_id,
    :resource_type,
    :screen_id,
    :session_id,
    :user_id,
    :status,
    :error,
    :trace_id,
    :span_id,
    :parent_span_id
  ]

  @event_definitions [
    %{
      event_name: [:ash_ui, :screen, :mount],
      description: "Screen mount completed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata
    },
    %{
      event_name: [:ash_ui, :screen, :unmount],
      description: "Screen unmount completed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata
    },
    %{
      event_name: [:ash_ui, :screen, :update],
      description: "Screen update observed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata
    },
    %{
      event_name: [:ash_ui, :screen, :mount_error],
      description: "Screen mount failed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata
    },
    %{
      event_name: [:ash_ui, :screen, :auth_failure],
      description: "Screen authorization failed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata
    },
    %{
      event_name: [:ash_ui, :binding, :evaluate],
      description: "Binding evaluation completed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:binding_id, :binding_type, :target]
    },
    %{
      event_name: [:ash_ui, :binding, :update],
      description: "Binding update completed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:binding_id, :binding_type, :target]
    },
    %{
      event_name: [:ash_ui, :binding, :error],
      description: "Binding operation failed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:binding_id, :binding_type, :target]
    },
    %{
      event_name: [:ash_ui, :compilation, :compile_start],
      description: "Compilation started",
      measurements: [:count, :system_time],
      metadata: @common_metadata ++ [:cache]
    },
    %{
      event_name: [:ash_ui, :compilation, :compile_end],
      description: "Compilation completed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:cache]
    },
    %{
      event_name: [:ash_ui, :compilation, :compile_error],
      description: "Compilation failed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:cache]
    },
    %{
      event_name: [:ash_ui, :render, :start],
      description: "Rendering started",
      measurements: [:count, :system_time],
      metadata: @common_metadata ++ [:renderer]
    },
    %{
      event_name: [:ash_ui, :render, :complete],
      description: "Rendering completed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:renderer]
    },
    %{
      event_name: [:ash_ui, :render, :fallback],
      description: "Renderer fallback selected",
      measurements: [:count, :system_time],
      metadata: @common_metadata ++ [:renderer, :requested_renderer, :selected_renderer]
    },
    %{
      event_name: [:ash_ui, :render, :error],
      description: "Rendering failed",
      measurements: [:count, :duration, :system_time],
      metadata: @common_metadata ++ [:renderer]
    },
    %{
      event_name: [:ash_ui, :authorization, :auth_check],
      description: "Authorization check performed",
      measurements: [:count, :system_time],
      metadata: @common_metadata ++ [:action]
    },
    %{
      event_name: [:ash_ui, :authorization, :auth_success],
      description: "Authorization check succeeded",
      measurements: [:count, :system_time],
      metadata: @common_metadata ++ [:action]
    },
    %{
      event_name: [:ash_ui, :authorization, :auth_fail],
      description: "Authorization check failed",
      measurements: [:count, :system_time],
      metadata: @common_metadata ++ [:action]
    }
  ]

  @type event_definition :: %{
          event_name: [atom()],
          description: String.t(),
          measurements: [atom()],
          metadata: [atom()]
        }

  @doc """
  Starts the telemetry process and installs the default handler set.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  @doc false
  def init(state) do
    ensure_metrics_table()
    attach_default_handlers()
    {:ok, state}
  end

  @doc """
  Returns the canonical Ash UI event catalog.
  """
  @spec events() :: [event_definition()]
  def events, do: @event_definitions

  @doc """
  Attaches the default telemetry handlers that populate the in-memory metrics table.
  """
  @spec attach_default_handlers() :: :ok
  def attach_default_handlers do
    ensure_metrics_table()
    event_names = Enum.map(@event_definitions, & &1.event_name)

    case :telemetry.attach_many(@default_handler_id, event_names, &__MODULE__.handle_event/4, %{}) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @doc """
  Detaches the default telemetry handlers if they are attached.
  """
  @spec detach_default_handlers() :: :ok
  def detach_default_handlers do
    :telemetry.detach(@default_handler_id)
    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Clears the accumulated in-memory telemetry counters.
  """
  @spec reset_metrics() :: :ok
  def reset_metrics do
    ensure_metrics_table()
    :ets.delete_all_objects(@metrics_table)
    :ok
  end

  @doc """
  Returns a snapshot of aggregated telemetry counters and dashboard-friendly metrics.
  """
  @spec snapshot() :: map()
  def snapshot do
    ensure_metrics_table()
    rows = Map.new(:ets.tab2list(@metrics_table))

    %{
      events:
        Enum.map(@event_definitions, fn definition ->
          key = event_key(definition.event_name)

          Map.merge(definition, %{
            count: counter(rows, {:count, key}),
            total_duration: counter(rows, {:duration, key}),
            ok_count: counter(rows, {:status, key, :ok}),
            error_count: counter(rows, {:status, key, :error})
          })
        end),
      dashboards: %{
        screen_performance: screen_performance_snapshot(rows),
        error_rate: error_rate_snapshot(rows),
        authorization_failures: authorization_failure_snapshot(rows),
        renderer_usage: renderer_usage_snapshot(rows)
      }
    }
  end

  @doc """
  Emits a canonical Ash UI telemetry event for the given category and event name.
  """
  @spec emit(atom(), atom(), map(), map(), keyword()) :: :ok
  def emit(category, event, measurements \\ %{}, metadata \\ %{}, opts \\ []) do
    execute([:ash_ui, category, event], measurements, metadata, opts)
  end

  @doc """
  Executes a telemetry event after normalizing measurements and metadata.
  """
  @spec execute([atom()], map(), map(), keyword()) :: :ok
  def execute(event_name, measurements \\ %{}, metadata \\ %{}, opts \\ [])
      when is_list(event_name) do
    normalized_measurements = normalize_measurements(measurements)
    normalized_metadata = normalize_metadata(event_name, metadata)

    :telemetry.execute(event_name, normalized_measurements, normalized_metadata)

    Enum.each(Keyword.get(opts, :legacy_event_names, []), fn legacy_event_name ->
      :telemetry.execute(legacy_event_name, normalized_measurements, normalized_metadata)
    end)

    :ok
  end

  @doc """
  Default telemetry handler used to accumulate counts, durations, and status metrics.
  """
  @spec handle_event([atom()], map(), map(), map()) :: :ok
  def handle_event(event_name, measurements, metadata, _config) do
    ensure_metrics_table()
    key = event_key(event_name)

    increment_counter({:count, key}, measurement_value(measurements, :count, 1))
    increment_counter({:duration, key}, measurement_value(measurements, :duration, 0))

    status = Map.get(metadata, :status, infer_status(event_name, metadata))
    increment_counter({:status, key, status}, 1)

    case Map.get(metadata, :renderer) do
      nil -> :ok
      renderer -> increment_counter({:renderer, renderer}, 1)
    end

    if status == :error or not is_nil(Map.get(metadata, :error)) do
      increment_counter({:errors, :total}, 1)
    end

    :ok
  end

  defp screen_performance_snapshot(rows) do
    mount_count = event_metric(rows, [:ash_ui, :screen, :mount], :count)
    mount_duration = event_metric(rows, [:ash_ui, :screen, :mount], :duration)
    compile_count = event_metric(rows, [:ash_ui, :compilation, :compile_end], :count)
    compile_duration = event_metric(rows, [:ash_ui, :compilation, :compile_end], :duration)
    render_count = event_metric(rows, [:ash_ui, :render, :complete], :count)
    render_duration = event_metric(rows, [:ash_ui, :render, :complete], :duration)

    %{
      mount_count: mount_count,
      average_mount_duration: average_duration(mount_duration, mount_count),
      compile_count: compile_count,
      average_compile_duration: average_duration(compile_duration, compile_count),
      render_count: render_count,
      average_render_duration: average_duration(render_duration, render_count)
    }
  end

  defp error_rate_snapshot(rows) do
    total_events =
      @event_definitions
      |> Enum.map(&counter(rows, {:count, event_key(&1.event_name)}))
      |> Enum.sum()

    total_errors = counter(rows, {:errors, :total})

    %{
      total_events: total_events,
      total_errors: total_errors,
      error_rate: ratio(total_errors, total_events)
    }
  end

  defp authorization_failure_snapshot(rows) do
    %{
      authorization_failures: event_metric(rows, [:ash_ui, :authorization, :auth_fail], :count),
      screen_auth_failures: event_metric(rows, [:ash_ui, :screen, :auth_failure], :count)
    }
  end

  defp renderer_usage_snapshot(rows) do
    %{
      live_ui: counter(rows, {:renderer, :live_ui}),
      web_ui: counter(rows, {:renderer, :web_ui}),
      desktop_ui: counter(rows, {:renderer, :desktop_ui}),
      fallback: counter(rows, {:renderer, :fallback})
    }
  end

  defp event_metric(rows, event_name, metric) do
    counter(rows, {metric, event_key(event_name)})
  end

  defp average_duration(_duration, 0), do: 0.0
  defp average_duration(duration, count), do: duration / count

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp counter(rows, key), do: Map.get(rows, key, 0)

  defp increment_counter(_key, amount) when not is_integer(amount), do: :ok
  defp increment_counter(_key, amount) when amount < 0, do: :ok

  defp increment_counter(key, amount) do
    :ets.update_counter(@metrics_table, key, {2, amount}, {key, 0})
    :ok
  end

  defp measurement_value(measurements, key, default) do
    case Map.get(measurements, key, default) do
      value when is_integer(value) -> value
      value when is_float(value) -> round(value)
      _ -> default
    end
  end

  defp normalize_measurements(measurements) do
    measurements =
      case measurements do
        value when is_map(value) -> value
        value when is_list(value) -> Map.new(value)
        _ -> %{}
      end

    measurements
    |> Enum.filter(fn {_key, value} -> is_integer(value) or is_float(value) end)
    |> Map.new()
    |> Map.put_new(:count, 1)
    |> Map.put_new(:system_time, System.system_time(:native))
  end

  defp normalize_metadata(event_name, metadata) do
    metadata =
      case metadata do
        value when is_map(value) -> value
        value when is_list(value) -> Map.new(value)
        _ -> %{}
      end

    metadata
    |> redact_sensitive_data()
    |> Map.put_new(:status, infer_status(event_name, metadata))
  end

  defp redact_sensitive_data(metadata) do
    Enum.reduce(@sensitive_keys, metadata, &Map.delete(&2, &1))
  end

  defp infer_status(event_name, metadata) do
    cond do
      Map.has_key?(metadata, :status) -> Map.get(metadata, :status)
      Map.has_key?(metadata, :error) -> :error
      List.last(event_name) in [:error, :mount_error, :auth_failure, :auth_fail] -> :error
      true -> :ok
    end
  end

  defp event_key(event_name) do
    event_name
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end

  defp ensure_metrics_table do
    case :ets.whereis(@metrics_table) do
      :undefined ->
        :ets.new(@metrics_table, [:named_table, :public, :set, read_concurrency: true])
        :ok

      _table ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end
end
