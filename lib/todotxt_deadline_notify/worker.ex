defmodule TodotxtDeadlineNotify.Worker do
  alias TodotxtDeadlineNotify.Parser
  alias TodotxtDeadlineNotify.TodoUtils
  alias TodotxtDeadlineNotify.SentCache
  alias TodotxtDeadlineNotify.Notify
  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def init(_data) do
    {:ok, cache_pid} = TodotxtDeadlineNotify.SentCache.start_link()

    # run initial check to make sure file exists/parse file

    state =
      maintenance(%{
        todo_file: Application.get_env(:todotxt_deadline_notify, :todo_file),
        timezone: Application.get_env(:todotxt_deadline_notify, :timezone),
        morning_remind_at: Application.get_env(:todotxt_deadline_notify, :morning_remind_at),
        night_remind_at: Application.get_env(:todotxt_deadline_notify, :night_remind_at),
        cache_pid: cache_pid
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
    state = send_notifications(state)
    # schedule next loop
    schedule_check()
    {:noreply, state}
  end

  defp current_naive_time(timezone) do
    DateTime.utc_now()
    |> DateTime.shift_zone!(timezone)
    |> DateTime.to_naive()
  end

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
  defp send_notifications(state) do
    %{timezone: timezone, cache_pid: pid} = state

    current_time = current_naive_time(timezone)

    reminders_to_send =
      state[:todos]
      # create {todotxt, reminder send time} tuples
      |> Enum.map(fn todo ->
        todo.reminders
        |> Enum.map(fn remind -> {todo.text, remind} end)
      end)
      |> List.flatten()
      # if the reminder send time is in the past
      |> Enum.filter(fn {_todotxt, attime} ->
        NaiveDateTime.compare(attime, current_time) == :lt
      end)
      # if the notification hasnt already been sent
      |> Enum.filter(fn {todotxt, attime} ->
        not SentCache.has_been_sent?(pid, todotxt, attime)
      end)

    # IO.inspect(reminders_to_send)

    # dont need to send muliple reminders for the same message on one loop
    responses_sent =
      reminders_to_send
      # filter to only send unique reminders
      |> Enum.map(fn {todotxt, _at} ->
        todotxt
      end)
      |> MapSet.new()
      # send notifications
      |> Enum.map(&Notify.notify(&1))

    # IO.inspect(responses_sent)

    # filter messages that got sent successfully
    messages_sent_successfully =
      responses_sent
      |> Enum.filter(fn {status, _message} ->
        status == :ok
      end)
      |> Enum.map(fn {_status, message} ->
        message
      end)
      |> MapSet.new()

    # IO.inspect(messages_sent_successfully)

    # mark messages that were sent successfully as sent
    reminders_to_send
    |> Enum.filter(fn {todotxt, _at} ->
      MapSet.member?(messages_sent_successfully, todotxt)
    end)
    |> Enum.map(fn {todotxt, attime} ->
      SentCache.mark_sent(pid, todotxt, attime)
    end)

    # for debuginning items in cache
    if length(responses_sent) > 0 do
      IO.puts("Current SendCache state:")
      send(pid, :dump_state)
    end

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

    case File.stat(todo_filepath) do
      {:ok, stat_info} ->
        file_changed =
          if Map.has_key?(state, :todo_mod_time) do
            # if the file has changed since we last read it, re-read
            not (stat_info.mtime == Map.get(state, :todo_mod_time))
          else
            # default to true if file hasnt been read, to signify to read the file
            # if this is being called from init and it fails, maintenance fails and the application doesnt start at all.
            true
          end

        {file_changed, Map.put(state, :todo_mod_time, stat_info.mtime)}

      {:error, _} ->
        IO.puts(:stderr, "Error: Could not stat file: #{todo_filepath}")
        {false, state}
    end
  end

  # calls :check once a minute
  defp schedule_check() do
    Process.send_after(self(), :check, 60 * 1000)
  end
end
