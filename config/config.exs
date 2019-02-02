use Mix.Config

config :logger, :console,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  level: :warn

config :mnesia, dir: 'mnesia/#{Mix.env()}/#{node()}'
