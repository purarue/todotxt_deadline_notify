defmodule TodotxtDeadlineNotify.Worker do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(data) do
    todo_file = [data]
    # run initial check to make sure file exists/parse file
    state = maintenance(%{:todo_file => todo_file})
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
    %{todo_file: todo_filepath} = state

    {file_changed, state} = update_mod_time(state)

    state =
      if file_changed do
        IO.puts("Re-reading todo.txt file...")
        Map.put(state, :contents, File.read!(todo_filepath))
      else
        state
      end

    IO.inspect(state)

    state
  end

  # checks if the file has been changed on disk,
  # returns {true/false, state}
  # the bool signifies whether the file
  # has changed, and hence we should re-read
  defp update_mod_time(state) do
    %{todo_file: todo_filepath} = state

    stat_info =
      case File.stat(todo_filepath) do
        {:ok, stat_info} ->
          stat_info

        {:error, reason} ->
          IO.puts(:stderr, {"Error opening file", reason})
          System.halt(1)
      end

    mod_time = stat_info.mtime

    file_changed =
      if Map.has_key?(state, :todo_mod_time) do
        not (mod_time == Map.get(state, :todo_mod_time))
      else
        # default to true if file hasnt been read, to signify to read the file
        true
      end

    {file_changed, Map.put(state, :todo_mod_time, mod_time)}
  end

  # calls :check in 30 seconds
  defp schedule_check() do
    Process.send_after(self(), :check, 10 * 1000)
  end
end
