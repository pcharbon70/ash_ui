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

  def installed_extensions do
    # Add any Postgres extensions you need here
    ["uuid-ossp", "pg_trgm"]
  end
end
