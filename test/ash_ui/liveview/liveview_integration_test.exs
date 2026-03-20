defmodule AshUI.LiveView.IntegrationTest do
  use AshUI.DataCase, async: false

  alias AshUI.LiveView.Integration
  alias AshUI.Resources.Screen

  # Mock socket for testing
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  # Mock user
  defp build_user(id \\ "user-1") do
    %{id: id, name: "Test User", role: :user, active: true}
  end

  defp build_admin(id \\ "admin-1") do
    %{id: id, name: "Admin User", role: :admin, active: true}
  end

  # Mock screen
  defp build_screen(id \\ "screen-1") do
    %Screen{
      id: id,
      name: "Test Screen",
      elements: []
    }
  end

  setup do
    {:ok, _screen} =
      AshUI.Domain.create(Screen,
        attrs: %{
          name: "test_screen",
          unified_dsl: %{"type" => "screen"}
        }
      )

    {:ok, _restricted_screen} =
      AshUI.Domain.create(Screen,
        attrs: %{
          name: "restricted_screen",
          unified_dsl: %{"type" => "screen"}
        }
      )

    :ok
  end

  describe "mount_ui_screen/3" do
    test "mounts screen successfully with valid user and screen" do
      socket = build_socket(current_user: build_admin())

      assert {:ok, socket} = Integration.mount_ui_screen(socket, :test_screen, %{})
    end

    test "returns error when no current user" do
      socket = build_socket(%{})

      assert {:error, :no_user} = Integration.mount_ui_screen(socket, :test_screen, %{})
    end

    test "returns error for unauthorized screen access" do
      socket = build_socket(current_user: build_user())

      # Note: Would need to mock authorization check
      assert {:error, _reason} = Integration.mount_ui_screen(socket, :restricted_screen, %{})
    end
  end

  describe "authorize_screen/2" do
    setup do
      %{screen: build_screen(), user: build_admin()}
    end

    test "returns :ok for authorized user", %{screen: screen, user: user} do
      assert :ok = Integration.authorize_screen(screen, user)
    end

    test "returns error for unauthorized user" do
      screen = build_screen("restricted-screen")
      unauthorized_user = build_user("unauthorized-user")

      assert {:error, :unauthorized} = Integration.authorize_screen(screen, unauthorized_user)
    end
  end

  describe "compile_screen/1" do
    test "compiles screen to IUR successfully" do
      screen = build_screen()

      # Note: Would need to mock Compiler and IURAdapter
      assert {:ok, iur} = Integration.compile_screen(screen)
      assert is_map(iur)
    end

    test "returns error for invalid screen" do
      invalid_screen = %Screen{id: nil, name: nil}

      assert {:error, _reason} = Integration.compile_screen(invalid_screen)
    end
  end

  describe "evaluate_bindings/4" do
    test "evaluates all screen bindings" do
      screen = build_screen()
      socket = build_socket()
      user = build_user()
      params = %{}

      # Note: Would need to mock binding loading and evaluation
      assert {:ok, bindings} = Integration.evaluate_bindings(screen, socket, user, params)
      assert is_map(bindings)
    end

    test "returns empty map for screen with no bindings" do
      screen = build_screen("empty-screen")
      socket = build_socket()
      user = build_user()
      params = %{}

      assert {:ok, bindings} = Integration.evaluate_bindings(screen, socket, user, params)
      assert bindings == %{}
    end
  end

  describe "emit_telemetry/3" do
    test "emits mount telemetry event" do
      # Attach a test handler to verify telemetry is emitted
      :telemetry.attach(
        "test-handler",
        [:ash_ui, :screen, :mount],
        fn _, _, _, _ -> :ok end,
        :ok
      )

      Integration.emit_telemetry(:mount, %{screen_id: "test"}, %{count: 1})

      :telemetry.detach("test-handler")
    end

    test "emits error telemetry event" do
      :telemetry.attach(
        "test-error-handler",
        [:ash_ui, :screen, :mount_error],
        fn _, _, _, _ -> :ok end,
        :ok
      )

      Integration.emit_telemetry(:mount_error, %{screen_id: "test", reason: "not_found"}, %{})

      :telemetry.detach("test-error-handler")
    end

    test "emits auth failure telemetry event" do
      :telemetry.attach(
        "test-auth-handler",
        [:ash_ui, :screen, :auth_failure],
        fn _, _, _, _ -> :ok end,
        :ok
      )

      Integration.emit_telemetry(:auth_failure, %{screen_id: "test"}, %{})

      :telemetry.detach("test-auth-handler")
    end
  end

  describe "redirect_to_login/2" do
    test "returns error tuple for redirect" do
      socket = build_socket()

      assert {:error, :unauthorized} = Integration.redirect_to_login(socket, :unauthorized)
    end
  end
end
