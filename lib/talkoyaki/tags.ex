defmodule Talkoyaki.Tags do
  @moduledoc false

  def register_bug_report_tags do
    register_tags(
      Application.get_env(:talkoyaki, :bug_reports_channel),
      :bug_report_tags
    )
  end

  def get_bug_report_tags do
    :persistent_term.get({Talkoyaki, :bug_report_tags})
  end

  def register_suggestion_tags do
    register_tags(
      Application.get_env(:talkoyaki, :suggestions_channel),
      :suggestion_tags
    )
  end

  def get_suggestion_tags do
    :persistent_term.get({Talkoyaki, :suggestion_tags})
  end

  defp register_tags(channel_id, tag_type) do
    channel_id
    |> Nostrum.Api.get_channel!()
    |> Map.get(:available_tags)
    |> Enum.map(fn tag -> {tag.name |> String.downcase() |> String.to_atom(), tag.id} end)
    |> Enum.into(%{})
    |> then(fn tags -> :persistent_term.put({Talkoyaki, tag_type}, tags) end)
  end
end
