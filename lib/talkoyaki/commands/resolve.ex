defmodule Talkoyaki.Commands.Resolve do
  @moduledoc false

  @behaviour Nosedrum.ApplicationCommand

  alias Talkoyaki.Utils
  alias Talkoyaki.Model.BugReport

  @impl true
  def description, do: "Resolves this bug report."

  @impl true
  def command(%{member: %{roles: roles}, channel_id: thread_id, data: %{options: options}}) do
    mod_key_role_id = Application.get_env(:talkoyaki, :mod_key_role_id)

    if mod_key_role_id in roles do
      case BugReport.get_bug_report_by_thread(thread_id) do
        nil ->
          Utils.error_embed("This bug report does not exist.")

        report ->
          reason = Utils.get_command_option(options, "reason")
          case BugReport.resolve_bug_report(report.id, reason) do
            {:error, reason} ->
              Utils.error_embed(reason)

            {:ok, _} ->
              Utils.success_embed("Successfully resolved this bug report!")
          end
      end
    else
      Utils.error_embed("You do not have permission to use this command.")
    end
  end

  @impl true
  def type, do: :slash

  @impl true
  def options,
    do: [
      %{
        name: "reason",
        description: "The reason for resolving this bug report.",
        type: :string,
        max_length: 800,
        required: true
      }
    ]
end
