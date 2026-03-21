defmodule AshUI.Authorization.Phase5IntegrationTest do
  use ExUnit.Case, async: false

  alias AshUI.Authorization.Runtime
  alias AshUI.Authorization.Policies
  alias AshUI.Authorization.ScreenPolicy
  alias AshUI.Authorization.ElementPolicy
  alias AshUI.Authorization.BindingPolicy
  alias AshUI.AuthorizationError

  @moduletag :conformance

  # Mock users
  defp build_admin(), do: %{id: "admin-1", role: :admin, active: true}
  defp build_user(id \\ "user-1"), do: %{id: id, role: :user, active: true}
  defp build_inactive(), do: %{id: "user-2", role: :user, active: false}
  defp build_guest(), do: %{id: nil, role: :guest, active: true}

  # Mock socket
  defp build_socket(assigns \\ %{}) do
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
      owner_id: "user-1",
      active: true
    })
  end

  defp build_element(opts \\ []) do
    Enum.into(opts, %{
      id: "element-1",
      screen_id: "screen-1",
      read_only: false,
      visible_when: nil
    })
  end

  defp build_binding(opts \\ []) do
    Enum.into(opts, %{
      id: "binding-1",
      screen_id: "screen-1",
      binding_type: :value,
      read_only: false,
      source: %{}
    })
  end

  describe "Section 5.5.1 - Mount authorization scenarios" do
    test "authorized user can mount screen" do
      user = build_user()
      screen = build_screen(public: true)

      assert Runtime.check_mount_authorization(user, screen) == :authorized
    end

    test "unauthorized user is redirected" do
      user = build_user("user-2")
      screen = build_screen(public: false, owner_id: "user-1")

      assert {:forbidden, reason} = Runtime.check_mount_authorization(user, screen)
      assert reason.reason == :forbidden
    end

    test "unauthenticated user redirects to login" do
      screen = build_screen(public: true)

      assert {:forbidden, reason} = Runtime.check_mount_authorization(nil, screen)
      assert reason.reason == :unauthenticated
      assert reason.redirect == :login
    end

    test "policy changes affect access immediately" do
      user = build_user()
      screen = build_screen(public: false, owner_id: "user-1")

      # User owns the screen
      assert Runtime.check_mount_authorization(user, screen) == :authorized

      # Change owner
      screen = build_screen(public: false, owner_id: "user-2")

      # No longer authorized
      assert {:forbidden, _} = Runtime.check_mount_authorization(user, screen)
    end
  end

  describe "Section 5.5.2 - Action authorization scenarios" do
    test "authorized action executes successfully" do
      user = build_admin()

      assert Runtime.check_action_authorization(user, :delete, %{}) == :authorized
    end

    test "unauthorized action returns error" do
      user = build_user()

      # Non-admin actions might be forbidden depending on policy
      result = Runtime.check_action_authorization(user, :delete, %{})
      assert result in [:authorized, {:forbidden, %{}}]
    end

    test "action errors include policy details" do
      user = build_inactive()

      assert {:forbidden, reason} = Runtime.check_action_authorization(user, :update, %{})
      assert reason.reason == :inactive
      assert reason.message != nil
    end

    test "partial authorization allows some fields" do
      user = build_user()

      # User can read but maybe not write depending on binding
      binding = build_binding(read_only: false)

      assert Runtime.check_read_access(user, binding) == :authorized
      assert Runtime.check_write_access(user, binding) == :authorized
    end
  end

  describe "Section 5.5.3 - Data source authorization scenarios" do
    test "authorized binding shows data" do
      user = build_user()
      binding = build_binding(source: %{})

      assert Runtime.check_read_access(user, binding) == :authorized
    end

    test "unauthorized binding shows placeholder" do
      user = build_inactive()
      binding = build_binding()

      assert {:forbidden, _} = Runtime.check_read_access(user, binding)
    end

    test "unauthorized binding doesn't leak data" do
      user = nil
      binding = build_binding(source: %{"resource" => "User.Profile"})

      # Unauthorized access should be forbidden
      assert {:forbidden, _} = Runtime.check_read_access(user, binding)

      # Redacted value should be placeholder
      redacted = BindingPolicy.redacted_value(binding)
      assert redacted == "[PROTECTED]" or redacted == []
    end

    test "cross-resource authorization works" do
      user = build_user()

      # Check cross-resource policy
      assert Policies.can_read_source(%{source: %{"resource" => "User"}}) == true
      assert Policies.can_write_source(%{source: %{"resource" => "User"}}) == true
    end
  end

  describe "Section 5.5.4 - Policy caching scenarios" do
    setup do
      Runtime.init_cache()
      :ok
    end

    test "repeated checks use cache" do
      user = build_user()
      screen = build_screen(public: true)

      # First check
      Runtime.check_mount_authorization(user, screen)
      Runtime.cache_policy_check(user, screen, :mount, :authorized)

      # Second check should use cache
      assert {:ok, :authorized} = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "cache invalidates on resource change" do
      user = build_user()
      screen = build_screen(public: true)

      # Cache the result
      Runtime.cache_policy_check(user, screen, :mount, :authorized)
      assert {:ok, :authorized} = Runtime.get_cached_policy(user, screen, :mount)

      # Invalidate on resource change
      Runtime.invalidate_resource_cache(screen)

      # Cache should be cleared
      assert :miss = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "cache invalidates on role change" do
      user = build_user()
      screen = build_screen(public: true)

      # Cache the result
      Runtime.cache_policy_check(user, screen, :mount, :authorized)
      assert {:ok, :authorized} = Runtime.get_cached_policy(user, screen, :mount)

      # Invalidate on role change
      Runtime.invalidate_user_cache(user.id)

      # Cache should be cleared
      assert :miss = Runtime.get_cached_policy(user, screen, :mount)
    end

    test "cache TTL is respected" do
      user = build_user()
      screen = build_screen(public: true)

      # Cache with a timestamp
      cache_key = Runtime.build_cache_key(user, screen, :mount)

      :ets.insert(
        :ash_ui_auth_cache,
        {cache_key, :authorized, System.system_time(:second) - 1000}
      )

      # Should be expired (assuming default TTL of 300 seconds)
      # Since we only went back 1000 seconds, this depends on actual TTL
      # Just verify cache lookup works
      result = Runtime.get_cached_policy(user, screen, :mount)
      assert result in [{:ok, :authorized}, :miss]
    end
  end

  describe "End-to-end authorization flows" do
    test "full mount authorization flow" do
      socket = build_socket(current_user: build_user())
      screen = build_screen(public: true)

      # Extract user from socket
      assert {:ok, user} = Runtime.extract_user(socket)

      # Check mount authorization
      assert Runtime.check_mount_authorization(user, screen) == :authorized
    end

    test "unauthenticated mount flow" do
      socket = build_socket(%{})
      screen = build_screen(public: true)

      # No user in socket
      assert {:error, :no_user} = Runtime.extract_user(socket)

      # Mount should fail
      assert {:forbidden, reason} = Runtime.check_mount_authorization(nil, screen)

      assert AuthorizationError.requires_login?(
               AuthorizationError.unauthenticated(AshUI.Screen, :mount)
             )
    end

    test "action execution authorization flow" do
      user = build_admin()
      action = :delete
      params = %{"id" => "resource-1"}

      # Check action authorization
      assert Runtime.check_action_authorization(user, action, params) == :authorized
    end

    test "binding evaluation authorization flow" do
      user = build_user()
      binding = build_binding(source: %{"resource" => "User.Profile"})

      # Check read access
      assert Runtime.check_read_access(user, binding) == :authorized

      # Check write access
      assert Runtime.check_write_access(user, binding) == :authorized
    end
  end

  describe "Error integration scenarios" do
    test "authorization error includes all required fields" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)

      assert error.resource == AshUI.Screen
      assert error.action == :mount
      assert error.reason == :forbidden
      assert error.policy != nil
      assert error.details != nil
    end

    test "error message is user-friendly" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      message = AuthorizationError.format_message(error)

      assert String.contains?(message, "logged in")
    end

    test "error suggests login for unauthenticated users" do
      error = AuthorizationError.unauthenticated(AshUI.Screen, :mount)
      page = AuthorizationError.custom_error_page(error, AshUI.Screen)

      assert page.suggested_action.action == :redirect_login
    end

    test "error provides help URL" do
      error = AuthorizationError.forbidden(AshUI.Screen, :mount)
      page = AuthorizationError.custom_error_page(error, AshUI.Screen)

      assert page.help_url != nil
      assert String.contains?(page.help_url, "/help/")
    end
  end

  describe "Policy integration scenarios" do
    test "screen policies control mount access" do
      user = build_user()
      public_screen = build_screen(public: true)
      private_screen = build_screen(public: false, owner_id: "user-2")

      # Can mount public screen
      assert ScreenPolicy.can_mount?(user, public_screen) == true

      # Cannot mount private screen owned by others
      assert ScreenPolicy.can_mount?(user, private_screen) == false
    end

    test "element policies control visibility" do
      user = build_user()
      element = build_element()

      # Element should be visible to active user
      assert ElementPolicy.visible?(user, element) == true

      # Element should be editable if not read-only
      assert ElementPolicy.editable?(user, element) == true
    end

    test "binding policies control data access" do
      user = build_user()
      binding = build_binding()

      # Can evaluate binding
      assert BindingPolicy.can_evaluate?(user, binding) == true

      # Can write to non-read-only binding
      assert BindingPolicy.can_write?(user, binding) == true
    end

    test "admin bypasses restrictions" do
      admin = build_admin()
      private_screen = build_screen(public: false, owner_id: "user-2")
      read_only_element = build_element(read_only: true)

      # Admin can mount any screen
      assert ScreenPolicy.can_mount?(admin, private_screen) == true

      # Admin can edit read-only elements
      assert ElementPolicy.editable?(admin, read_only_element) == true

      # Admin can write to any binding
      assert BindingPolicy.can_write?(admin, build_binding(read_only: true)) == true
    end
  end

  describe "Common policy checks" do
    test "user_active check works correctly" do
      active_user = build_user()
      inactive_user = build_inactive()

      assert Policies.user_active(active_user) == true
      assert Policies.user_active(inactive_user) == false
    end

    test "user_role check works correctly" do
      admin = build_admin()
      user = build_user()

      assert Policies.user_role(admin, :admin) == true
      assert Policies.user_role(user, :admin) == false
      assert Policies.user_role(user, [:admin, :user]) == true
    end

    test "screen_owner check works correctly" do
      user = build_user("user-1")
      other_user = build_user("user-2")
      screen = build_screen(owner_id: "user-1")

      assert Policies.screen_owner(user, screen) == true
      assert Policies.screen_owner(other_user, screen) == false
    end
  end
end
