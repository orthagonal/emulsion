defmodule Emulsion.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      EmulsionWeb.Telemetry,
      { Emulsion.Files, name: :fileServer },
      { Emulsion.Video, name: :videoServer },
      { Emulsion.NotifyWhenDone, name: :notifyWhenDone},
      # Start the Ecto repository
      Emulsion.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Emulsion.PubSub},
      # Start Finch
      {Finch, name: Emulsion.Finch},
      # Start the Endpoint (http/https)
      EmulsionWeb.Endpoint
      # Start a worker by calling: Emulsion.Worker.start_link(arg)
      # {Emulsion.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Emulsion.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EmulsionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
