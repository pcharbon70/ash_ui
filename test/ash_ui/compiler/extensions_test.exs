defmodule AshUI.Compiler.ExtensionsTest do
  use ExUnit.Case, async: true

  alias AshUI.Compiler.Extensions

  describe "register_widget/2" do
    setup do
      Extensions.init()
    end

    test "registers a custom widget" do
      definition = %{
        module: TestWidget,
        props: [%{name: :value, type: :string, required: true}],
        validate: fn _props -> :ok end,
        compile: fn props -> %{type: "test_widget", props: props} end
      }

      assert :ok = Extensions.register_widget("custom:test", definition)
    end

    test "returns error for invalid definition" do
      definition = %{
        module: TestWidget
        # Missing required keys
      }

      assert {:error, _reason} = Extensions.register_widget("custom:invalid", definition)
    end
  end

  describe "register_layout/2" do
    setup do
      Extensions.init()
    end

    test "registers a custom layout" do
      definition = %{
        module: TestLayout,
        props: [%{name: :columns, type: :integer, default: 3}],
        validate: fn _props -> :ok end,
        compile: fn props, children -> %{type: "test_layout", props: props, children: children} end
      }

      assert :ok = Extensions.register_layout("custom:test", definition)
    end
  end

  describe "registered_widgets/0" do
    setup do
      Extensions.init()
    end

    test "returns empty list when no widgets registered" do
      assert Extensions.registered_widgets() == []
    end

    test "returns list of registered widgets" do
      definition = %{
        module: TestWidget,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _ -> %{} end
      }

      Extensions.register_widget("custom:test1", definition)
      Extensions.register_widget("custom:test2", definition)

      widgets = Extensions.registered_widgets()
      assert length(widgets) == 2
    end
  end

  describe "registered_layouts/0" do
    setup do
      Extensions.init()
    end

    test "returns empty list when no layouts registered" do
      assert Extensions.registered_layouts() == []
    end
  end

  describe "get_widget/1" do
    setup do
      Extensions.init()

      definition = %{
        module: TestWidget,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _ -> %{} end
      }

      Extensions.register_widget("custom:lookup", definition)
    end

    test "returns registered widget" do
      assert {:ok, widget} = Extensions.get_widget("custom:lookup")
      assert widget.module == TestWidget
    end

    test "returns error for unregistered widget" do
      assert {:error, :not_found} = Extensions.get_widget("custom:nonexistent")
    end
  end

  describe "get_layout/1" do
    setup do
      Extensions.init()

      definition = %{
        module: TestLayout,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _, _ -> %{} end
      }

      Extensions.register_layout("custom:layout_lookup", definition)
    end

    test "returns registered layout" do
      assert {:ok, layout} = Extensions.get_layout("custom:layout_lookup")
      assert layout.module == TestLayout
    end

    test "returns error for unregistered layout" do
      assert {:error, :not_found} = Extensions.get_layout("custom:nonexistent")
    end
  end

  describe "widget_registered?/1" do
    setup do
      Extensions.init()
    end

    test "returns true for registered widget" do
      definition = %{
        module: TestWidget,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _ -> %{} end
      }

      Extensions.register_widget("custom:registered", definition)

      assert Extensions.widget_registered?("custom:registered") == true
    end

    test "returns false for unregistered widget" do
      assert Extensions.widget_registered?("custom:unregistered") == false
    end
  end

  describe "layout_registered?/1" do
    setup do
      Extensions.init()
    end

    test "returns true for registered layout" do
      definition = %{
        module: TestLayout,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _, _ -> %{} end
      }

      Extensions.register_layout("custom:layout_registered", definition)

      assert Extensions.layout_registered?("custom:layout_registered") == true
    end
  end

  describe "compile_widget/2" do
    setup do
      Extensions.init()

      definition = %{
        module: TestWidget,
        props: [
          %{name: :value, type: :string, required: false}
        ],
        validate: fn props ->
          if Map.has_key?(props, :value), do: :ok, else: {:error, :missing_value}
        end,
        compile: fn props -> %{type: "test_widget", value: Map.get(props, :value)} end
      }

      Extensions.register_widget("custom:compile", definition)
    end

    test "compiles widget with valid props" do
      props = %{value: "test"}

      assert {:ok, compiled} = Extensions.compile_widget("custom:compile", props)
      assert compiled.type == "test_widget"
    end

    test "returns error for invalid props" do
      props = %{} # Missing required value

      assert {:error, _reason} = Extensions.compile_widget("custom:compile", props)
    end

    test "returns error for unregistered widget" do
      assert {:error, :not_found} = Extensions.compile_widget("custom:unknown", %{})
    end
  end

  describe "compile_layout/2" do
    setup do
      Extensions.init()

      definition = %{
        module: TestLayout,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn props, children -> %{type: "test_layout", props: props, children: children} end
      }

      Extensions.register_layout("custom:compile_layout", definition)
    end

    test "compiles layout with children" do
      props = %{}
      children = [%{type: "text"}]

      assert {:ok, compiled} = Extensions.compile_layout("custom:compile_layout", props, children)
      assert compiled.type == "test_layout"
    end
  end

  describe "unregister_widget/1" do
    setup do
      Extensions.init()

      definition = %{
        module: TestWidget,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _ -> %{} end
      }

      Extensions.register_widget("custom:unregister", definition)
    end

    test "removes registered widget" do
      assert Extensions.widget_registered?("custom:unregister") == true
      Extensions.unregister_widget("custom:unregister")
      assert Extensions.widget_registered?("custom:unregister") == false
    end
  end

  describe "unregister_layout/1" do
    setup do
      Extensions.init()

      definition = %{
        module: TestLayout,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _, _ -> %{} end
      }

      Extensions.register_layout("custom:unregister_layout", definition)
    end

    test "removes registered layout" do
      assert Extensions.layout_registered?("custom:unregister_layout") == true
      Extensions.unregister_layout("custom:unregister_layout")
      assert Extensions.layout_registered?("custom:unregister_layout") == false
    end
  end

  describe "available_widget_types/0" do
    test "includes built-in widget types" do
      types = Extensions.available_widget_types()

      assert "text" in types
      assert "button" in types
      assert "input" in types
    end

    test "includes custom widget types" do
      Extensions.init()

      definition = %{
        module: TestWidget,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _ -> %{} end
      }

      Extensions.register_widget("custom:available", definition)

      types = Extensions.available_widget_types()
      assert "custom:available" in types
    end
  end

  describe "available_layout_types/0" do
    test "includes built-in layout types" do
      types = Extensions.available_layout_types()

      assert "row" in types
      assert "column" in types
      assert "grid" in types
    end

    test "includes custom layout types" do
      Extensions.init()

      definition = %{
        module: TestLayout,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _, _ -> %{} end
      }

      Extensions.register_layout("custom:available_layout", definition)

      types = Extensions.available_layout_types()
      assert "custom:available_layout" in types
    end
  end

  describe "validate_widget_spec/1" do
    setup do
      Extensions.init()
    end

    test "validates valid widget definition" do
      definition = %{
        module: TestWidget,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _ -> %{} end
      }

      assert :ok = Extensions.validate_widget_spec(definition)
    end

    test "returns errors for invalid definition" do
      definition = %{
        module: TestWidget
        # Missing keys
      }

      assert {:error, errors} = Extensions.validate_widget_spec(definition)
      assert length(errors) > 0
    end
  end

  describe "validate_layout_spec/1" do
    setup do
      Extensions.init()
    end

    test "validates valid layout definition" do
      definition = %{
        module: TestLayout,
        props: [],
        validate: fn _ -> :ok end,
        compile: fn _, _ -> %{} end
      }

      assert :ok = Extensions.validate_layout_spec(definition)
    end
  end

  describe "init/0" do
    test "initializes extension tables" do
      Extensions.init()

      # Tables should exist now
      assert Extensions.available_widget_types() != []
      assert Extensions.available_layout_types() != []
    end
  end
end
