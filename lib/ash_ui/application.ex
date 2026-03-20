defmodule AshUI.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AshUI.Repo,
      AshUI.Rendering.Registry
    ]

    opts = [strategy: :one_for_one, name: AshUI.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
