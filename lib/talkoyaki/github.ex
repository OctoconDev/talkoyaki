defmodule Talkoyaki.GitHub do
  @moduledoc false

  @jwt_key {:talkoyaki, :github_jwt}
  @install_token_key {:talkoyaki, :github_install_token}
  @jwt_expiration_minutes 5
  @install_token_expiration_minutes 30

  defp get_jwk_time do
    # GitHub recommends building the JWT to be 1 minute in the past to account for clock skew
    System.os_time(:millisecond) - :timer.seconds(60)
  end

  defp get_jwk do
    JOSE.JWK.from_pem(Application.get_env(:talkoyaki, :github_key_pem))
  end

  defp generate_jwt do
    current_time = get_jwk_time()
    time_seconds = div(current_time, 1000)

    jwt = JOSE.JWT.sign(
      get_jwk(),
      %{ "alg" => "RS256" },
      %{
        "iat" => time_seconds,
        "exp" => time_seconds + (@jwt_expiration_minutes * 60),
        "iss" => Application.get_env(:talkoyaki, :github_client_id)
      }
    )
    |> JOSE.JWS.compact()
    |> elem(1)

    :persistent_term.put(@jwt_key, {jwt, current_time + :timer.minutes(@jwt_expiration_minutes)})
    jwt
  end

  defp get_current_jwt do
    case :persistent_term.get(@jwt_key, nil) do
      nil -> generate_jwt()
      {jwt, exp_time} ->
        if exp_time < get_jwk_time() do
          generate_jwt()
        else
          jwt
        end
    end
  end

  def generate_install_token do
    app_client = build_app_client()

    {200, [ %{id: installation_id} ], _} = Tentacat.App.Installations.list_mine(app_client)
    {201, %{token: token}, _} = Tentacat.App.Installations.token(app_client, installation_id)

    :persistent_term.put(@install_token_key, {token, System.os_time(:millisecond) + :timer.minutes(@install_token_expiration_minutes)})
    token
  end

  def get_current_installation_token do
    case :persistent_term.get(@install_token_key, nil) do
      nil -> generate_install_token()
      {token, exp_time} ->
        if exp_time < System.os_time(:millisecond) do
          generate_install_token()
        else
          token
        end
    end
  end

  def build_app_client do
    Tentacat.Client.new(%{jwt: get_current_jwt()})
  end

  def build_client do
    Tentacat.Client.new(%{access_token: get_current_installation_token()})
  end

  @type_labels %{
    bot: {"Discord", "Bot"},
    app: {"App (all platforms)", "App"}
  }

  def create_bug_report_issue(
    :bot,
    %{
      description: description,
      discord_up_to_date: discord_up_to_date,
      affected_platform: affected_platform,
      expected_behavior: expected_behavior,
      actual_behavior: actual_behavior
    },
    user
  ) do
    {type_label, type_name} = @type_labels[:bot]

    discord_up_to_date =
      discord_up_to_date
      |> String.downcase()
      |> String.contains?("y")
      |> if(do: "Yes", else: "No")

    platform = extract_discord_platform(affected_platform)
    issue_title = "Bug Report (#{type_name}) - #{description}"
    issue_body = """
    #{
      if user == nil, do: "", else: """
      **Reported by:** @#{user.username} (#{user.id})

      """
    }
    **Discord up-to-date:** #{discord_up_to_date}
    **Affected platform:** #{platform}
    **Expected behavior:**
    #{expected_behavior}
    **Actual behavior:**
    #{actual_behavior}
    """

    create_issue(issue_title, issue_body, type_label)
  end

  def create_bug_report_issue(
    :app,
    %{
      app_version: app_version,
      description: description,
      affected_platform: platform,
      expected_behavior: expected_behavior,
      actual_behavior: actual_behavior
    },
    user
  ) do
    {type_label, type_name} = @type_labels[:app]

    issue_title = "Bug Report (#{type_name}) - #{description}"
    issue_body = """
    #{
      if user == nil, do: "", else: """
      **Reported by:** @#{user.username} (#{user.id})

      """
    }
    **App version:** #{app_version}
    **Affected platform:** #{platform}
    **Expected behavior:**
    #{expected_behavior}
    **Actual behavior:**
    #{actual_behavior}
    """

    create_issue(issue_title, issue_body, type_label)
  end

  defp extract_discord_platform(original_platform, downcase \\ nil)

  defp extract_discord_platform(original_platform, nil) do
    extract_discord_platform(original_platform, String.downcase(original_platform))
  end

  defp extract_discord_platform(_, "pc"), do: "PC"
  defp extract_discord_platform(_, "android"), do: "Android"
  defp extract_discord_platform(_, "ios"), do: "iOS"
  defp extract_discord_platform(other, _), do: String.capitalize(other)

  def create_suggestion_issue(
    type,
    %{
      title: title,
      suggestion: suggestion,
      reason: reason
    },
    user
  ) do
    {type_label, type_name} = @type_labels[type]

    issue_title = "Suggestion (#{type_name}) - #{title}"
    issue_body = """
    #{
      if user == nil, do: "", else: """
      **Suggested by:** @#{user.username} (#{user.id})

      """
    }
    **Suggestion:**
    #{suggestion}
    **Why this would be beneficial:**
    #{reason}
    """

    create_issue(issue_title, issue_body, type_label)
  end

  defp create_issue(title, body, type_label) do
    {201, %{html_url: url}, _} = Tentacat.Issues.create(build_client(), "OctoconDev", "issues", %{
      title: title,
      body: body,
      assignees: [Talkoyaki.GitHub.TriageTeam.get_random_triage_team_member()],
      labels: [type_label, "Needs triage"]
    })

    url
  end
end
