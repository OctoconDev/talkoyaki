import Config

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :nostrum, token: "TOKEN_HERE"

config :talkoyaki,
  bug_reports_channel: 1_234_567_890_123_456_789,
  suggestions_channel: 1_234_567_890_123_456_789,
  guild_id: 1_234_567_890_123_456_789,
  mod_key_role_id: 1_234_567_890_123_456_789,
  github_client_id: "",
  github_key_pem: ""
