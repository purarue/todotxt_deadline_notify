defmodule TodotxtDeadlineNotify.Worker do
  alias TodotxtDeadlineNotify.Parser
  alias TodotxtDeadlineNotify.TodoUtils
  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def init(_data) do
    # run initial check to make sure file exists/parse file
    state =
      maintenance(%{
        :todo_file => Application.get_env(:todotxt_deadline_notify, :todo_file),
        :timezone => Application.get_env(:todotxt_deadline_notify, :timezone),
        morning_remind_at: Application.get_env(:todotxt_deadline_notify, :morning_remind_at),
        night_remind_at: Application.get_env(:todotxt_deadline_notify, :night_remind_at)
      })

    schedule_check()
    {:ok, state}
  end

  @doc """
  Main loop, checks if any notifications need to be sent
  """
  def handle_info(:check, state) do
    # recursive call to check file every 5 minutes
    state = maintenance(state)
    # check if any todos need to be sent
    state = check_for_new_todos(state)
    # schedule next loop
    schedule_check()
    {:noreply, state}
  end

  defp check_for_new_todos(state) do
    %{timezone: timezone} = state

    # when each todo is parsed, it saves times when notifications for it
    # should be sent (morning, night, some time before based on priority)
    # if the current time is past any of those times, it should send a message, and mark
    # a value in the genserver cache to specify that todo has been sent.
    # that cache dies whenever the application is restarted, so on application start, messages which
    # have deadlines in the past will have notifications sent (but not for each time (morning, night), should
    # be filtered down to each type, and then all marked notifications sent
    # (assuming the discord POST succeeded))
    # the duplicate notifications are managable. If a todo really has a deadline
    # in the past, no need to worry about re-remindig me about it.
    # If I dont want to be, I can always extend the deadline and re-sync the todo.txt file.
    # This keeps my todo.txt file up to date and reminds me to look at my todos
    state
  end

  # re-reads the file if needed,
  # updates the list of todos
  defp maintenance(state) do
    %{
      todo_file: todo_filepath,
      morning_remind_at: morn,
      night_remind_at: night
    } = state

    # update when the file was last changed and check if we need to re-read the file
    {file_changed, state} = update_mod_time(state)

    if file_changed do
      IO.puts("Re-reading todo.txt file...")

      todo_list =
        File.read!(todo_filepath)
        |> Parser.parse_file_contents()
        |> Stream.map(&TodoUtils.parse_deadline(&1))
        |> Stream.map(&TodoUtils.get_notification_times(&1, morn, night))
        |> Enum.to_list()

      IO.puts("Read #{length(todo_list)} todos: ")

      new_state = Map.merge(state, %{todos: todo_list})
      IO.inspect(new_state)
      new_state
    else
      state
    end
  end

  # checks if the file has been changed on disk,
  # returns {true/false, state}
  # the bool signifies whether the file
  # has changed, and hence we should re-read
  defp update_mod_time(state) do
    %{todo_file: todo_filepath} = state

    # possibility to crash here, if the file doesnt exist
    {:ok, stat_info} = File.stat(todo_filepath)

    file_changed =
      if Map.has_key?(state, :todo_mod_time) do
        # if the file has changed since we last read it, re-read
        not (stat_info.mtime == Map.get(state, :todo_mod_time))
      else
        # default to true if file hasnt been read, to signify to read the file
        # if this is being called from init, maintenance fails and the application doesnt start at all.
        true
      end

    {file_changed, Map.put(state, :todo_mod_time, stat_info.mtime)}
  end

  # calls :check in 30 seconds
  defp schedule_check() do
    Process.send_after(self(), :check, 5 * 1000)
  end
end
