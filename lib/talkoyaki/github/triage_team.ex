defmodule Talkoyaki.GitHub.TriageTeam do
  @moduledoc false

  alias Talkoyaki.GitHub

  def get_triage_team_members do
    case :persistent_term.get(__MODULE__, nil) do
      nil -> generate_triage_team_members()
      {team, exp_time} ->
        if exp_time < System.os_time(:millisecond) do
          generate_triage_team_members()
        else
          team
        end
    end
  end

  def get_random_triage_team_member do
    get_triage_team_members()
    |> Enum.random()
  end

  defp generate_triage_team_members do
    client = GitHub.build_client()

    {200, members, _} = Tentacat.get("orgs/OctoconDev/teams/triage/members", client)
    member_usernames = Enum.map(members, &Map.get(&1, :login))

    :persistent_term.put(__MODULE__, {member_usernames, System.os_time(:millisecond) + :timer.hours(4)})
    member_usernames
  end
end