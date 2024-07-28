defmodule Talkoyaki.Commands.Delete do
  @moduledoc false

  @behaviour Nosedrum.ApplicationCommand

  alias Talkoyaki.Utils
  alias Talkoyaki.Model.BugReport

  @impl true
  def description, do: "Deletes this bug report."

  @impl true
  def command(%{member: %{roles: roles}, channel_id: thread_id}) do
    mod_key_role_id = Application.get_env(:talkoyaki, :mod_key_role_id)

    if mod_key_role_id in roles do
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
    else
      Utils.error_embed("You do not have permission to use this command.")
    end
  end

  @impl true
  def type, do: :slash

  # @impl true
  # def options, do: []
end
