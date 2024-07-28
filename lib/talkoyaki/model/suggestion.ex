defmodule Talkoyaki.Model.Suggestion do
  @moduledoc false
  use Memento.Table,
    attributes: [
      :id,
      :title,
      :description,
      :type,
      :author_id,
      :thread_id,
      :bumps
    ],
    index: [:thread_id],
    type: :ordered_set,
    autoincrement: true

  import Talkoyaki.Model.Utils, only: [transaction: 1]
  import Nostrum.Struct.Component.ActionRow, only: [action_row: 1]
  import Nostrum.Struct.Component.Button, only: [interaction_button: 3]

  alias Nostrum.Struct.Embed

  def list_suggestions do
    transaction do
      Memento.Query.all(__MODULE__)
    end
  end

  def get_suggestion(suggestion_id) do
    transaction do
      Memento.Query.read(__MODULE__, suggestion_id)
    end
  end

  def get_suggestion_by_thread(thread_id) do
    transaction do
      Memento.Query.select(__MODULE__, {:==, :thread_id, thread_id})
    end
    |> List.first()
  end

  def bump_suggestion(suggestion_id, user_id) do
    suggestion = get_suggestion(suggestion_id)

    {type, new_suggestion} =
      if user_id in suggestion.bumps do
        {:unbump,
         transaction do
           Memento.Query.write(%__MODULE__{
             suggestion
             | bumps: suggestion.bumps -- [user_id]
           })
         end}
      else
        {:bump,
         transaction do
           Memento.Query.write(%__MODULE__{
             suggestion
             | bumps: [user_id | suggestion.bumps]
           })
         end}
      end

    refresh_suggestion(new_suggestion)

    type
  end

  def create_suggestion(%{
        type: type,
        author_id: author_id,
        responses: responses
      }) do
    result =
      transaction do
        Memento.Query.write(%__MODULE__{
          title: responses[:title],
          description: build_description(author_id, responses),
          type: type,
          author_id: author_id,
          bumps: [author_id]
        })
      end

    log_suggestion(result)

    result
  end

  def reject_suggestion(id, reason) do
    suggestion = get_suggestion(id)

    case suggestion do
      nil ->
        {:error, "No suggestion found with ID #{id}"}

      suggestion ->
        transaction do
          Memento.Query.delete(__MODULE__, id)
        end

        Talkoyaki.Utils.send_dm_danger(
          suggestion.author_id,
          ":x: Suggestion rejected",
          "Your suggestion **\"#{suggestion.title}\"** has been rejected for the following reason:\n\n*#{reason}*"
        )

        {:ok, suggestion}
    end
  end

  def accept_suggestion(id) do
    suggestion = get_suggestion(id)

    case suggestion do
      nil ->
        {:error, "No suggestion found with ID #{id}"}

      suggestion ->
        %{
          thread_id: thread_id,
          guild_id: guild_id
        } = create_thread(suggestion)

        new_suggestion =
          transaction do
            Memento.Query.write(%__MODULE__{
              suggestion
              | thread_id: thread_id
            })
          end

        Talkoyaki.Utils.send_dm_success(
          suggestion.author_id,
          ":white_check_mark: Suggestion accepted",
          "Your suggestion **\"#{suggestion.title}\"** has been accepted! A thread has been created for it [here](https://discord.com/channels/#{guild_id}/#{thread_id})."
        )

        {:ok, new_suggestion}
    end
  end

  def delete_suggestion(id) do
    suggestion = get_suggestion(id)

    transaction do
      Memento.Query.delete(__MODULE__, id)
    end

    Task.await_many([
      Task.async(fn ->
        Nostrum.Api.delete_channel!(suggestion.thread_id)
      end),
      Task.async(fn ->
        Talkoyaki.Utils.send_dm_danger(
          suggestion.author_id,
          ":wastebasket: Suggestion deleted",
          "Your suggestion **\"#{suggestion.title}\"** has been deleted."
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
    channel = Application.get_env(:talkoyaki, :suggestions_channel)
    all_tags = Talkoyaki.Tags.get_suggestion_tags()

    # TODO
    Nostrum.Api.start_thread_in_forum_channel(
      channel,
      %{
        name: title,
        applied_tags: [all_tags[type]],
        message: %{
          content: description,
          components: [
            action_row([
              interaction_button(
                "Bump (1)",
                "suggestion|bump|#{id}",
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

  defp refresh_suggestion(suggestion) do
    old_message = Nostrum.Api.get_channel_message!(suggestion.thread_id, suggestion.thread_id)

    Nostrum.Api.edit_message!(suggestion.thread_id, suggestion.thread_id,
      content: old_message.content,
      embeds: old_message.embeds,
      components: [
        action_row([
          interaction_button(
            "Bump (#{length(suggestion.bumps)})",
            "suggestion|bump|#{suggestion.id}",
            style: 2,
            emoji: %Nostrum.Struct.Emoji{name: "🔼"}
          )
        ])
      ]
    )
  end

  defp log_suggestion(suggestion) do
    log_channel = Application.get_env(:talkoyaki, :log_channel)

    res =
      Nostrum.Api.create_message(log_channel,
        embeds: [
          %Embed{
            title:
              "<:important:1259653512904572938> New suggestion (#{suggestion.type |> to_string() |> String.capitalize()})",
            color: Talkoyaki.Utils.brand_color(),
            description: "# #{suggestion.title}\n#{suggestion.description}",
            fields: [
              %Nostrum.Struct.Embed.Field{
                name: "Type",
                value: to_string(suggestion.type) |> String.capitalize()
              }
            ]
          }
        ],
        components: [
          action_row([
            interaction_button(
              "Accept",
              "suggestion|accept|#{suggestion.id}",
              style: 3,
              emoji: %Nostrum.Struct.Emoji{name: "✅"}
            ),
            interaction_button(
              "Reject",
              "suggestion|reject|btn|#{suggestion.id}",
              style: 4,
              emoji: %Nostrum.Struct.Emoji{name: "🗑️"}
            )
          ])
        ]
      )

    res
  end

  defp build_description(author_id, %{
         suggestion: description,
         reason: reason
       }) do
    """
    ### Suggestion description:
    #{description}
    ### Reasoning:
    #{reason}
    ### Submitted by:
    <@#{author_id}>
    """
  end
end
