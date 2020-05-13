use Mix.Config

home = System.user_home!

config :todotxt_deadline_notify,
  todo_file: Path.join([home, ".todo/todo.txt"]),
  discord_web_hook: File.read!(Path.join([home, ".todo/discord.txt"]))
