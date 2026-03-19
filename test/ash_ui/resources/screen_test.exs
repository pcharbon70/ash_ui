defmodule AshUI.Resources.ScreenTest do
  use AshUI.DataCase, async: false

  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  describe "Screen CRUD operations" do
    test "create/1 creates a screen with unified_dsl storage" do
      attrs = %{
        name: "test_screen",
        unified_dsl: %{
          "type" => "screen",
          "root" => %{"type" => "row"}
        },
        layout: :row,
        route: "/test"
      }

      assert {:ok, screen} = AshUI.Domain.create(Screen, attrs: attrs)
      assert screen.name == "test_screen"
      assert screen.layout == :row
      assert screen.route == "/test"
      assert is_map(screen.unified_dsl)
      assert screen.version == 1
      assert screen.active == true
    end

    test "read/2 lists all screens" do
      # Create test screens
      Enum.each(["screen_a", "screen_b"], fn name ->
        attrs = %{
          name: name,
          unified_dsl: %{"type" => "screen"},
          layout: :row
        }

        AshUI.Domain.create(Screen, attrs: attrs)
      end)

      screens = AshUI.Domain.read!(Screen)
      assert length(screens) >= 2
    end

    test "update/2 updates screen attributes" do
      attrs = %{
        name: "update_test",
        unified_dsl: %{"type" => "screen"},
        layout: :column
      }

      {:ok, screen} = AshUI.Domain.create(Screen, attrs: attrs)
      {:ok, updated} = AshUI.Domain.update(screen, attrs: %{layout: :grid})

      assert updated.layout == :grid
      assert updated.version == 2
    end

    test "destroy/1 deletes a screen" do
      attrs = %{
        name: "destroy_test",
        unified_dsl: %{"type" => "screen"},
        layout: :row
      }

      {:ok, screen} = AshUI.Domain.create(Screen, attrs: attrs)
      assert {:ok, _} = AshUI.Domain.destroy(screen)

      assert [] = AshUI.Domain.read!(Screen, filter: [name: "destroy_test"])
    end
  end

  describe "Screen name uniqueness" do
    test "prevents duplicate screen names" do
      attrs = %{
        name: "unique_test",
        unified_dsl: %{"type" => "screen"},
        layout: :row
      }

      {:ok, _screen} = AshUI.Domain.create(Screen, attrs: attrs)

      assert {:error, error} = AshUI.Domain.create(Screen, attrs: attrs)
      assert {:name, _} = hd(Ash.Error.errors(error))
    end
  end
end
