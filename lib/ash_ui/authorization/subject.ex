defmodule AshUI.Authorization.Subject do
  @moduledoc false

  @spec to_data(term()) :: map()
  def to_data(%Ash.Changeset{} = changeset) do
    changeset
    |> base_data()
    |> Map.merge(normalize_map(changeset.arguments || %{}))
    |> Map.merge(normalize_map(changeset.attributes || %{}))
  end

  def to_data(%Ash.Query{resource: resource}), do: %{__resource__: resource}
  def to_data(%struct{} = value) when struct != Ash.Query, do: Map.from_struct(value)
  def to_data(value) when is_map(value), do: value
  def to_data(resource) when is_atom(resource), do: %{__resource__: resource}
  def to_data(_value), do: %{}

  defp base_data(%Ash.Changeset{data: nil}), do: %{}
  defp base_data(%Ash.Changeset{data: data}) when is_map(data), do: to_data(data)
  defp base_data(_changeset), do: %{}

  defp normalize_map(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      normalized_key =
        if is_atom(key) do
          key
        else
          to_string(key)
        end

      {normalized_key, value}
    end)
  end
end
