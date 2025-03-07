defmodule Talkoyaki.Consumer do
  use Nostrum.Consumer

  require Logger

  alias Talkoyaki.{
    Components
  }

  def handle_event({:READY, _data, _ws_state}) do
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
      # Catch the error to notify the user, then re-raise it for logging
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
