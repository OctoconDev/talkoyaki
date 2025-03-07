defmodule Talkoyaki.Components.SuggestionHandler do
  @moduledoc false
  import Talkoyaki.Utils, only: [brand_color: 0, text_input: 1, ephemeral_flag: 0, send_dm_success: 3]

  alias Talkoyaki.GitHub
  alias Nostrum.Struct.Embed

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
              "Thank you for submitting a suggestion. We'll look into it as soon as possible!\n\nYou'll receive a DM from <@1266802792383910052> shortly with a link to track the status of your suggestion.",
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

    url = GitHub.create_suggestion_issue(
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
