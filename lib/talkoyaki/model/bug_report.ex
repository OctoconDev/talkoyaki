defmodule Talkoyaki.Model.BugReport do
  @moduledoc false
  use Memento.Table,
    attributes: [
      :id,
      :title,
      :description,
      :type,
      :author_id,
      :thread_id,
      :bumps,
      :is_resolved?
    ],
    index: [:is_resolved?, :thread_id],
    type: :ordered_set,
    autoincrement: true

  import Talkoyaki.Model.Utils, only: [transaction: 1]
  import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]
  import Nostrum.Struct.Component.Button, only: [interaction_button: 3]

  alias Nostrum.Struct.Embed

  def list_bug_reports do
    transaction do
      Memento.Query.all(__MODULE__)
    end
  end

  def get_bug_report(report_id) do
    transaction do
      Memento.Query.read(__MODULE__, report_id)
    end
  end

  def get_bug_report_by_thread(thread_id) do
    transaction do
      Memento.Query.select(__MODULE__, {:==, :thread_id, thread_id})
    end
    |> List.first()
  end

  def bump_bug_report(report_id, user_id) do
    report = get_bug_report(report_id)

    {type, new_report} =
      if user_id in report.bumps do
        {:unbump,
         transaction do
           Memento.Query.write(%__MODULE__{
             report
             | bumps: report.bumps -- [user_id]
           })
         end}
      else
        {:bump,
         transaction do
           Memento.Query.write(%__MODULE__{
             report
             | bumps: [user_id | report.bumps]
           })
         end}
      end

    refresh_bug_report(new_report)

    type
  end

  def resolve_bug_report(id, details \\ "No details provided.") do
    report = get_bug_report(id)

    cond do
      report == nil ->
        {:error, "No bug report found."}

      report.is_resolved? ->
        {:error, "This bug report is already resolved."}

      true ->
        new_report =
          transaction do
            Memento.Query.write(%__MODULE__{
              report
              | is_resolved?: true
            })
          end

        all_tags = Talkoyaki.Tags.get_bug_report_tags()

        Task.await_many([
          Task.async(fn ->
            Nostrum.Api.modify_channel!(
              report.thread_id,
              %{
                applied_tags: [all_tags[report.type], all_tags[:resolved]]
              }
            )
          end),
          Task.async(fn ->
            Nostrum.Api.create_message!(report.thread_id,
              embeds: [
                %Embed{
                  title: ":white_check_mark: Resolved",
                  color: 0x00FF00,
                  description:
                    "This bug report has been marked as resolved. Details:\n\n*#{details}*"
                }
              ]
            )
          end),
          Task.async(fn ->
            Talkoyaki.Utils.send_dm_success(
              report.author_id,
              ":white_check_mark: Bug report resolved",
              "Your bug report **\"#{report.title}\"** has been resolved! Details:\n\n*#{details}*"
            )
          end)
        ])

        {:ok, new_report}
    end
  end

  def create_bug_report(%{
        type: type,
        author_id: author_id,
        responses: responses
      }) do
    result =
      transaction do
        Memento.Query.write(%__MODULE__{
          title: responses[:description],
          description: build_description(author_id, responses),
          type: type,
          author_id: author_id,
          bumps: [author_id]
        })
      end

    log_report(result, responses)

    result
  end

  def reject_bug_report(id, reason) do
    report = get_bug_report(id)

    case report do
      nil ->
        {:error, "No bug report found with ID #{id}"}

      report ->
        transaction do
          Memento.Query.delete(__MODULE__, id)
        end

        Talkoyaki.Utils.send_dm_danger(
          report.author_id,
          ":x: Bug report rejected",
          "Your bug report **\"#{report.title}\"** has been rejected for the following reason:\n\n*#{reason}*"
        )

        {:ok, report}
    end
  end

  def accept_bug_report(id) do
    report = get_bug_report(id)

    case report do
      nil ->
        {:error, "No bug report found with ID #{id}"}

      report ->
        %{
          thread_id: thread_id,
          guild_id: guild_id
        } = create_thread(report)

        new_report =
          transaction do
            Memento.Query.write(%__MODULE__{
              report
              | thread_id: thread_id
            })
          end

        Talkoyaki.Utils.send_dm_success(
          report.author_id,
          ":white_check_mark: Bug report accepted",
          "Your bug report **\"#{report.title}\"** has been accepted! A thread has been created for it [here](https://discord.com/channels/#{guild_id}/#{thread_id})."
        )

        {:ok, new_report}
    end
  end

  def delete_bug_report(id) do
    report = get_bug_report(id)

    transaction do
      Memento.Query.delete(__MODULE__, id)
    end

    Task.await_many([
      Task.async(fn ->
        Nostrum.Api.delete_channel!(report.thread_id)
      end),
      Task.async(fn ->
        Talkoyaki.Utils.send_dm_danger(
          report.author_id,
          ":wastebasket: Bug report deleted",
          "Your bug report **\"#{report.title}\"** has been deleted."
        )
      end)
    ])

    :ok
  end

  defp create_thread(%__MODULE__{
         title: title,
         description: description,
         type: type,
         id: id
       }) do
    channel = Application.get_env(:talkoyaki, :bug_reports_channel)
    all_tags = Talkoyaki.Tags.get_bug_report_tags()

    # TODO
    Nostrum.Api.start_thread_in_forum_channel(
      channel,
      %{
        name: title,
        applied_tags: [all_tags[type], all_tags[:unresolved]],
        message: %{
          content: description,
          components: [
            action_row([
              interaction_button(
                "Bump (1)",
                "bug-report|bump|#{id}",
                style: 2,
                emoji: %Nostrum.Struct.Emoji{name: "🔼"}
              )
            ])
          ]
        }
      }
    )
    |> case do
      {:ok,
       %{
         id: thread_id,
         guild_id: guild_id
       }} ->
        %{
          thread_id: thread_id,
          guild_id: guild_id
        }

      {:error, reason} ->
        raise reason
    end
  end

  defp refresh_bug_report(report) do
    old_message = Nostrum.Api.get_channel_message!(report.thread_id, report.thread_id)

    Nostrum.Api.edit_message!(report.thread_id, report.thread_id,
      content: old_message.content,
      embeds: old_message.embeds,
      components: [
        action_row([
          interaction_button(
            "Bump (#{length(report.bumps)})",
            "bug-report|bump|#{report.id}",
            style: 2,
            emoji: %Nostrum.Struct.Emoji{name: "🔼"}
          )
        ])
      ]
    )
  end

  defp log_report(report, responses) do
    log_channel = Application.get_env(:talkoyaki, :log_channel)

    res =
      Nostrum.Api.create_message(log_channel,
        embeds: [
          %Embed{
            title:
              ":warning: New bug report (#{report.type |> to_string() |> String.capitalize()})",
            color: Talkoyaki.Utils.brand_color(),
            description: "# #{report.title}\n#{report.description}",
            fields:
              [
                %Nostrum.Struct.Embed.Field{
                  name: "Type",
                  value: to_string(report.type) |> String.capitalize()
                }
              ] ++
                case report.type do
                  :app ->
                    [
                      %Nostrum.Struct.Embed.Field{
                        name: "App version",
                        value: responses[:app_version]
                      }
                    ]

                  :bot ->
                    [
                      %Nostrum.Struct.Embed.Field{
                        name: "Discord up-to-date?",
                        value: responses[:discord_up_to_date]
                      }
                    ]
                end
          }
        ],
        components: [
          action_row([
            interaction_button(
              "Accept",
              "bug-report|accept|#{report.id}",
              style: 3,
              emoji: %Nostrum.Struct.Emoji{name: "✅"}
            ),
            interaction_button(
              "Reject",
              "bug-report|reject|btn|#{report.id}",
              style: 4,
              emoji: %Nostrum.Struct.Emoji{name: "🗑️"}
            )
          ])
        ]
      )

    res
  end

  defp build_description(author_id, %{
         affected_platform: affected_platform,
         expected_behavior: expected_behavior,
         actual_behavior: actual_behavior
       }) do
    """
    ### Affected platform:
    #{affected_platform}
    ### Expected behavior:
    #{expected_behavior}
    ### Actual behavior:
    #{actual_behavior}
    ### Submitted by:
    <@#{author_id}>
    """
  end
end
