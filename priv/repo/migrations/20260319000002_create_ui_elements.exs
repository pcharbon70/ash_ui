defmodule Repo.Migrations.CreateUiElements do
  use Ecto.Migration

  def change do
    create table(:ui_elements, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :type, :string, null: false
      add :props, :map, default: "{}"
      add :variants, {:array, :string}, default: []
      add :position, :integer, default: 0
      add :screen_id, :uuid
      add :metadata, :map, default: "{}"
      add :inserted_at, :utc_datetime_usec
      add :updated_at, :utc_datetime_usec

      add :active, :boolean, default: true
    end

    create index(:ui_elements, [:screen_id])
  end
end
