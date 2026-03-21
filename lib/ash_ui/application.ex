defmodule AshUI.Application do
  @moduledoc """
  OTP application entry point for Ash UI.

  Starts the repo and runtime services required by the framework.
  """

  use Application

  @impl true
  @doc """
  Starts the Ash UI supervision tree.
  """
  def start(_type, _args) do
    AshUI.Compiler.init_cache()
    AshUI.Authorization.Runtime.init_cache()

    children = [
      {Phoenix.PubSub, name: AshUI.PubSub},
      AshUI.Telemetry,
      AshUI.Repo,
      AshUI.Rendering.Registry
    ]

    opts = [strategy: :one_for_one, name: AshUI.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
