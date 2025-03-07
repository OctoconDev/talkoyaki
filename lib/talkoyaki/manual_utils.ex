defmodule Talkoyaki.ManualUtils do
  @moduledoc false

  @app :talkoyaki

  require Logger

  alias Nostrum.Struct.Embed

  def release do
    load_app()

    Logger.info("Release tasks are running...")
  end

  def nuke_tables do
    Logger.info("Nuking all tables...")

    :mnesia.system_info(:tables)
    |> Enum.each(&:mnesia.delete_table/1)

    Logger.info("Reinitializing tables...")

    Talkoyaki.Application.init_mnesia()

    Logger.info("Tables reinitialized.")
  end

  def create_bug_report_embed do
    import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]
    import Nostrum.Struct.Component.Button, only: [interaction_button: 3]

    channel_id = Application.get_env(:talkoyaki, :bug_reports_channel)

    Nostrum.Api.Message.create(channel_id, %{
      embeds: [
        %Embed{
          title: "Report a bug!",
          description: """
          Use a button below to report a bug. Please provide as much detail as possible!

          **NOTE:** Before doing this, please check TODO to see if the bug has already been reported. If you are experiencing a very similar issue and have additional information, please comment on the existing report or let us know in #TODO.
          """,
          color: Talkoyaki.Utils.brand_color()
        }
      ],
      components: [
        action_row([
          interaction_button(
            "Report a bot bug",
            "bug-report|button|bot",
            style: 2,
            emoji: %Nostrum.Struct.Emoji{name: "🤖"}
          ),
          interaction_button(
            "Report an app bug",
            "bug-report|button|app",
            style: 2,
            emoji: %Nostrum.Struct.Emoji{name: "📱"}
          )
        ])
      ]
    })
  end

  def create_suggestion_embed do
    import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]
    import Nostrum.Struct.Component.Button, only: [interaction_button: 3]

    channel_id = Application.get_env(:talkoyaki, :suggestions_channel)

    Nostrum.Api.Message.create(channel_id, %{
      embeds: [
        %Embed{
          title: "Make a suggestion!",
          description: """
          Use a button below to make a suggestion. Please provide as much detail as possible!

          **NOTE:** Before doing this, please check TODO to see if the suggestion has already been made.
          """,
          color: Talkoyaki.Utils.brand_color()
        }
      ],
      components: [
        action_row([
          interaction_button(
            "Make a bot suggestion",
            "suggestion|button|bot",
            style: 2,
            emoji: %Nostrum.Struct.Emoji{name: "🤖"}
          ),
          interaction_button(
            "Make an app suggestion",
            "suggestion|button|app",
            style: 2,
            emoji: %Nostrum.Struct.Emoji{name: "📱"}
          )
        ])
      ]
    })
  end

  defp load_app do
    Application.load(@app)
  end
end
