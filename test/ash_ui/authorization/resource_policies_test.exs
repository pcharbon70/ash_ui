defmodule AshUI.Authorization.ResourcePoliciesTest do
  use ExUnit.Case, async: true

  alias AshUI.Authorization.ScreenPolicy
  alias AshUI.Authorization.ElementPolicy
  alias AshUI.Authorization.BindingPolicy

  # Mock users
  defp build_admin(), do: %{id: "admin-1", role: :admin, active: true}
  defp build_user(id \\ "user-1"), do: %{id: id, role: :user, active: true}
  defp build_inactive(), do: %{id: "user-2", role: :user, active: false}
  defp build_guest(), do: %{id: nil, role: :guest, active: true}

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

  describe "ScreenPolicy.policies/0" do
    test "returns list of policies" do
      policies = ScreenPolicy.policies()
      assert is_list(policies)
      assert length(policies) > 0
    end
  end

  describe "ScreenPolicy.filter_screens/1" do
    test "returns all screens for admin" do
      filters = ScreenPolicy.filter_screens(build_admin())
      assert Keyword.get(filters, :active) == true
    end

    test "returns public and owned screens for regular user" do
      filters = ScreenPolicy.filter_screens(build_user())
      assert Keyword.get(filters, :active) == true
      assert Keyword.has_key?(filters, :or)
    end

    test "returns only public screens for guest" do
      filters = ScreenPolicy.filter_screens(build_guest())
      assert Keyword.get(filters, :active) == true
    end
  end

  describe "ScreenPolicy.can_mount?/2" do
    test "admin can mount any screen" do
      screen = build_screen(public: false, owner_id: "other-user")
      assert ScreenPolicy.can_mount?(build_admin(), screen) == true
    end

    test "user can mount public screen" do
      screen = build_screen(public: true, owner_id: "other-user")
      assert ScreenPolicy.can_mount?(build_user(), screen) == true
    end

    test "user can mount their own screen" do
      screen = build_screen(public: false, owner_id: "user-1")
      assert ScreenPolicy.can_mount?(build_user("user-1"), screen) == true
    end

    test "user cannot mount private screen owned by others" do
      screen = build_screen(public: false, owner_id: "user-2")
      assert ScreenPolicy.can_mount?(build_user("user-1"), screen) == false
    end

    test "inactive user cannot mount screen" do
      screen = build_screen(public: true)
      assert ScreenPolicy.can_mount?(build_inactive(), screen) == false
    end
  end

  describe "ElementPolicy.policies/0" do
    test "returns list of policies" do
      policies = ElementPolicy.policies()
      assert is_list(policies)
      assert length(policies) > 0
    end
  end

  describe "ElementPolicy.visible?/2" do
    test "admin sees all elements" do
      element = build_element()
      assert ElementPolicy.visible?(build_admin(), element) == true
    end

    test "active user sees element without visibility condition" do
      element = build_element()
      assert ElementPolicy.visible?(build_user(), element) == true
    end

    test "inactive user does not see element" do
      element = build_element()
      assert ElementPolicy.visible?(build_inactive(), element) == false
    end

    test "respects visibility condition function" do
      element = build_element(visible_when: fn user -> user.role == :admin end)
      assert ElementPolicy.visible?(build_admin(), element) == true
      assert ElementPolicy.visible?(build_user(), element) == false
    end

    test "respects visibility condition tuple" do
      element = build_element(visible_when: {:role, :admin})
      assert ElementPolicy.visible?(build_admin(), element) == true
      assert ElementPolicy.visible?(build_user(), element) == false
    end
  end

  describe "ElementPolicy.editable?/2" do
    test "admin can edit all elements" do
      element = build_element(read_only: false)
      assert ElementPolicy.editable?(build_admin(), element) == true
    end

    test "user can edit non-read-only element" do
      element = build_element(read_only: false)
      assert ElementPolicy.editable?(build_user(), element) == true
    end

    test "user cannot edit read-only element" do
      element = build_element(read_only: true)
      assert ElementPolicy.editable?(build_user(), element) == false
    end

    test "inactive user cannot edit element" do
      element = build_element(read_only: false)
      assert ElementPolicy.editable?(build_inactive(), element) == false
    end
  end

  describe "BindingPolicy.policies/0" do
    test "returns list of policies" do
      policies = BindingPolicy.policies()
      assert is_list(policies)
      assert length(policies) > 0
    end
  end

  describe "BindingPolicy.can_evaluate?/2" do
    test "admin can evaluate all bindings" do
      binding = build_binding()
      assert BindingPolicy.can_evaluate?(build_admin(), binding) == true
    end

    test "active user can evaluate binding without source" do
      binding = build_binding(source: nil)
      assert BindingPolicy.can_evaluate?(build_user(), binding) == true
    end

    test "inactive user cannot evaluate binding" do
      binding = build_binding()
      assert BindingPolicy.can_evaluate?(build_inactive(), binding) == false
    end
  end

  describe "BindingPolicy.can_write?/2" do
    test "admin can write to all bindings" do
      binding = build_binding(read_only: false)
      assert BindingPolicy.can_write?(build_admin(), binding) == true
    end

    test "user can write to non-read-only binding" do
      binding = build_binding(read_only: false)
      assert BindingPolicy.can_write?(build_user(), binding) == true
    end

    test "user cannot write to read-only binding" do
      binding = build_binding(read_only: true)
      assert BindingPolicy.can_write?(build_user(), binding) == false
    end

    test "inactive user cannot write to binding" do
      binding = build_binding(read_only: false)
      assert BindingPolicy.can_write?(build_inactive(), binding) == false
    end
  end

  describe "BindingPolicy.redacted_value/1" do
    test "returns protected placeholder for value bindings" do
      binding = build_binding(binding_type: :value)
      assert BindingPolicy.redacted_value(binding) == "[PROTECTED]"
    end

    test "returns empty list for list bindings" do
      binding = build_binding(binding_type: :list)
      assert BindingPolicy.redacted_value(binding) == []
    end

    test "returns nil for action bindings" do
      binding = build_binding(binding_type: :action)
      assert BindingPolicy.redacted_value(binding) == nil
    end

    test "returns nil for unknown binding types" do
      binding = build_binding(binding_type: :unknown)
      assert BindingPolicy.redacted_value(binding) == nil
    end
  end

  describe "BindingPolicy.source_accessible?/2" do
    test "returns true for binding without source" do
      binding = build_binding(source: nil)
      assert BindingPolicy.source_accessible?(build_user(), binding) == true
    end

    test "returns true for binding with empty source" do
      binding = build_binding(source: %{})
      assert BindingPolicy.source_accessible?(build_user(), binding) == true
    end

    test "checks source resource access" do
      binding = build_binding(source: %{"resource" => "User.Profile"})
      assert is_boolean(BindingPolicy.source_accessible?(build_user(), binding))
    end
  end
end
