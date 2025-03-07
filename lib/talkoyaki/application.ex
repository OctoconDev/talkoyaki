defmodule Talkoyaki.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  alias Talkoyaki.Model

  @impl true
  def start(_type, _args) do
    Logger.info("Starting up...")

    children = [
      Nostrum.Application,
      {Nosedrum.Storage.Dispatcher, name: Nosedrum.Storage.Dispatcher},
      Talkoyaki.Consumer
    ]

    opts = [strategy: :one_for_one, name: Talkoyaki.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
