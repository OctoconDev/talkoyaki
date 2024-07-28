defmodule Talkoyaki.Components.SuggestionHandler do
  @moduledoc false
  import Talkoyaki.Utils, only: [brand_color: 0, text_input: 1, ephemeral_flag: 0]

  alias Nostrum.Struct.Embed

  def handle_interaction(interaction, options \\ [])

  def handle_interaction(interaction, [:button, type]) do
    Nostrum.Api.create_interaction_response(interaction, %{
      type: 9,
      data: %{
        title: "Make a suggestion!",
        custom_id: "suggestion|modal|#{type}",
        components: [
          text_input(
            id: "title",
            label: "What is a short title for your suggestion?",
            min_length: 1,
            max_length: 100,
            placeholder: "My suggestion is..."
          ),
          text_input(
            id: "suggestion",
            type: :long,
            label: "What is your suggestion?",
            min_length: 1,
            max_length: 800,
            placeholder: "I think it would be cool if..."
          ),
          text_input(
            id: "reason",
            type: :long,
            label: "Why do you think this would be beneficial?",
            min_length: 1,
            max_length: 800,
            placeholder: "I think this would be beneficial because..."
          )
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
            title: "Suggestion submitted!",
            description:
              "Thank you for submitting a suggestion. We'll look into it as soon as possible!\n\nYou'll receive a DM from <@1266802792383910052> shortly once your suggestion is reviewed.",
            color: brand_color()
          }
        ],
        flags: ephemeral_flag()
      }
    })
  end

  def handle_interaction(interaction, [:reject, :btn, id]) do
    Nostrum.Api.create_interaction_response(interaction, %{
      type: 9,
      data: %{
        title: "Reject suggestion",
        custom_id: "suggestion|reject|modal|#{id}",
        components: [
          text_input(
            id: "reason",
            label: "Rejection reason",
            min_length: 1,
            max_length: 800,
            placeholder: "We're rejecting this suggestion because..."
          )
        ]
      }
    })
  end

  def handle_interaction(
        %{
          message: %{embeds: [embed]},
          data: %{components: [%{components: [%{value: reason}]}]},
          user: %{id: mod_id}
        } = interaction,
        [:reject, :modal, id]
      ) do
    Talkoyaki.Model.Suggestion.reject_suggestion(id |> to_string() |> String.to_integer(), reason)

    Nostrum.Api.create_interaction_response(interaction, %{
      type: 7,
      data: %{
        content: "Rejected by: <@#{mod_id}>",
        embeds: [
          embed
          |> Map.put(:title, ":wastebasket: Suggestion rejected")
          |> Map.put(:color, 0xFF0000)
        ],
        components: nil
      }
    })
  end

  def handle_interaction(
        %{
          message: %{embeds: [embed]},
          user: %{id: mod_id},
          guild_id: guild_id
        } = interaction,
        [:accept, id]
      ) do
    {:ok, new_suggestion} =
      Talkoyaki.Model.Suggestion.accept_suggestion(id |> to_string() |> String.to_integer())

    Nostrum.Api.create_interaction_response(interaction, %{
      type: 7,
      data: %{
        content:
          "Accepted by: <@#{mod_id}>; thread: https://discord.com/channels/#{guild_id}/#{new_suggestion.thread_id}",
        embeds: [
          embed
          |> Map.put(:title, ":white_check_mark: Suggestion accepted")
          |> Map.put(:color, 0x00FF00)
        ],
        components: nil
      }
    })
  end

  def handle_interaction(%{user: %{id: user_id}} = interaction, [:bump, id]) do
    res =
      Talkoyaki.Model.Suggestion.bump_suggestion(
        id |> to_string() |> String.to_integer(),
        user_id
      )

    Nostrum.Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{
        embeds: [
          %Embed{
            title: if(res == :bump, do: "Bumped!", else: "Unbumped!"),
            description:
              if(res == :bump,
                do: "Successfully bumped this suggestion!",
                else: "Successfully unbumped this suggestion!"
              ),
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

    Talkoyaki.Model.Suggestion.create_suggestion(%{
      type: type,
      author_id: author_id,
      responses: responses
    })
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
