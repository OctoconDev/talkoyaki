defmodule Talkoyaki.Components do
  @moduledoc false

  alias __MODULE__.{
    BugReportHandler,
    SuggestionHandler
  }

  @dispatchers %{
    "bug-report" => &BugReportHandler.handle_interaction/2,
    "suggestion" => &SuggestionHandler.handle_interaction/2
  }

  def dispatch(interaction) do
    case String.split(interaction.data.custom_id, "|") do
      [id] ->
        Map.get(@dispatchers, id).(interaction)

      [id | rest] ->
        Map.get(@dispatchers, id).(interaction, Enum.map(rest, &String.to_atom/1))
    end
  end
end
