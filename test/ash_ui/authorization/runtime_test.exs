defmodule AshUI.Authorization.RuntimeTest do
  use ExUnit.Case, async: false

  alias AshUI.Authorization.Runtime

  # Mock users
  defp build_admin(), do: %{id: "admin-1", role: :admin, active: true}
  defp build_user(id \\ "user-1"), do: %{id: id, role: :user, active: true}
  defp build_inactive(), do: %{id: "user-2", role: :user, active: false}

  # Mock socket
  defp build_socket(assigns) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  # Mock resources
  defp build_screen(opts \\ []) do
    Enum.into(opts, %{
      id: "screen-1",
      name: "Test Screen",
      public: false,
      owner_id: "user-1"
    })
  end

  defp build_binding(opts \\ []) do
    Enum.into(opts, %{
      id: "binding-1",
      binding_type: :value,
      read_only: false,
      source: %{}
    })
  end

  describe "check_mount_authorization/2" do
    test "authorizes admin for any screen" do
      screen = build_screen(public: false, owner_id: "other-user")
      assert Runtime.check_mount_authorization(build_admin(), screen) == :authorized
    end

    test "authorizes user for public screen" do
      screen = build_screen(public: true, owner_id: "other-user")
      assert Runtime.check_mount_authorization(build_user(), screen) == :authorized
    end

    test "authorizes user for their own screen" do
      screen = build_screen(public: false, owner_id: "user-1")
      assert Runtime.check_mount_authorization(build_user("user-1"), screen) == :authorized
    end

    test "forbids user from private screen owned by others" do
      screen = build_screen(public: false, owner_id: "user-2")
      assert {:forbidden, _} = Runtime.check_mount_authorization(build_user("user-1"), screen)
    end

    test "forbids inactive user" do
      screen = build_screen(public: true)
      assert {:forbidden, reason} = Runtime.check_mount_authorization(build_inactive(), screen)
      assert reason.reason == :inactive
    end

    test "forbids unauthenticated user" do
      screen = build_screen(public: true)
      assert {:forbidden, reason} = Runtime.check_mount_authorization(nil, screen)
      assert reason.reason == :unauthenticated
    end
  end

  describe "check_action_authorization/3" do
    test "authorizes admin for any action" do
      assert Runtime.check_action_authorization(build_admin(), :delete, %{}) == :authorized
    end

    test "authorizes active user for action" do
      assert Runtime.check_action_authorization(build_user(), :update, %{}) == :authorized
    end

    test "forbids inactive user" do
      assert {:forbidden, reason} = Runtime.check_action_authorization(build_inactive(), :update, %{})
      assert reason.reason == :inactive
    end

    test "forbids unauthenticated user" do
      assert {:forbidden, reason} = Runtime.check_action_authorization(nil, :update, %{})
      assert reason.reason == :unauthenticated
      assert reason.redirect == :login
    end

    test "includes error message in forbidden response" do
      assert {:forbidden, reason} =
               Runtime.check_action_authorization(build_inactive(), :delete, %{})

      assert is_binary(reason.message)
    end
  end

  describe "check_read_access/2" do
    test "authorizes user to read binding without source" do
      binding = build_binding(source: nil)
      assert Runtime.check_read_access(build_user(), binding) == :authorized
    end

    test "authorizes user to read binding with empty source" do
      binding = build_binding(source: %{})
      assert Runtime.check_read_access(build_user(), binding) == :authorized
    end

    test "forbids unauthenticated user" do
      binding = build_binding()
      assert {:forbidden, _} = Runtime.check_read_access(nil, binding)
    end
  end

  describe "check_write_access/2" do
    test "authorizes user to write to writable binding" do
      binding = build_binding(read_only: false)
      assert Runtime.check_write_access(build_user(), binding) == :authorized
    end

    test "forbids user from writing to read-only binding" do
      binding = build_binding(read_only: true)

      assert {:forbidden, reason} = Runtime.check_write_access(build_user(), binding)
      assert reason.reason == :forbidden
    end

    test "forbids unauthenticated user" do
      binding = build_binding()
      assert {:forbidden, _} = Runtime.check_write_access(nil, binding)
    end
  end

  describe "extract_user/1" do
    test "extracts user from socket assigns" do
      user = build_user()
      socket = build_socket(current_user: user)
      assert {:ok, ^user} = Runtime.extract_user(socket)
    end

    test "returns error when no user in assigns" do
      socket = build_socket(%{})
      assert {:error, :no_user} = Runtime.extract_user(socket)
    end

    test "returns error when current_user is nil" do
      socket = build_socket(current_user: nil)
      assert {:error, :no_user} = Runtime.extract_user(socket)
    end
  end

  describe "policy caching" do
    setup do
      Runtime.init_cache()
      :ok
    end

    test "caches and retrieves policy check result" do
      user = build_user()
      screen = build_screen()

      Runtime.cache_policy_check(user, screen, :mount, :authorized)
      assert {:ok, :authorized} = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "returns miss for uncached policy" do
      user = build_user()
      screen = build_screen()

      assert :miss = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "invalidates user cache" do
      user = build_user()
      screen = build_screen()

      Runtime.cache_policy_check(user, screen, :mount, :authorized)
      Runtime.invalidate_user_cache(user.id)

      assert :miss = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "invalidates resource cache" do
      user = build_user()
      screen = build_screen()

      Runtime.cache_policy_check(user, screen, :mount, :authorized)
      Runtime.invalidate_resource_cache(screen)

      assert :miss = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "builds unique cache keys" do
      user1 = build_user("user-1")
      user2 = build_user("user-2")
      screen = build_screen()

      Runtime.cache_policy_check(user1, screen, :mount, :authorized)
      Runtime.cache_policy_check(user2, screen, :mount, {:forbidden, %{}})

      assert {:ok, :authorized} = Runtime.get_cached_policy(user1, screen, :mount)
      assert {:ok, {:forbidden, _}} = Runtime.get_cached_policy(user2, screen, :mount)
    end

    test "handles nil user in cache key" do
      screen = build_screen()

      Runtime.cache_policy_check(nil, screen, :mount, {:forbidden, %{}})

      assert {:ok, {:forbidden, _}} = Runtime.get_cached_policy(nil, screen, :mount)
    end
  end

  describe "init_cache/0" do
    test "initializes cache table" do
      :ets.delete(:ash_ui_auth_cache)

      assert :ok = Runtime.init_cache()

      # Table should exist now
      assert :ets.whereis(:ash_ui_auth_cache) != :undefined
    end

    test "handles existing table" do
      Runtime.init_cache()

      # Should not crash if table already exists
      assert :ok = Runtime.init_cache()
    end
  end

  describe "emit_auth_telemetry/2" do
    test "emits telemetry events" do
      :telemetry.attach(
        "auth-test-handler",
        [:ash_ui, :auth, :mount_attempt],
        fn _, measurements, metadata, _ ->
          send(self(), {:auth_telemetry, measurements, metadata})
        end,
        :ok
      )

      user = build_user()
      screen = build_screen()
      context = Runtime.build_context(user, :mount, screen, %{})

      Runtime.emit_auth_telemetry(:mount_attempt, context)

      assert_receive {:auth_telemetry, _measurements, metadata}
      assert metadata.user_id == "user-1"
      assert metadata.action == :mount

      :telemetry.detach("auth-test-handler")
    end
  end
end
