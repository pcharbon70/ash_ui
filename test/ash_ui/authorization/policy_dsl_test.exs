defmodule AshUI.Authorization.PolicyDSLTest do
  use ExUnit.Case, async: true

  alias AshUI.Authorization.PolicyDSL

  # Mock users
  defp build_admin(), do: %{id: "admin-1", role: :admin, active: true}
  defp build_user(), do: %{id: "user-1", role: :user, active: true}
  defp build_inactive(), do: %{id: "user-2", role: :user, active: false}

  # Mock resources
  defp build_resource(opts \\ []) do
    Enum.into(opts, %{
      id: "resource-1",
      public: false,
      owner_id: "user-1"
    })
  end

  describe "visible_if/2" do
    test "returns true when function condition passes" do
      condition = fn user -> user.role == :admin end
      assert PolicyDSL.visible_if(build_admin(), condition) == true
    end

    test "returns false when function condition fails" do
      condition = fn user -> user.role == :admin end
      assert PolicyDSL.visible_if(build_user(), condition) == false
    end

    test "returns false for nil user" do
      condition = fn _user -> true end
      assert PolicyDSL.visible_if(nil, condition) == false
    end

    test "checks tuple condition with field and value" do
      assert PolicyDSL.visible_if(build_admin(), {:role, :admin}) == true
      assert PolicyDSL.visible_if(build_user(), {:role, :admin}) == false
    end

    test "returns boolean condition directly" do
      assert PolicyDSL.visible_if(build_user(), true) == true
      assert PolicyDSL.visible_if(build_user(), false) == false
    end
  end

  describe "editable_if/2" do
    test "returns true when function condition passes" do
      condition = fn user -> user.role == :admin end
      assert PolicyDSL.editable_if(build_admin(), condition) == true
    end

    test "returns true when user has role in list" do
      assert PolicyDSL.editable_if(build_admin(), [:admin, :editor]) == true
      assert PolicyDSL.editable_if(build_user(), [:admin, :editor]) == false
    end

    test "returns true when user has specific role" do
      assert PolicyDSL.editable_if(build_admin(), :admin) == true
      assert PolicyDSL.editable_if(build_user(), :admin) == false
    end
  end

  describe "accessible_if/2" do
    test "returns true for admin users" do
      resource = build_resource()
      assert PolicyDSL.accessible_if(build_admin(), resource) == true
    end

    test "returns true for public resources" do
      resource = build_resource(public: true)
      assert PolicyDSL.accessible_if(build_user(), resource) == true
    end

    test "returns true for resource owner" do
      resource = build_resource(owner_id: "user-1")
      assert PolicyDSL.accessible_if(build_user("user-1"), resource) == true
    end

    test "returns false for nil user" do
      resource = build_resource(public: true)
      assert PolicyDSL.accessible_if(nil, resource) == false
    end

    test "returns false for inactive user" do
      resource = build_resource(public: true)
      assert PolicyDSL.accessible_if(build_inactive(), resource) == false
    end
  end

  describe "can_read_source/1" do
    test "checks source accessibility" do
      binding = %{source: %{"resource" => "User.Profile"}}
      assert is_boolean(PolicyDSL.can_read_source(binding))
    end

    test "returns true for nil source" do
      binding = %{source: nil}
      assert PolicyDSL.can_read_source(binding) == true
    end
  end

  describe "can_write_source/1" do
    test "checks source writability" do
      binding = %{source: %{"resource" => "User.Profile", "action" => :update}}
      assert is_boolean(PolicyDSL.can_write_source(binding))
    end

    test "returns true for nil source" do
      binding = %{source: nil}
      assert PolicyDSL.can_write_source(binding) == true
    end
  end

  describe "can_access_field/2" do
    test "returns true for any field" do
      resource = %{}
      assert PolicyDSL.can_access_field(resource, :email) == true
      assert PolicyDSL.can_access_field(resource, "name") == true
    end
  end

  describe "can_execute_action/2" do
    test "returns true for any action" do
      resource = %{}
      assert PolicyDSL.can_execute_action(resource, :delete) == true
    end
  end

  describe "build_visibility_policy/1" do
    test "builds visibility policy map" do
      condition = fn user -> user.active end
      policy = PolicyDSL.build_visibility_policy(condition)

      assert policy.type == :visibility
      assert policy.condition == condition
    end
  end

  describe "build_editability_policy/1" do
    test "builds editability policy with role list" do
      policy = PolicyDSL.build_editability_policy([:admin, :editor])

      assert policy.type == :editability
      assert policy.condition == {:roles, [:admin, :editor]}
    end

    test "builds editability policy with function" do
      condition = fn user -> user.role == :admin end
      policy = PolicyDSL.build_editability_policy(condition)

      assert policy.type == :editability
      assert policy.condition == condition
    end
  end

  describe "build_access_policy/2" do
    test "builds access policy map" do
      condition = fn _user, _resource -> true end
      policy = PolicyDSL.build_access_policy(:read, condition)

      assert policy.type == :access
      assert policy.action == :read
      assert policy.condition == condition
    end
  end

  describe "all_of/1" do
    test "returns true when all policies pass" do
      combined = PolicyDSL.all_of([
        fn user -> user.active end,
        fn user -> user.role == :admin end
      ])

      assert combined.(build_admin(), build_resource()) == true
    end

    test "returns false when any policy fails" do
      combined = PolicyDSL.all_of([
        fn user -> user.active end,
        fn user -> user.role == :admin end
      ])

      assert combined.(build_user(), build_resource()) == false
    end

    test "handles 2-arity policies" do
      combined = PolicyDSL.all_of([
        fn _user, resource -> resource.public end,
        fn user -> user.active end
      ])

      assert combined.(build_user(), build_resource(public: true)) == true
      assert combined.(build_user(), build_resource(public: false)) == false
    end
  end

  describe "any_of/1" do
    test "returns true when any policy passes" do
      combined = PolicyDSL.any_of([
        fn user -> user.role == :admin end,
        fn user -> user.role == :superadmin end
      ])

      assert combined.(build_admin(), build_resource()) == true
    end

    test "returns false when all policies fail" do
      combined = PolicyDSL.any_of([
        fn user -> user.role == :superadmin end,
        fn user -> user.role == :moderator end
      ])

      assert combined.(build_user(), build_resource()) == false
    end

    test "handles boolean values" do
      combined = PolicyDSL.any_of([
        false,
        true,
        false
      ])

      assert combined.(build_user(), build_resource()) == true
    end
  end

  describe "not_/1" do
    test "negates 1-arity function" do
      not_admin = PolicyDSL.not_(& &1.role == :admin)

      assert not_admin.(build_user()) == true
      assert not_admin.(build_admin()) == false
    end

    test "negates 2-arity function" do
      not_owner = PolicyDSL.not_(fn user, resource -> user.id == resource.owner_id end)

      assert not_owner.(build_user("user-1"), build_resource(owner_id: "user-2")) == true
      assert not_owner.(build_user("user-1"), build_resource(owner_id: "user-1")) == false
    end
  end

  describe "environment_policy/1" do
    test "checks single environment" do
      result = PolicyDSL.environment_policy(:dev)
      assert is_boolean(result)
    end

    test "checks environment list" do
      result = PolicyDSL.environment_policy([:dev, :test])
      assert is_boolean(result)
    end
  end

  describe "document_policy/2" do
    test "creates policy documentation" do
      docs = PolicyDSL.document_policy(:screen_read, %{
        description: "Allows reading screens",
        checks: [:user_active]
      })

      assert docs.name == :screen_read
      assert docs.description == "Allows reading screens"
      assert docs.checks == [:user_active]
    end
  end

  describe "generate_policy_docs/1" do
    test "generates policy documentation for resource" do
      docs = PolicyDSL.generate_policy_docs(AshUI.Screen)

      assert docs.resource == AshUI.Screen
      assert is_list(docs.policies)
      assert is_list(docs.checks)
    end
  end

  describe "time_policy/2" do
    test "evaluates time-based condition" do
      policy = PolicyDSL.time_policy(10, fn hour -> hour >= 9 and hour < 17 end)
      assert policy == true
    end

    test "returns false for out of range hours" do
      policy = PolicyDSL.time_policy(20, fn hour -> hour >= 9 and hour < 17 end)
      assert policy == false
    end
  end
end
