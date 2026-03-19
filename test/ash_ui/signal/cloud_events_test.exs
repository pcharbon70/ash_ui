defmodule AshUI.Signal.CloudEventsTest do
  use ExUnit.Case, async: true

  alias AshUI.Signal.Struct
  alias AshUI.Signal.CloudEvents

  describe "to_cloud_event/1" do
    test "converts signal to CloudEvents format" do
      signal = Struct.bidirectional("User.name", "input-name")

      cloud_event = CloudEvents.to_cloud_event(signal)

      assert cloud_event["id"] == signal.id
      assert cloud_event["source"] == "ash-ui/User/name"
      assert cloud_event["type"] == "ash_ui.signal.bidirectional"
      assert cloud_event["datacontenttype"] == "application/json"
      assert is_map(cloud_event["data"])
    end

    test "includes required CloudEvents fields" do
      signal = Struct.event("Post.create", "create-btn")

      cloud_event = CloudEvents.to_cloud_event(signal)

      # Required CloudEvents fields
      assert Map.has_key?(cloud_event, "id")
      assert Map.has_key?(cloud_event, "source")
      assert Map.has_key?(cloud_event, "type")
      assert Map.has_key?(cloud_event, "datacontenttype")
      assert Map.has_key?(cloud_event, "time")
    end

    test "includes AshUI-specific metadata" do
      signal = Struct.collection("Post.comments", "comments-list")

      cloud_event = CloudEvents.to_cloud_event(signal)

      assert Map.has_key?(cloud_event, "ashui")
      assert cloud_event["ashui"]["target"] == "comments-list"
    end
  end

  describe "from_cloud_event/1" do
    test "converts CloudEvents back to signal" do
      original_signal = Struct.bidirectional("User.name", "input-name")
      cloud_event = CloudEvents.to_cloud_event(original_signal)

      assert {:ok, signal} = CloudEvents.from_cloud_event(cloud_event)
      assert signal.id == original_signal.id
      assert signal.target == original_signal.target
      assert signal.type == original_signal.type
    end

    test "returns error for invalid CloudEvents" do
      invalid_event = %{"id" => "test"}

      assert {:error, _reason} = CloudEvents.from_cloud_event(invalid_event)
    end
  end

  describe "batch/1" do
    test "wraps multiple signals in batch envelope" do
      signals = [
        Struct.bidirectional("User.name", "name"),
        Struct.collection("Post.comments", "comments"),
        Struct.event("User.delete", "delete")
      ]

      batch = CloudEvents.batch(signals)

      assert batch["type"] == "ash_ui.signal.batch"
      assert is_list(batch["data"]["events"])
      assert length(batch["data"]["events"]) == 3
    end
  end

  describe "serialize/2" do
    test "serializes signal to JSON" do
      signal = Struct.bidirectional("User.name", "input-name")

      json = CloudEvents.serialize(signal, format: :json)

      assert is_binary(json)
      assert {:ok, _decoded} = Jason.decode(json)
    end

    test "serializes CloudEvents to text format" do
      signal = Struct.event("Post.create", "btn")

      text = CloudEvents.serialize(signal, format: :text)

      assert is_binary(text)
      assert String.contains?(text, "CloudEvent")
    end
  end
end
