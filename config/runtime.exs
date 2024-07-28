import Config

try_get_env = fn key ->
  System.get_env(key) || raise("environment variable #{key} is missing.")
end

if config_env() == :prod do
  config :nostrum,
    token: try_get_env.("DISCORD_TOKEN")

  config :talkoyaki,
    log_channel: String.to_integer(try_get_env.("LOG_CHANNEL")),
    bug_reports_channel: String.to_integer(try_get_env.("BUG_REPORTS_CHANNEL")),
    suggestions_channel: String.to_integer(try_get_env.("SUGGESTIONS_CHANNEL")),
    guild_id: String.to_integer(try_get_env.("GUILD_ID")),
    mod_key_role_id: String.to_integer(try_get_env.("MOD_KEY_ROLE_ID"))
end
