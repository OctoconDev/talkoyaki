defmodule Talkoyaki.Consumer do
  use Nostrum.Consumer

  require Logger

  alias Talkoyaki.{
    Components,
    Commands
  }

  @commands %{
    "resolve" => Commands.Resolve,
    "delete" => Commands.Delete
  }

  def handle_event({:READY, _data, _ws_state}) do
    Talkoyaki.Tags.register_bug_report_tags()
    Talkoyaki.Tags.register_suggestion_tags()

    spawn(fn ->
      Logger.info("Bulk-registering all slash commands (#{map_size(@commands)})...")

      guild_id = Application.get_env(:talkoyaki, :guild_id)

      Enum.each(@commands, fn {name, module} ->
        Nosedrum.Storage.Dispatcher.queue_command(name, module)
      end)

      case Nosedrum.Storage.Dispatcher.process_queue(guild_id) do
        {:ok, _} -> Logger.info("Registered all commands!")
        {:error, e} -> Logger.error("Failed to register all commands: #{e}")
      end
    end)

    :ok
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    if interaction.type in [3, 5] do
      Components.dispatch(interaction)
    else
      Nosedrum.Storage.Dispatcher.handle_interaction(interaction)
    end
  rescue
    e ->
      Nostrum.Api.create_interaction_response(interaction, %{
        type: :integer,
        data: %{
          flags: 64,
          embeds: [
            %{
              title: ":x: Whoops!",
              description: "An error occurred while processing your command.",
              color: 0xFF0000
            }
          ]
        }
      })

      reraise e, __STACKTRACE__
  end
end
