defmodule AshUI.Signal.StructTest do
  use ExUnit.Case, async: true

  alias AshUI.Signal.Struct

  describe "new/1" do
    test "creates new signal with defaults" do
      signal = Struct.new()

      assert signal.id != nil
      assert signal.source == %{}
      assert signal.target == ""
      assert signal.type == :bidirectional
      assert signal.metadata == %{}
    end

    test "creates signal with custom options" do
      signal = Struct.new(
        id: "custom-id",
        source: %{"type" => "field", "resource" => "User"},
        target: "input-1",
        type: :collection
      )

      assert signal.id == "custom-id"
      assert signal.target == "input-1"
      assert signal.type == :collection
    end
  end

  describe "bidirectional/2" do
    test "creates bidirectional signal from path" do
      signal = Struct.bidirectional("User.name", "name-input")

      assert signal.type == :bidirectional
      assert signal.target == "name-input"
      assert signal.source["resource"] == "User"
      assert signal.source["field"] == "name"
    end
  end

  describe "collection/2" do
    test "creates collection signal from path" do
      signal = Struct.collection("Post.comments", "comments-list")

      assert signal.type == :collection
      assert signal.target == "comments-list"
      assert signal.source["relationship"] == "comments"
    end
  end

  describe "event/2" do
    test "creates event signal from path" do
      signal = Struct.event("User.delete", "delete-button")

      assert signal.type == :event
      assert signal.target == "delete-button"
      assert signal.source["action"] == "delete"
    end
  end

  describe "validate/1" do
    test "validates valid signal" do
      signal = Struct.bidirectional("User.name", "input")

      assert :ok = Struct.validate(signal)
    end

    test "returns errors for invalid signal" do
      # Missing id
      signal = %Struct{id: "", target: "test", type: :bidirectional, source: %{}}

      assert {:error, errors} = Struct.validate(signal)
      assert length(errors) > 0
    end

    test "validates signal type" do
      signal = %Struct{id: "test", target: "test", type: :invalid, source: %{}}

      assert {:error, errors} = Struct.validate(signal)
      assert Enum.any?(errors, &(&1 =~ "type must be"))
    end
  end
end
