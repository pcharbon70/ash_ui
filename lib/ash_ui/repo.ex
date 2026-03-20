defmodule AshUI.Repo do
  @moduledoc """
  Repo for AshUI resources using AshPostgres.

  This repo manages database persistence for UI resources:
  - UI.Screen
  - UI.Element
  - UI.Binding
  """

  use AshPostgres.Repo,
    otp_app: :ash_ui,
    warn_on_missing_ash_functions?: false

  @doc """
  Returns the PostgreSQL extensions expected by the Ash UI repo.
  """
  def installed_extensions do
    # Add any Postgres extensions you need here
    ["uuid-ossp", "pg_trgm"]
  end

  @doc """
  Returns the minimum supported PostgreSQL version for this repo.
  """
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
