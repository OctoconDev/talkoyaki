defmodule Talkoyaki.Components.BugReportHandler do
  @moduledoc false

  import Talkoyaki.Utils, only: [brand_color: 0, text_input: 1, ephemeral_flag: 0, send_dm_success: 3]

  alias Talkoyaki.GitHub
  alias Nostrum.Struct.Embed

  @global_components [
    text_input(
      id: "description",
      label: "What is a short description of the bug?",
      min_length: 1,
      max_length: 100,
      placeholder: "Doing \"XYZ\" causes..."
    ),
    text_input(
      id: "expected_behavior",
      type: :long,
      label: "What did you expect to happen?",
      min_length: 1,
      max_length: 800,
      placeholder: "I expected..."
    ),
    text_input(
      id: "actual_behavior",
      type: :long,
      label: "What actually happened?",
      min_length: 1,
      max_length: 800,
      placeholder: "Instead..."
    )
  ]

  def handle_interaction(interaction, options \\ [])

  def handle_interaction(interaction, [:button, :bot]) do
    Nostrum.Api.create_interaction_response(interaction, %{
      type: 9,
      data: %{
        title: "Report a bug!",
        custom_id: "bug-report|modal|bot",
        components: [
          text_input(
            id: "discord_up_to_date",
            label: "Is your Discord client up-to-date?",
            min_length: 1,
            max_length: 3,
            placeholder: "Yes/No"
          ),
          text_input(
            id: "affected_platform",
            label: "Are you on PC, Android, or iOS?",
            min_length: 1,
            max_length: 15,
            placeholder: "PC/Android/iOS"
          )
          | @global_components
        ]
      }
    })
  end

  def handle_interaction(interaction, [:button, :app]) do
    Nostrum.Api.create_interaction_response(interaction, %{
      type: 9,
      data: %{
        title: "Report a bug!",
        custom_id: "bug-report|modal|app",
        components: [
          text_input(
            id: "app_version",
            label: "Which version of the app are you using?",
            min_length: 1,
            max_length: 15,
            placeholder: "1.2.3 (45)"
          ),
          text_input(
            id: "affected_platform",
            label: "What platform are you on (including version)?",
            min_length: 1,
            max_length: 15,
            placeholder: "Android 12; iOS 14.5"
          )
          | @global_components
        ]
      }
    })
  end

  def handle_interaction(interaction, [:modal, type]) do
    handle_modal(type, interaction)

    Nostrum.Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{
        embeds: [
          %Embed{
            title: "Bug report submitted!",
            description:
              "Thank you for submitting a bug report. We'll look into it as soon as possible!\n\nYou'll receive a DM from <@1266802792383910052> shortly with a link to track the status of your report.",
            color: brand_color()
          }
        ],
        flags: ephemeral_flag()
      }
    })
  end

  def handle_modal(type, %{
        data: %{components: components},
        user: %{id: author_id}
      }) do
    responses = parse_responses(components)

    user = case Nostrum.Api.User.get(author_id) do
      {:ok, user} -> user
      _ -> nil
    end

    url = GitHub.create_bug_report_issue(
      type,
      responses,
      user
    )
    send_dm_success(author_id, "Suggestion submitted!", "Thank you for submitting a suggestion! You can track the status of your suggestion [here](#{url}).")

    :ok
  end

  defp parse_responses(components) do
    components
    |> Stream.map(&List.first(&1.components))
    |> Stream.map(fn %{custom_id: id, value: value} ->
      {String.to_atom(id), value}
    end)
    |> Enum.into(%{})
  end
end
