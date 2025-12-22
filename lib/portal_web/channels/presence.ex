defmodule PortalWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.
  """
  use Phoenix.Presence,
    otp_app: :portal,
    pubsub_server: Portal.PubSub
end
