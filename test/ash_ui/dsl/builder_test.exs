defmodule AshUI.DSL.BuilderTest do
  use ExUnit.Case, async: true

  alias AshUI.DSL.Builder

  describe "root/2" do
    test "creates a root DSL element" do
      dsl = Builder.root("row")

      assert dsl.type == "row"
      assert dsl.props == %{}
      assert dsl.children == []
      assert dsl.signals == []
    end

    test "accepts custom props" do
      dsl = Builder.root("row", props: %{spacing: 16})

      assert dsl.props == %{spacing: 16}
    end

    test "accepts children" do
      child = Builder.text("Hello")
      dsl = Builder.root("row", children: [child])

      assert dsl.children == [child]
    end

    test "accepts signals" do
      signal = %{type: :bidirectional, target: "name", source: "User.name"}
      dsl = Builder.root("row", signals: [signal])

      assert dsl.signals == [signal]
    end
  end

  describe "row/1" do
    test "creates a row layout" do
      dsl = Builder.row()

      assert dsl.type == "row"
      assert dsl.props.spacing == 8
      assert dsl.props.align == :start
      assert dsl.props.justify == :start
    end

    test "accepts custom spacing" do
      dsl = Builder.row(spacing: 16)

      assert dsl.props.spacing == 16
    end

    test "accepts custom alignment" do
      dsl = Builder.row(align: :center)

      assert dsl.props.align == :center
    end

    test "accepts children" do
      child = Builder.text("Hello")
      dsl = Builder.row(children: [child])

      assert dsl.children == [child]
    end
  end

  describe "column/1" do
    test "creates a column layout" do
      dsl = Builder.column()

      assert dsl.type == "column"
      assert dsl.props.spacing == 8
    end

    test "accepts custom spacing" do
      dsl = Builder.column(spacing: 24)

      assert dsl.props.spacing == 24
    end
  end

  describe "text/2" do
    test "creates a text widget" do
      dsl = Builder.text("Hello, World!")

      assert dsl.type == "text"
      assert dsl.props.content == "Hello, World!"
      assert dsl.props.size == 14
    end

    test "accepts custom size" do
      dsl = Builder.text("Hello", size: 24)

      assert dsl.props.size == 24
    end

    test "accepts custom color" do
      dsl = Builder.text("Hello", color: "blue")

      assert dsl.props.color == "blue"
    end

    test "accepts custom weight" do
      dsl = Builder.text("Hello", weight: :bold)

      assert dsl.props.weight == :bold
    end
  end

  describe "button/2" do
    test "creates a button widget" do
      dsl = Builder.button("Click Me")

      assert dsl.type == "button"
      assert dsl.props.label == "Click Me"
      assert dsl.props.variant == :primary
    end

    test "accepts on_click action" do
      dsl = Builder.button("Save", on_click: "save_action")

      assert dsl.props.on_click == "save_action"
      assert length(dsl.signals) == 1
      assert hd(dsl.signals).action == "save_action"
    end

    test "accepts variant" do
      dsl = Builder.button("Cancel", variant: :secondary)

      assert dsl.props.variant == :secondary
    end
  end

  describe "input/2" do
    test "creates an input widget" do
      dsl = Builder.input("name")

      assert dsl.type == "input"
      assert dsl.props.name == "name"
    end

    test "accepts placeholder" do
      dsl = Builder.input("email", placeholder: "Enter email")

      assert dsl.props.placeholder == "Enter email"
    end

    test "accepts bind_to for signals" do
      dsl = Builder.input("name", bind_to: "User.name")

      assert length(dsl.signals) == 1
      signal = hd(dsl.signals)
      assert signal.type == :bidirectional
      assert signal.target == "name"
      assert signal.source == "User.name"
    end
  end

  describe "container/2" do
    test "creates a custom container" do
      dsl = Builder.container("div", padding: 16, background: "white")

      assert dsl.type == "div"
      assert dsl.props.padding == 16
      assert dsl.props.background == "white"
    end

    test "accepts children" do
      child = Builder.text("Hello")
      dsl = Builder.container("div", children: [child])

      assert dsl.children == [child]
    end
  end

  describe "add_signal/4" do
    test "adds a signal to an element" do
      element = Builder.text("Hello")
      element = Builder.add_signal(element, :bidirectional, "name", "User.name")

      assert length(element.signals) == 1
      signal = hd(element.signals)
      assert signal.type == :bidirectional
    end
  end

  describe "merge/1" do
    test "merges multiple elements into fragment" do
      elements = [
        Builder.text("Hello"),
        Builder.text("World")
      ]

      dsl = Builder.merge(elements)

      assert dsl.type == "fragment"
      assert length(dsl.children) == 2
    end
  end

  describe "validate/1" do
    test "returns :ok for valid DSL" do
      dsl = Builder.text("Hello")

      assert Builder.validate(dsl) == :ok
    end

    test "returns errors for missing type" do
      invalid = %{props: %{}, children: [], signals: []}

      assert {:error, errors} = Builder.validate(invalid)
      assert "Missing or invalid type field" in errors
    end

    test "returns errors for invalid children" do
      invalid = %{type: "text", props: %{}, children: "not a list", signals: []}

      assert {:error, errors} = Builder.validate(invalid)
      assert "Children must be a list" in errors
    end
  end
end
