defmodule Noizu.Intellect.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      Noizu.IntellectWeb.Telemetry,
      # Start the Ecto repository
      Noizu.Intellect.Repo,
      # Start Redis
      Noizu.Intellect.Redis,
      # Start the PubSub system
      Supervisor.child_spec({Phoenix.PubSub, name: Noizu.Intellect.PubSub}, id: :pubsub_standard),
      Supervisor.child_spec({Phoenix.PubSub, name: Noizu.Intellect.LiveViewEvent}, id: :pubsub_live_event),
      # Start Finch
      {Finch, name: Noizu.Intellect.Finch},
      # Start Services
      Noizu.Intellect.Services.Supervisor,

      # Start the Endpoint (http/https)
      Noizu.IntellectWeb.Endpoint
      # Start a worker by calling: Noizu.Intellect.Worker.start_link(arg)
      # {Noizu.Intellect.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Noizu.Intellect.Supervisor]
    s = Supervisor.start_link(children, opts)
    if Mix.env != :test do
      Noizu.Intellect.Services.Supervisor.bring_online(Noizu.Context.dummy())
    end
    s
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Noizu.IntellectWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
