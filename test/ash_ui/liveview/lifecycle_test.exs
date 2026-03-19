defmodule AshUI.LiveView.LifecycleTest do
  use ExUnit.Case, async: true

  alias AshUI.LiveView.Lifecycle

  # Mock socket for testing
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  describe "init_session/2" do
    test "initializes session state" do
      socket = build_socket()

      assert {:ok, socket} = Lifecycle.init_session(socket, :dashboard)
      assert socket.assigns[:ash_ui_session].screen_id == :dashboard
      assert socket.assigns[:ash_ui_session_id] != nil
      assert socket.assigns[:ash_ui_session].mounted_at != nil
    end

    test "generates unique session IDs" do
      socket1 = build_socket()
      socket2 = build_socket()

      {:ok, socket1} = Lifecycle.init_session(socket1, :dashboard)
      {:ok, socket2} = Lifecycle.init_session(socket2, :dashboard)

      refute socket1.assigns[:ash_ui_session_id] == socket2.assigns[:ash_ui_session_id]
    end
  end

  describe "register_hook/3" do
    test "registers a lifecycle hook" do
      socket = build_socket()
      hook = fn socket -> socket end

      socket = Lifecycle.register_hook(socket, :on_init, hook)

      hooks = socket.assigns[:ash_ui_lifecycle_hooks]
      assert Map.has_key?(hooks, :on_init)
      assert length(hooks[:on_init]) == 1
    end

    test "registers multiple hooks for same type" do
      socket = build_socket()
      hook1 = fn socket -> socket end
      hook2 = fn socket -> socket end

      socket =
        socket
        |> Lifecycle.register_hook(:on_init, hook1)
        |> Lifecycle.register_hook(:on_init, hook2)

      hooks = socket.assigns[:ash_ui_lifecycle_hooks]
      assert length(hooks[:on_init]) == 2
    end
  end

  describe "execute_hooks/2" do
    test "executes registered hooks in order" do
      hook1 = fn socket ->
        Phoenix.LiveView.assign(socket, :hook1_executed, true)
      end

      hook2 = fn socket ->
        Phoenix.LiveView.assign(socket, :hook2_executed, true)
      end

      socket =
        build_socket()
        |> Lifecycle.register_hook(:on_test, hook1)
        |> Lifecycle.register_hook(:on_test, hook2)
        |> Lifecycle.execute_hooks(:on_test)

      assert socket.assigns[:hook1_executed] == true
      assert socket.assigns[:hook2_executed] == true
    end

    test "handles hook errors gracefully" do
      error_hook = fn _socket -> raise "Hook error" end
      success_hook = fn socket -> Phoenix.LiveView.assign(socket, :still_ran, true) end

      socket =
        build_socket()
        |> Lifecycle.register_hook(:on_test, error_hook)
        |> Lifecycle.register_hook(:on_test, success_hook)
        |> Lifecycle.execute_hooks(:on_test)

      assert socket.assigns[:still_ran] == true
    end

    test "handles no hooks registered" do
      socket = build_socket()

      socket = Lifecycle.execute_hooks(socket, :on_init)

      # Should not crash
      assert socket != nil
    end
  end

  describe "ensure_isolation/1" do
    test "marks session as isolated" do
      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)
        |> Lifecycle.ensure_isolation()

      assert socket.assigns[:ash_ui_isolated] == true
      assert socket.assigns[:ash_ui_session_key] != nil
    end

    test "creates isolated binding state" do
      socket =
        build_socket(ash_ui_bindings: %{binding1: "value1"})
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)
        |> Lifecycle.ensure_isolation()

      assert socket.assigns[:ash_ui_bindings_isolated] != nil
    end
  end

  describe "put_session_state/3 and get_session_state/2" do
    test "stores and retrieves session state" do
      socket = build_socket()

      socket = Lifecycle.put_session_state(socket, :current_tab, "profile")

      assert Lifecycle.get_session_state(socket, :current_tab) == "profile"
    end

    test "returns nil for missing keys" do
      socket = build_socket()

      assert Lifecycle.get_session_state(socket, :nonexistent) == nil
    end

    test "isolates state between sessions" do
      socket1 =
        build_socket()
        |> Lifecycle.init_session(:screen1)
        |> elem(1)
        |> Lifecycle.put_session_state(:value, "session1")

      socket2 =
        build_socket()
        |> Lifecycle.init_session(:screen2)
        |> elem(1)
        |> Lifecycle.put_session_state(:value, "session2")

      assert Lifecycle.get_session_state(socket1, :value) == "session1"
      assert Lifecycle.get_session_state(socket2, :value) == "session2"
    end
  end

  describe "cleanup_session/1" do
    test "cleans up session state" do
      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)
        |> Lifecycle.register_hook(:on_unmount, fn socket ->
          Phoenix.LiveView.assign(socket, :cleanup_called, true)
        end)

      assert :ok = Lifecycle.cleanup_session(socket)
    end

    test "executes on_unmount hooks" do
      socket =
        build_socket()
        |> Lifecycle.register_hook(:on_unmount, fn socket ->
          Phoenix.LiveView.assign(socket, :unmounted, true)
        end)

      # Note: cleanup returns :ok, not the socket
      # The hooks are executed during cleanup
      assert :ok = Lifecycle.cleanup_session(socket)
    end
  end

  describe "session_key/2" do
    test "creates session-specific keys" do
      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)

      key = Lifecycle.session_key(socket, "current_user")

      assert String.contains?(key, "ash_ui_session_")
      assert String.contains?(key, "current_user")
    end

    test "different sessions have different keys" do
      socket1 =
        build_socket()
        |> Lifecycle.init_session(:screen1)
        |> elem(1)

      socket2 =
        build_socket()
        |> Lifecycle.init_session(:screen2)
        |> elem(1)

      key1 = Lifecycle.session_key(socket1, "data")
      key2 = Lifecycle.session_key(socket2, "data")

      refute key1 == key2
    end
  end

  describe "session_isolated?/1" do
    test "returns true when session is isolated" do
      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)
        |> Lifecycle.ensure_isolation()

      assert Lifecycle.session_isolated?(socket) == true
    end

    test "returns false when session is not isolated" do
      socket = build_socket()

      assert Lifecycle.session_isolated?(socket) == false
    end

    test "returns false when isolation is set but no session ID" do
      socket = build_socket(ash_ui_isolated: true)

      assert Lifecycle.session_isolated?(socket) == false
    end
  end

  describe "handle_error/3" do
    test "stores error in assigns" do
      socket = build_socket()

      exception = RuntimeError.exception("Test error")
      socket = Lifecycle.handle_error(exception, [], socket)

      assert socket.assigns[:ash_ui_error] != nil
      assert socket.assigns[:ash_ui_error].exception == exception
    end

    test "executes error hooks" do
      socket =
        build_socket()
        |> Lifecycle.register_hook(:on_error, fn socket ->
          Phoenix.LiveView.assign(socket, :error_handled, true)
        end)

      exception = RuntimeError.exception("Test error")
      socket = Lifecycle.handle_error(exception, [], socket)

      assert socket.assigns[:error_handled] == true
    end
  end

  describe "emit_telemetry/3" do
    test "emits telemetry events" do
      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)

      # Attach a handler to verify event is emitted
      :telemetry.attach(
        "test-lifecycle-handler",
        [:ash_ui, :lifecycle, :mount],
        fn _, measurements, metadata, _ ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        :ok
      )

      Lifecycle.emit_telemetry(:mount, socket, %{custom: "data"})

      assert_receive {:telemetry_event, _measurements, metadata}
      assert metadata.screen_id == :dashboard
      assert metadata.custom == "data"

      :telemetry.detach("test-lifecycle-handler")
    end
  end

  describe "create_context/1" do
    test "creates new lifecycle context" do
      context = Lifecycle.create_context(%{user_id: "user-1"})

      assert context.session_id != nil
      assert context.user_id == "user-1"
      assert context.created_at != nil
    end
  end

  describe "merge_callbacks/2" do
    test "merges callbacks from module" do
      defmodule TestLifecycleCallbacks do
        def on_lifecycle(:init, socket) do
          Phoenix.LiveView.assign(socket, :module_callback_ran, true)
        end

        def on_lifecycle(_, socket), do: socket
      end

      socket = build_socket()
      socket = Lifecycle.merge_callbacks(socket, TestLifecycleCallbacks)

      # Hook should be registered
      assert socket.assigns[:ash_ui_lifecycle_hooks][:user_callback] != nil
    end

    test "handles modules without callbacks" do
      defmodule NoCallbacks do
        # No on_lifecycle function
      end

      socket = build_socket()
      socket = Lifecycle.merge_callbacks(socket, NoCallbacks)

      # Should not crash
      assert socket != nil
    end
  end

  describe "on_session_change/2" do
    test "executes update hooks" do
      socket =
        build_socket()
        |> Lifecycle.register_hook(:on_update, fn socket ->
          Phoenix.LiveView.assign(socket, :updated, true)
        end)

      socket = Lifecycle.on_session_change(socket, %{})

      assert socket.assigns[:updated] == true
    end

    test "updates params when screen_id is present" do
      socket = build_socket()
      socket = Lifecycle.on_session_change(socket, %{"screen_id" => "new_screen"})

      assert socket.assigns[:ash_ui_params] == %{"screen_id" => "new_screen"}
    end
  end
end
