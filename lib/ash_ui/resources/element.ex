defmodule AshUI.Resources.Element do
  @moduledoc """
  Ash Resource for storing unified-ui element definitions.

  Elements are atomic UI components (widgets) like buttons, inputs, text, etc.
  """
  use Ash.Resource,
    domain: AshUI.Domain,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :type, :atom, allow_nil?: false
    attribute :props, :map, default: %{}
    attribute :variants, {:array, :atom}, default: []
    attribute :position, :integer, default: 0
    attribute :screen_id, :uuid
    attribute :metadata, :map, default: %{}
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :screen, AshUI.Resources.Screen
    has_many :bindings, AshUI.Resources.Binding
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  # Note: Policy DSL requires Ash.Policy.Authorizer extension
  # This will be added when authorization policies are fully implemented
  # policies do
  #   policy action(:read) do
  #     authorize_if expr(active == true)
  #   end
  # end
end
