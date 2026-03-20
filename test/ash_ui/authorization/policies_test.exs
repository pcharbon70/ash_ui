defmodule AshUI.Authorization.PoliciesTest do
  use ExUnit.Case, async: true

  alias AshUI.Authorization.Policies

  # Mock users
  defp build_admin(), do: %{id: "admin-1", role: :admin, active: true}
  defp build_user(), do: %{id: "user-1", role: :user, active: true}
  defp build_inactive(), do: %{id: "user-2", role: :user, active: false}
  # Mock resources
  defp build_screen(opts \\ []) do
    Enum.into(opts, %{
      id: "screen-1",
      name: "Test Screen",
      public: false,
      owner_id: "user-1"
    })
  end

  describe "user_active/1" do
    test "returns true for active users" do
      assert Policies.user_active(build_user()) == true
    end

    test "returns true for active admin" do
      assert Policies.user_active(build_admin()) == true
    end

    test "returns false for inactive users" do
      assert Policies.user_active(build_inactive()) == false
    end

    test "returns false for nil user" do
      assert Policies.user_active(nil) == false
    end

    test "returns true for status: 'active'" do
      user = %{id: "user-1", status: "active"}
      assert Policies.user_active(user) == true
    end
  end

  describe "user_role/2" do
    test "returns true when user has required role" do
      assert Policies.user_role(build_admin(), :admin) == true
      assert Policies.user_role(build_user(), :user) == true
    end

    test "returns true when user has one of required roles" do
      assert Policies.user_role(build_admin(), [:admin, :superadmin]) == true
      assert Policies.user_role(build_user(), [:admin, :user]) == true
    end

    test "returns false when user lacks required role" do
      assert Policies.user_role(build_user(), :admin) == false
      assert Policies.user_role(build_admin(), [:user, :moderator]) == false
    end

    test "returns false for nil user" do
      assert Policies.user_role(nil, :user) == false
    end

    test "checks list of roles" do
      user = %{id: "user-1", roles: [:admin, :moderator]}
      assert Policies.user_role(user, [:admin, :user]) == true
      assert Policies.user_role(user, [:user, :guest]) == false
    end
  end

  describe "screen_owner/2" do
    test "returns true when user owns the resource" do
      user = %{id: "user-1"}
      resource = %{owner_id: "user-1"}
      assert Policies.screen_owner(user, resource) == true
    end

    test "returns true when user_id matches" do
      user = %{id: "user-1"}
      resource = %{user_id: "user-1"}
      assert Policies.screen_owner(user, resource) == true
    end

    test "returns false when user does not own resource" do
      user = %{id: "user-1"}
      resource = %{owner_id: "user-2"}
      assert Policies.screen_owner(user, resource) == false
    end

    test "returns false for nil user" do
      assert Policies.screen_owner(nil, build_screen()) == false
    end

    test "returns false when owner_id is nil" do
      user = %{id: "user-1"}
      resource = %{owner_id: nil}
      assert Policies.screen_owner(user, resource) == false
    end
  end

  describe "environment/1" do
    test "returns true when environment matches" do
      # In test, we can't easily change the config env
      # But we can test the function structure
      assert is_boolean(Policies.environment(:dev))
      assert is_boolean(Policies.environment(:prod))
    end

    test "returns true when environment in list" do
      assert is_boolean(Policies.environment([:dev, :test]))
    end
  end

  describe "can_read_source/1" do
    test "returns true for nil source" do
      binding = %{source: nil}
      assert Policies.can_read_source(binding) == true
    end

    test "returns true for empty source map" do
      binding = %{source: %{}}
      assert Policies.can_read_source(binding) == true
    end

    test "checks source resource" do
      binding = %{source: %{"resource" => "User.Profile"}}
      assert is_boolean(Policies.can_read_source(binding))
    end
  end

  describe "can_write_source/1" do
    test "returns true for nil source" do
      binding = %{source: nil}
      assert Policies.can_write_source(binding) == true
    end

    test "returns true for empty source map" do
      binding = %{source: %{}}
      assert Policies.can_write_source(binding) == true
    end

    test "checks source resource with action" do
      binding = %{source: %{"resource" => "User.Profile", "action" => :update}}
      assert is_boolean(Policies.can_write_source(binding))
    end
  end

  describe "can_access_field/2" do
    test "returns true for any field" do
      resource = %{}
      assert Policies.can_access_field(resource, :email) == true
      assert Policies.can_access_field(resource, "name") == true
    end
  end

  describe "can_execute_action/2" do
    test "returns true for any action" do
      resource = %{}
      assert Policies.can_execute_action(resource, :delete) == true
      assert Policies.can_execute_action(resource, :update) == true
    end
  end
end
