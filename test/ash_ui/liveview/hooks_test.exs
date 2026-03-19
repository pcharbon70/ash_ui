defmodule AshUI.LiveView.HooksTest do
  use ExUnit.Case, async: true

  alias AshUI.LiveView.Hooks

  # Mock socket for testing
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  describe "on_mount_ash_ui/3" do
    test "initializes ash_ui assigns" do
      socket = build_socket()

      assert {:cont, socket} = Hooks.on_mount_ash_ui(%{}, %{}, socket)
      assert socket.assigns[:ash_ui_loaded] == false
      assert socket.assigns[:ash_ui_subscriptions] == []
    end
  end

  describe "register_callback/4" do
    test "registers on_init callback" do
      socket = build_socket()
      callback = fn socket -> assign(socket, :initialized, true) end

      socket = Hooks.register_callback(socket, :on_init, callback)

      callbacks = socket.assigns[:ash_ui_callbacks]
      assert Map.has_key?(callbacks, :on_init)
      assert length(callbacks[:on_init]) == 1
    end

    test "registers multiple callbacks for same type" do
      socket = build_socket()
      callback1 = fn socket -> socket end
      callback2 = fn socket -> socket end

      socket =
        socket
        |> Hooks.register_callback(:on_init, callback1)
        |> Hooks.register_callback(:on_init, callback2)

      callbacks = socket.assigns[:ash_ui_callbacks]
      assert length(callbacks[:on_init]) == 2
    end
  end

  describe "execute_callbacks/2" do
    test "executes registered on_init callbacks" do
      callback = fn socket ->
        Phoenix.LiveView.assign(socket, :callback_executed, true)
      end

      socket =
        build_socket()
        |> Hooks.register_callback(:on_init, callback)

      socket = Hooks.execute_callbacks(socket, :on_init)

      assert socket.assigns[:callback_executed] == true
    end

    test "executes callbacks in order" do
      callback1 = fn socket ->
        Phoenix.LiveView.assign(socket, :order, ["first"])
      end

      callback2 = fn socket ->
        order = socket.assigns[:order] || []
        Phoenix.LiveView.assign(socket, :order, order ++ ["second"])
      end

      socket =
        build_socket()
        |> Hooks.register_callback(:on_init, callback1)
        |> Hooks.register_callback(:on_init, callback2)

      socket = Hooks.execute_callbacks(socket, :on_init)

      assert socket.assigns[:order] == ["first", "second"]
    end

    test "handles callback errors gracefully" do
      # Add a callback that will error
      error_callback = fn _socket -> raise "Callback error" end

      # Add a callback that should still execute
      success_callback = fn socket ->
        Phoenix.LiveView.assign(socket, :still_executed, true)
      end

      socket =
        build_socket()
        |> Hooks.register_callback(:on_init, error_callback)
        |> Hooks.register_callback(:on_init, success_callback)

      socket = Hooks.execute_callbacks(socket, :on_init)

      # The second callback should still execute
      assert socket.assigns[:still_executed] == true
    end

    test "returns socket unchanged when no callbacks registered" do
      socket = build_socket(original: true)

      socket = Hooks.execute_callbacks(socket, :on_init)

      assert socket.assigns[:original] == true
    end
  end

  describe "on_update/2" do
    test "applies callback to socket" do
      socket = build_socket()

      callback = fn socket ->
        Phoenix.LiveView.assign(socket, :updated, true)
      end

      assert {:cont, socket} = Hooks.on_update(socket, callback)
      assert socket.assigns[:updated] == true
    end

    test "returns cont tuple with updated socket" do
      socket = build_socket()

      callback = fn socket ->
        Phoenix.LiveView.assign(socket, :value, 42)
      end

      assert {:cont, socket} = Hooks.on_update(socket, callback)
      assert socket.assigns[:value] == 42
    end
  end

  describe "cleanup_session/1" do
    test "clears subscriptions" do
      socket =
        build_socket(ash_ui_subscriptions: [:sub1, :sub2])

      socket = Hooks.cleanup_session(socket)

      assert socket.assigns[:ash_ui_subscriptions] == []
    end

    test "clears bindings" do
      socket =
        build_socket(ash_ui_bindings: %{binding1: "value"})

      socket = Hooks.cleanup_session(socket)

      assert socket.assigns[:ash_ui_bindings] == %{}
    end

    test "handles socket without ash_ui assigns" do
      socket = build_socket()

      socket = Hooks.cleanup_session(socket)

      assert socket.assigns[:ash_ui_subscriptions] == []
      assert socket.assigns[:ash_ui_bindings] == %{}
    end
  end

  describe "on_unmount/1" do
    test "cleans up subscriptions" do
      socket =
        build_socket(
          ash_ui_screen: %{id: "screen-1"},
          ash_ui_subscriptions: [:sub1]
        )

      assert :ok = Hooks.on_unmount(socket)
    end

    test "returns ok for socket without screen" do
      socket = build_socket()

      assert :ok = Hooks.on_unmount(socket)
    end
  end
end
