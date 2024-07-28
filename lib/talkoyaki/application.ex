defmodule Talkoyaki.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  alias Talkoyaki.Model

  @tables [
    Model.BugReport,
    Model.Suggestion
  ]

  @impl true
  def start(_type, _args) do
    Logger.info("Starting up...")

    children = [
      Supervisor.child_spec(
        {Task, fn -> init_mnesia() end},
        id: :init_mnesia
      ),
      Nostrum.Application,
      {Nosedrum.Storage.Dispatcher, name: Nosedrum.Storage.Dispatcher},
      Talkoyaki.Consumer
    ]

    opts = [strategy: :one_for_one, name: Talkoyaki.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def init_mnesia do
    Logger.info("Initializing mnesia...")
    nodes = [Node.self()]

    Logger.info("Stopping mnesia...")
    Memento.stop()
    Logger.info("Creating schema...")
    Memento.Schema.create(nodes)
    Logger.info("Starting mnesia...")
    Memento.start()

    Logger.info("Creating tables...")

    for table <- @tables do
      Logger.info("Creating table #{inspect(table)}")

      case Memento.Table.create(table, disc_copies: nodes) do
        :ok ->
          Logger.info("Table created successfully")

        {:error, {:already_exists, _}} ->
          Logger.info("Table already exists; skipping")

        {:error, error} ->
          raise "Table creation failed: #{inspect(error)}"
      end
    end
  end
end
