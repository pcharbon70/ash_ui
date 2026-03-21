defmodule AshUI.Authorization.ResourceAuthorizerTest do
  use AshUI.DataCase, async: false

  alias AshUI.Domain
  alias AshUI.LiveView.Integration
  alias AshUI.Resources.Binding
  alias AshUI.Resources.Element
  alias AshUI.Resources.Screen

  defp build_admin(id \\ "admin-1"), do: %{id: id, role: :admin, active: true}
  defp build_user(id), do: %{id: id, role: :user, active: true}

  defp assert_forbidden(result) do
    assert {:error, %Ash.Error.Forbidden{}} = result
  end

  test "screen mount authorization enforces owner metadata" do
    {:ok, screen} =
      Ash.create(
        Screen,
        %{
          name: "screen-#{System.unique_integer([:positive])}",
          unified_dsl: %{"type" => "screen"},
          metadata: %{"owner_id" => "owner-1", "public" => false}
        }, domain: Domain)

    assert :ok = Integration.authorize_screen(screen, build_user("owner-1"))

    assert {:error, :unauthorized} =
             Integration.authorize_screen(screen, build_user("other-user"))

    assert :ok = Integration.authorize_screen(screen, build_admin())
  end

  test "element updates are enforced by resource policy" do
    {:ok, element} =
      Ash.create(
        Element,
        %{
          type: :text,
          props: %{"content" => "Restricted"},
          metadata: %{"owner_id" => "owner-1"}
        }, domain: Domain)

    assert {:ok, updated} =
             Ash.update(element, %{position: 1},
               actor: build_user("owner-1"),
               authorize?: true,
               domain: Domain
             )

    assert updated.position == 1

    assert_forbidden(
      Ash.update(element, %{position: 2},
        actor: build_user("other-user"),
        authorize?: true,
        domain: Domain
      )
    )

    assert {:ok, admin_updated} =
             Ash.update(element, %{position: 3},
               actor: build_admin(),
               authorize?: true,
               domain: Domain
             )

    assert admin_updated.position == 3
  end

  test "binding updates are enforced by resource policy" do
    {:ok, binding} =
      Ash.create(
        Binding,
        %{
          source: %{"resource" => "User", "field" => "name"},
          target: "profile.name",
          binding_type: :value,
          metadata: %{"owner_id" => "owner-1"}
        }, domain: Domain)

    assert {:ok, updated} =
             Ash.update(binding, %{target: "profile.display_name"},
               actor: build_user("owner-1"),
               authorize?: true,
               domain: Domain
             )

    assert updated.target == "profile.display_name"

    assert_forbidden(
      Ash.update(binding, %{target: "profile.nickname"},
        actor: build_user("other-user"),
        authorize?: true,
        domain: Domain
      )
    )

    assert {:ok, admin_updated} =
             Ash.update(binding, %{target: "profile.admin_name"},
               actor: build_admin(),
               authorize?: true,
               domain: Domain
             )

    assert admin_updated.target == "profile.admin_name"
  end
end
