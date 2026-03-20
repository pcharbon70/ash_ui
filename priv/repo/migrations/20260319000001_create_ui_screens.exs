defmodule Repo.Migrations.CreateUiScreens do
  use Ecto.Migration

  def change do
    create table(:ui_screens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :unified_dsl, :map, default: "{}"
      add :layout, :string, default: "default"
      add :route, :string
      add :metadata, :map, default: "{}"
      add :version, :integer, default: 1, null: false
      add :inserted_at, :utc_datetime_usec
      add :updated_at, :utc_datetime_usec

      add :active, :boolean, default: true
    end

    create unique_index(:ui_screens, [:name])
  end
end
