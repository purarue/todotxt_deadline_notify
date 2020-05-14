use Mix.Config

home = System.user_home!()

todo_file = Path.join([home], ".todo/todo.txt")
discord_file = Path.join([home, ".todo/discord.txt"])

discord_webhook = discord_file |> File.read!() |> String.trim()

if not File.exists?(todo_file) do
  IO.puts(:stderr, "'#{todo_file}' doesn't exists, exiting...")
  System.halt(1)
end

config :todotxt_deadline_notify,
  todo_file: todo_file,
  discord_webhook: discord_webhook,
  timezone: "America/Los_Angeles",
  # these specify what time to batch remind me of all todos for the day (in the morning)
  # and all todos due the next day (the day before)
  # remind me at 10 in the morning on the same day
  morning_remind_at: [hour: 10, minute: 0],
  # remind me at 7PM on the previous day
  night_remind_at: [hour: 19, minute: 0]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
