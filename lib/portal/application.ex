defmodule Portal.Application do
  @moduledoc """
    Starts the application and handles the sidecar (logging / telemetry)
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PortalWeb.Telemetry,
      Portal.Repo,
      {DNSCluster, query: Application.get_env(:portal, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Portal.PubSub},
      PortalWeb.Presence,
      {Registry, keys: :unique, name: Portal.LobbyRegistry}, 
      {Finch, name: Portal.Finch},
      PortalWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Portal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
