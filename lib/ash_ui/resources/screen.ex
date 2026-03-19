defmodule AshUI.Resources.Screen do
  @moduledoc """
  Ash Resource for storing unified-ui screen definitions.
  """
  use Ash.Resource,
    domain: AshUI.Domain,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :unified_dsl, :map, default: %{}
    attribute :layout, :atom, default: :default
    attribute :route, :string
    attribute :metadata, :map, default: %{}
    attribute :version, :integer, default: 1
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :elements, AshUI.Resources.Element
    has_many :bindings, AshUI.Resources.Binding
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  policies do
    policy action(:read) do
      authorize_if expr(active == true)
    end
  end
end
