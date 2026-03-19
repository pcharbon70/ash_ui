defmodule AshUI.Resources.Binding do
  @moduledoc """
  Ash Resource for data binding definitions.

  Bindings connect UI elements to Ash resource data.
  """
  use Ash.Resource,
    domain: AshUI.Domain,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :source, :string, allow_nil?: false
    attribute :target, :string, allow_nil?: false
    attribute :binding_type, :atom, constraints: [one_of: [:value, :list, :action]]
    attribute :transform, :map, default: %{}
    attribute :element_id, :uuid
    attribute :screen_id, :uuid
    attribute :metadata, :map, default: %{}
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :element, AshUI.Resources.Element
    belongs_to :screen, AshUI.Resources.Screen
  end

  actions do
    defaults [:create, :update, :destroy]

    read :read_with_filter do
      argument :filter, :map, default: %{}
      filter expr(active == true)
    end
  end

  # Note: Policy DSL requires Ash.Policy.Authorizer extension
  # This will be added when authorization policies are fully implemented
  # policies do
  #   policy action(:read) do
  #     authorize_if expr(active == true)
  #   end
  # end
end
