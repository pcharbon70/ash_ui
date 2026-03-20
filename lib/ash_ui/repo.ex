defmodule AshUI.Repo do
  @moduledoc """
  Repo for AshUI resources using AshPostgres.

  This repo manages database persistence for UI resources:
  - UI.Screen
  - UI.Element
  - UI.Binding
  """

  use AshPostgres.Repo,
    otp_app: :ash_ui

  @doc """
  Returns the PostgreSQL extensions expected by the Ash UI repo.
  """
  def installed_extensions do
    # Add any Postgres extensions you need here
    ["uuid-ossp", "pg_trgm"]
  end
end
