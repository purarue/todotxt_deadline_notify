use Mix.Config

home = System.user_home!()

config :todotxt_deadline_notify,
  todo_file: Path.join([home, ".todo/todo.txt"]),
  discord_web_hook: File.read!(Path.join([home, ".todo/discord.txt"])),
  timezone: "America/Los_Angeles",
  # these specify what time to batch remind me of all todos for the day (in the morning)
  # and all todos due the next day (the day before)
  # remind me at 10 in the morning on the same day
  morning_remind_at: [hour: 10, minute: 0],
  # remind me at 7PM on the previous day
  night_remind_at: [hour: 19, minute: 0]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
