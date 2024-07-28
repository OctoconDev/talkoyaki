defmodule Talkoyaki.Commands.Delete do
  @moduledoc false

  @behaviour Nosedrum.ApplicationCommand

  alias Talkoyaki.Model.{
    BugReport,
    Suggestion
  }
  alias Talkoyaki.Utils

  @impl true
  def description, do: "Deletes this bug report or suggestion."

  @impl true
  def command(%{member: %{roles: roles}, channel_id: thread_id, channel: %{parent_id: forum_id}}) do
    mod_key_role_id = Application.get_env(:talkoyaki, :mod_key_role_id)

    if mod_key_role_id in roles do
      cond do
        forum_id == Application.get_env(:talkoyaki, :bug_reports_channel) ->
          delete_bug_report(thread_id)

        forum_id == Application.get_env(:talkoyaki, :suggestions_channel) ->
          delete_suggestion(thread_id)

        true ->
          Utils.error_embed("This command can only be used in the channel of a bug report or suggestion.")
      end
    else
      Utils.error_embed("You do not have permission to use this command.")
    end
  end

  defp delete_bug_report(thread_id) do
    case BugReport.get_bug_report_by_thread(thread_id) do
      nil ->
        Utils.error_embed("This bug report does not exist.")

      report ->
        case BugReport.delete_bug_report(report.id) do
          {:error, reason} ->
            Utils.error_embed(reason)

          :ok ->
            Utils.success_embed("Successfully deleted this bug report!")
        end
    end
  end

  defp delete_suggestion(thread_id) do
    case Suggestion.get_suggestion_by_thread(thread_id) do
      nil ->
        Utils.error_embed("This suggestion does not exist.")

      suggestion ->
        case Suggestion.delete_suggestion(suggestion.id) do
          {:error, reason} ->
            Utils.error_embed(reason)

          :ok ->
            Utils.success_embed("Successfully deleted this suggestion!")
        end
    end
  end

  @impl true
  def type, do: :slash

  # @impl true
  # def options, do: []
end
