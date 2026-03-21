defmodule AshUI.TelemetryTest do
  use ExUnit.Case, async: false

  alias AshUI.Compiler
  alias AshUI.Rendering.LiveUIAdapter
  alias AshUI.Resources.Screen
  alias AshUI.Runtime.BindingEvaluator
  alias AshUI.Telemetry

  @moduletag :conformance

  setup do
    Telemetry.reset_metrics()
    :ok
  end

  test "defines the required phase 8 telemetry events" do
    event_names = Enum.map(Telemetry.events(), & &1.event_name)

    assert [:ash_ui, :screen, :mount] in event_names
    assert [:ash_ui, :screen, :unmount] in event_names
    assert [:ash_ui, :binding, :evaluate] in event_names
    assert [:ash_ui, :render, :complete] in event_names
  end

  test "binding evaluation emits canonical telemetry with duration" do
    handler_id = "binding-evaluate-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash_ui, :binding, :evaluate],
      fn _, measurements, metadata, _ ->
        send(self(), {:binding_event, measurements, metadata})
      end,
      :ok
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    binding = %{
      id: "binding-telemetry",
      source: %{"resource" => "User", "field" => "name"},
      target: "name-input",
      binding_type: :value
    }

    assert {:ok, _value} =
             BindingEvaluator.evaluate(binding, %{user_id: "user-1", params: %{}, assigns: %{}})

    assert_receive {:binding_event, measurements, metadata}
    assert is_integer(measurements.duration)
    assert metadata.binding_id == "binding-telemetry"
    assert metadata.status == :ok
  end

  test "compiler emits compile lifecycle telemetry" do
    start_handler_id = "compile-start-#{System.unique_integer([:positive])}"
    end_handler_id = "compile-end-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      start_handler_id,
      [:ash_ui, :compilation, :compile_start],
      fn _, measurements, metadata, _ ->
        send(self(), {:compile_start, measurements, metadata})
      end,
      :ok
    )

    :telemetry.attach(
      end_handler_id,
      [:ash_ui, :compilation, :compile_end],
      fn _, measurements, metadata, _ ->
        send(self(), {:compile_end, measurements, metadata})
      end,
      :ok
    )

    on_exit(fn ->
      :telemetry.detach(start_handler_id)
      :telemetry.detach(end_handler_id)
    end)

    screen = %Screen{
      id: "screen-telemetry",
      name: "Telemetry Screen",
      unified_dsl: %{
        type: "row",
        props: %{},
        children: [],
        signals: [],
        metadata: %{}
      },
      metadata: %{},
      version: 1
    }

    assert {:ok, _compiled} = Compiler.compile(screen, use_cache: false)

    assert_receive {:compile_start, _measurements, start_metadata}
    assert start_metadata.resource_id == "screen-telemetry"

    assert_receive {:compile_end, measurements, end_metadata}
    assert is_integer(measurements.duration)
    assert end_metadata.status == :ok
  end

  test "render completion updates the in-memory telemetry snapshot" do
    handler_id = "render-complete-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash_ui, :render, :complete],
      fn _, measurements, metadata, _ ->
        send(self(), {:render_complete, measurements, metadata})
      end,
      :ok
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    canonical_iur = %{
      "type" => "screen",
      "id" => "render-screen",
      "name" => "Render Screen",
      "children" => [],
      "bindings" => [],
      "metadata" => %{}
    }

    assert {:ok, _rendered} = LiveUIAdapter.render(canonical_iur)

    assert_receive {:render_complete, measurements, metadata}
    assert is_integer(measurements.duration)
    assert metadata.renderer == :live_ui

    snapshot = Telemetry.snapshot()
    assert snapshot.dashboards.renderer_usage.live_ui >= 1
    assert snapshot.dashboards.screen_performance.render_count >= 1
  end

  test "dashboard definitions are present and valid json" do
    dashboard_dir = "/Users/Pascal/code/ash/ash_ui/priv/monitoring/dashboards"

    expected_files = [
      "screen_performance.json",
      "error_rate.json",
      "authorization_failures.json",
      "renderer_usage.json"
    ]

    Enum.each(expected_files, fn file_name ->
      path = Path.join(dashboard_dir, file_name)

      assert {:ok, body} = File.read(path)
      assert {:ok, definition} = Jason.decode(body)
      assert is_binary(definition["title"])
      assert is_list(definition["panels"])
      assert definition["panels"] != []
    end)
  end

  test "propagates trace and span metadata through emitted events" do
    handler_id = "screen-mount-span-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash_ui, :screen, :mount],
      fn _, _measurements, metadata, _ ->
        send(self(), {:screen_mount, metadata})
      end,
      :ok
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    Telemetry.emit(
      :screen,
      :mount,
      %{count: 1},
      %{
        trace_id: "trace-1",
        span_id: "span-1",
        parent_span_id: "parent-1",
        screen_id: "screen-123"
      }
    )

    assert_receive {:screen_mount, metadata}
    assert metadata.trace_id == "trace-1"
    assert metadata.span_id == "span-1"
    assert metadata.parent_span_id == "parent-1"
    assert metadata.screen_id == "screen-123"
  end

  test "redacts sensitive metadata before telemetry handlers receive it" do
    handler_id = "screen-mount-redaction-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash_ui, :screen, :mount],
      fn _, _measurements, metadata, _ ->
        send(self(), {:screen_mount_redacted, metadata})
      end,
      :ok
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    Telemetry.emit(
      :screen,
      :mount,
      %{count: 1},
      %{
        user_id: "user-1",
        email: "pascal@example.com",
        token: "secret-token"
      }
    )

    assert_receive {:screen_mount_redacted, metadata}
    assert metadata.user_id == "user-1"
    refute Map.has_key?(metadata, :email)
    refute Map.has_key?(metadata, :token)
  end
end
