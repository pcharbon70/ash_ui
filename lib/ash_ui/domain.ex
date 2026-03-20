defmodule AshUI.Domain do
  @moduledoc """
  AshUI domain containing all Ash UI resources.

  This domain defines the authorization and resource boundaries for the Ash UI system.
  """
  use Ash.Domain
  require Ash.Query

  resources do
    resource AshUI.Resources.Screen
    resource AshUI.Resources.Element
    resource AshUI.Resources.Binding
  end

  @doc false
  def create(resource, opts) when is_atom(resource) and is_list(opts) do
    case Keyword.fetch(opts, :attrs) do
      {:ok, attrs} ->
        opts = opts |> Keyword.delete(:attrs) |> Keyword.put(:domain, __MODULE__)
        Ash.create(resource, attrs, opts)

      :error ->
        Ash.create(resource, Keyword.put(opts, :domain, __MODULE__))
    end
  end

  @doc false
  def update(record, opts) when is_list(opts) do
    case Keyword.fetch(opts, :attrs) do
      {:ok, attrs} ->
        opts = opts |> Keyword.delete(:attrs) |> Keyword.put(:domain, __MODULE__)
        Ash.update(record, attrs, opts)

      :error ->
        Ash.update(record, Keyword.put(opts, :domain, __MODULE__))
    end
  end

  @doc false
  def read(resource, opts) when is_atom(resource) and is_list(opts) do
    {filter, opts} = Keyword.pop(opts, :filter)
    query = apply_filter(resource, filter)

    Ash.read(query, Keyword.put(opts, :domain, __MODULE__))
  end

  @doc false
  def read!(resource, opts) when is_atom(resource) and is_list(opts) do
    {filter, opts} = Keyword.pop(opts, :filter)
    query = apply_filter(resource, filter)

    Ash.read!(query, Keyword.put(opts, :domain, __MODULE__))
  end

  @doc false
  def read_one(resource, opts) when is_atom(resource) and is_list(opts) do
    {filter, opts} = Keyword.pop(opts, :filter)
    query = apply_filter(resource, filter)

    Ash.read_one(query, Keyword.put(opts, :domain, __MODULE__))
  end

  @doc false
  def read_one!(resource, opts) when is_atom(resource) and is_list(opts) do
    {filter, opts} = Keyword.pop(opts, :filter)
    query = apply_filter(resource, filter)

    Ash.read_one!(query, Keyword.put(opts, :domain, __MODULE__))
  end

  defp apply_filter(resource, nil), do: resource

  defp apply_filter(resource, filter) do
    resource
    |> Ash.Query.new()
    |> Ash.Query.filter(^filter)
  end
end
