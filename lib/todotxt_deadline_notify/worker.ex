defmodule TodotxtDeadlineNotify.Worker do
  alias TodotxtDeadlineNotify.Parser
  use GenServer

  def start_link(data) do
    GenServer.start_link(__MODULE__, data, name: __MODULE__)
  end

  def init(_data) do
    todo_file = Application.get_env(:todotxt_deadline_notify, :todo_file)

    timezone =
      Application.get_env(:todotxt_deadline_notify, :timezone) |> Timex.Timezone.get(Timex.now())

    # run initial check to make sure file exists/parse file
    state = maintenance(%{:todo_file => todo_file, :timezone => timezone})
    schedule_check()
    {:ok, state}
  end

  @doc """
  Main loop, checks if any notifications need to be sent
  """
  def handle_info(:check, state) do
    # recursive call to check file every 5 minutes
    state = maintenance(state)
    # schedule next loop
    schedule_check()
    {:noreply, state}
  end

  # re-reads the file if needed,
  # updates the list of todos
  defp maintenance(state) do
    %{todo_file: todo_filepath, timezone: timezone} = state

    {file_changed, state} = update_mod_time(state)

    state =
      if file_changed do
        IO.puts("Re-reading todo.txt file...")

        todo_list =
          File.read!(todo_filepath)
          |> Parser.parse_file_contents()
          |> Enum.map(fn todo ->
            if Map.has_key?(todo.additional_tags, "deadline") do
              parsed_time =
                Timex.parse!(todo.additional_tags["deadline"], "%Y-%m-%d-%H-%M", :strftime)
                |> Timex.Timezone.convert(timezone)

              %{todo | additional_tags: Map.put(todo.additional_tags, "deadline", parsed_time)}
            else
              todo
            end
          end)

        IO.puts("Read #{length(todo_list)} todos: ")

        new_state = Map.put(state, :todos, todo_list)
        IO.inspect(new_state)
        new_state
      else
        state
      end

    state
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
    Process.send_after(self(), :check, 10 * 1000)
  end
end
