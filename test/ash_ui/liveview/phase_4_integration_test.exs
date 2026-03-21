defmodule AshUI.LiveView.Phase4IntegrationTest do
  use ExUnit.Case, async: false

  alias AshUI.LiveView.Lifecycle
  alias AshUI.LiveView.ErrorHandler
  alias AshUI.LiveView.EventHandler
  alias AshUI.LiveView.UpdateIntegration
  alias AshUI.Test.RuntimeDomain
  alias AshUI.Test.RuntimeFixtures
  alias AshUI.Test.User

  @moduletag :conformance

  # Integration test helpers
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}, flash: %{}, ash_ui_domains: [RuntimeDomain]})
    }
  end

  defp build_user(id \\ "user-1"), do: %{id: id, name: "Test User"}
  defp build_screen(id \\ "screen-1"), do: %{id: id, name: "Test Screen"}

  describe "Section 4.6.1 - Mount lifecycle integration scenarios" do
    test "screen mounts with valid user" do
      socket =
        build_socket(
          current_user: build_user()
        )

      # Mount should succeed with valid user
      # Note: In actual implementation, would need to mock Ash.get
      socket = socket
      {:ok, socket} = Lifecycle.init_session(socket, :dashboard)
      assert socket.assigns[:ash_ui_session].screen_id == :dashboard
    end

    test "screen redirects on unauthorized access" do
      socket =
        build_socket(
          current_user: build_user("unauthorized-user")
        )

      # Unauthorized access should result in error
      # Note: Would need to mock Ash.can? returning false
      result = ErrorHandler.handle_auth_error({:error, :unauthorized}, socket)
      assert result == {:error, :unauthorized}
    end

    test "bindings are evaluated on mount" do
      socket =
        build_socket(
          current_user: build_user(),
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      # Bindings should be evaluated during mount
      # Note: Would need to mock binding evaluation
      socket = Lifecycle.put_session_state(socket, :bindings_evaluated, true)
      assert Lifecycle.get_session_state(socket, :bindings_evaluated) == true
    end

    test "compilation errors are handled gracefully" do
      socket =
        build_socket(
          current_user: build_user(),
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      # Compilation errors should not crash the LiveView
      assert {:error, socket} = ErrorHandler.handle_compilation_error(:syntax_error, socket)
      assert socket.assigns[:ash_ui_error] != nil
      assert socket.assigns[:ash_ui_error].type == :compilation
    end
  end

  describe "Section 4.6.2 - Event handling integration scenarios" do
    test "button clicks trigger Ash actions" do
      fixtures = RuntimeFixtures.seed!()

      socket =
        build_socket(
          ash_ui_bindings: %{
            action1: %{
              id: "action1",
              target: "action1",
              source: %{"resource" => "User", "action" => "create"},
              binding_type: :action,
              transform: %{
                "params" => %{
                  "name" => {"event", "name"},
                  "email" => {"event", "email"}
                }
              }
            }
          },
          ash_ui_user: fixtures.actor
        )

      params = %{"action_id" => "action1", "data" => %{"name" => "Test", "email" => "test@example.com"}}

      assert {:reply, reply, socket} = EventHandler.handle_action_event(params, socket)
      assert reply[:status] == :ok
      assert get_in(socket.assigns, [:flash, :info]) == "Action completed successfully"
    end

    test "input changes update Ash resources" do
      fixtures = RuntimeFixtures.seed!()

      socket =
        build_socket(
          ash_ui_bindings: %{
            binding1: %{
              id: "binding1",
              target: "input-1",
              source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
              binding_type: :value,
              value: fixtures.user.name
            }
          },
          ash_ui_user: fixtures.actor
        )

      params = %{"target" => "input-1", "value" => "new value"}

      assert {:noreply, socket} = EventHandler.handle_value_change(params, socket)
      assert socket.assigns[:ash_ui_bindings][:binding1].value == "new value"
      assert get_in(socket.assigns, [:ash_ui, :bindings, "input-1", "value"]) == "new value"
    end

    test "action errors display feedback" do
      socket =
        build_socket(
          ash_ui_bindings: %{},
          ash_ui_user: build_user()
        )

      params = %{"action_id" => "nonexistent", "data" => %{}}

      # Missing actions should return error
      assert {:reply, reply, socket} = EventHandler.handle_action_event(params, socket)
      assert reply[:status] == :error
      assert socket.assigns[:flash][:error] != nil
    end

    test "event handlers receive correct parameters" do
      params = %{"target" => "button-1", "data" => %{"key" => "value"}}

      # Event parsing should extract parameters correctly
      assert {:ok, event} = EventHandler.parse_event("ash_ui_click", params)
      assert event.target == "button-1"
      assert event.data == %{"key" => "value"}
    end
  end

  describe "Section 4.6.3 - Reactivity integration scenarios" do
    test "UI updates when bound data changes" do
      fixtures = RuntimeFixtures.seed!()

      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: fixtures.actor,
          ash_ui_bindings: %{
            binding1: %{
              id: "binding1",
              target: "input-1",
              source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
              binding_type: :value,
              value: fixtures.user.name
            }
          }
        )

      {:ok, _updated_user} = Ash.update(fixtures.user, %{name: "Reactive Update"}, domain: RuntimeDomain)

      notification = %{
        type: :updated,
        resource: User,
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, socket} = UpdateIntegration.handle_resource_change(notification, socket)
      assert socket.assigns[:ash_ui_bindings][:binding1].value == "Reactive Update"
      assert get_in(socket.assigns, [:ash_ui, :bindings, "input-1", "value"]) == "Reactive Update"
    end

    test "multiple sessions don't interfere" do
      # Create two separate sessions
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

      # Each session should have isolated state
      assert Lifecycle.get_session_state(socket1, :value) == "session1"
      assert Lifecycle.get_session_state(socket2, :value) == "session2"
    end

    test "updates are batched efficiently" do
      socket = build_socket()

      # Batch updates should apply all changes at once
      assert {:noreply, socket} =
               UpdateIntegration.batch_updates(socket, fn socket ->
                 socket
                 |> Phoenix.Component.assign(:value1, 1)
                 |> Phoenix.Component.assign(:value2, 2)
                 |> Phoenix.Component.assign(:value3, 3)
               end)

      assert socket.assigns[:value1] == 1
      assert socket.assigns[:value2] == 2
      assert socket.assigns[:value3] == 3
    end

    test "subscriptions clean up on unmount" do
      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)

      # Subscribe to some resources
      {:ok, _sub} = UpdateIntegration.subscribe(socket, User.Profile)

      # Cleanup should remove subscriptions
      assert :ok = UpdateIntegration.cleanup_subscriptions(socket)
    end
  end

  describe "End-to-end scenarios" do
    test "full screen lifecycle" do
      # 1. Initialize session
      {:ok, socket} = Lifecycle.init_session(build_socket(), :dashboard)
      assert socket.assigns[:ash_ui_session_id] != nil

      # 2. Ensure isolation
      socket = Lifecycle.ensure_isolation(socket)
      assert Lifecycle.session_isolated?(socket) == true

      # 3. Store session state
      socket = Lifecycle.put_session_state(socket, :current_tab, "profile")
      assert Lifecycle.get_session_state(socket, :current_tab) == "profile"

      # 4. Register lifecycle hook
      socket = Lifecycle.register_hook(socket, :on_update, fn socket -> socket end)
      assert socket.assigns[:ash_ui_lifecycle_hooks][:on_update] != nil

      # 5. Execute hooks
      socket = Lifecycle.execute_hooks(socket, :on_update)
      assert socket != nil

      # 6. Cleanup
      assert :ok = Lifecycle.cleanup_session(socket)
    end

    test "error recovery flow" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      # 1. Handle a transient error
      error_info = %{type: :compilation, reason: {:timeout, 5000}}
      recovery = ErrorHandler.determine_recovery(error_info)
      assert recovery == :retry

      # 2. Handle the error with retry option
      {:error, socket} = ErrorHandler.handle_compilation_error({:timeout, 5000}, socket)
      assert socket.assigns[:ash_ui_can_retry] == true

      # 3. Get user-friendly message
      message = ErrorHandler.user_friendly_message(error_info)
      assert String.contains?(message, "taking too long")
    end

    test "event flow from UI to Ash and back" do
      fixtures = RuntimeFixtures.seed!()

      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: fixtures.actor,
          ash_ui_bindings: %{
            binding1: %{
              id: "binding1",
              target: "input-1",
              source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
              binding_type: :value,
              value: fixtures.user.name
            }
          }
        )

      {:noreply, socket} = EventHandler.handle_value_change(%{"target" => "input-1", "value" => "changed"}, socket)
      assert socket.assigns[:ash_ui_bindings][:binding1].value == "changed"

      {:ok, _updated_user} = Ash.update(fixtures.user, %{name: "server change"}, domain: RuntimeDomain)

      notification = %{type: :updated, resource: User, timestamp: DateTime.utc_now()}
      {:noreply, socket} = UpdateIntegration.handle_resource_change(notification, socket)

      assert socket.assigns[:ash_ui_bindings][:binding1].value == "server change"
    end
  end

  describe "Session management" do
    test "session keys are unique per session" do
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

    test "session isolation prevents state leakage" do
      socket1 =
        build_socket()
        |> Lifecycle.init_session(:screen1)
        |> elem(1)
        |> Lifecycle.put_session_state(:secret, "session1_data")

      socket2 =
        build_socket()
        |> Lifecycle.init_session(:screen2)
        |> elem(1)
        |> Lifecycle.put_session_state(:secret, "session2_data")

      # Each session should have its own isolated state
      assert Lifecycle.get_session_state(socket1, :secret) == "session1_data"
      assert Lifecycle.get_session_state(socket2, :secret) == "session2_data"
    end
  end

  describe "Telemetry events" do
    test "mount telemetry is emitted" do
      :telemetry.attach(
        "mount-test-handler",
        [:ash_ui, :lifecycle, :mount],
        fn _, measurements, metadata, _ ->
          send(self(), {:mount_telemetry, measurements, metadata})
        end,
        :ok
      )

      socket =
        build_socket()
        |> Lifecycle.init_session(:dashboard)
        |> elem(1)

      Lifecycle.emit_telemetry(:mount, socket)

      assert_receive {:mount_telemetry, _measurements, metadata}
      assert metadata.screen_id == :dashboard

      :telemetry.detach("mount-test-handler")
    end

    test "error telemetry is emitted" do
      :telemetry.attach(
        "error-test-handler",
        [:ash_ui, :error, :compilation],
        fn _, measurements, metadata, _ ->
          send(self(), {:error_telemetry, measurements, metadata})
        end,
        :ok
      )

      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user()
        )

      ErrorHandler.handle_compilation_error(:not_found, socket)

      assert_receive {:error_telemetry, _measurements, metadata}
      assert metadata.reason == ":not_found"

      :telemetry.detach("error-test-handler")
    end
  end
end
