defmodule AshUI.Notifications do
  @moduledoc """
  PubSub bridge for Ash resource notifications used by LiveView reactivity.

  Resources publish Ash notifications through `Ash.Notifier.PubSub` to the
  local `AshUI.PubSub` server, and runtime integrations subscribe to the
  per-resource change topics exposed here.
  """

  @doc """
  Broadcasts a notification payload on the given topic and event.
  """
  @spec broadcast(String.t(), String.t(), term()) :: :ok | {:error, term()}
  def broadcast(topic, _event, payload) do
    Phoenix.PubSub.broadcast(AshUI.PubSub, topic, payload)
  end

  @doc """
  Subscribes the current process to change notifications for a resource.
  """
  @spec subscribe(module()) :: :ok
  def subscribe(resource) do
    case resource_topic(resource) do
      {:ok, topic} -> Phoenix.PubSub.subscribe(AshUI.PubSub, topic)
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Unsubscribes the current process from change notifications for a resource.
  """
  @spec unsubscribe(module()) :: :ok
  def unsubscribe(resource) do
    case resource_topic(resource) do
      {:ok, topic} -> Phoenix.PubSub.unsubscribe(AshUI.PubSub, topic)
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Returns the resource change topic for an Ash resource module.
  """
  @spec resource_topic(module()) :: {:ok, String.t()} | {:error, :unsupported_resource}
  def resource_topic(resource) when is_atom(resource) do
    resource
    |> resource_path()
    |> case do
      nil -> {:error, :unsupported_resource}
      path -> {:ok, "ash_ui:resource:#{path}:changes"}
    end
  end

  def resource_topic(_resource), do: {:error, :unsupported_resource}

  defp resource_path(resource) do
    resource
    |> Atom.to_string()
    |> String.trim_leading("Elixir.")
    |> case do
      "" -> nil
      name -> String.replace(name, ".", ":")
    end
  rescue
    _ -> nil
  end
end
