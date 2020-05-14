defmodule TodotxtDeadlineNotify.SentCache do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(data) do
    {:ok, data}
  end

  @doc """
  Check if a todo reminder at a specific time has been sent
  """
  def has_been_sent?(pid, todostr, time) do
    GenServer.call(pid, {:has_todo?, todostr, time})
  end

  @doc """
  Mark a todo reminder at a specific time as sent
  """
  def mark_sent(pid, todostr, time) do
    GenServer.call(pid, {:sent_todo, todostr, time})
  end

  # debug, dump state
  def handle_info(:dump_state, state) do
    IO.inspect(state)

    {:noreply, state}
  end

  # checks if the todo has been sent already
  def handle_call({:has_todo?, todostr, time}, _from, state) do
    matched_todo =
      if Map.has_key?(state, todostr) do
        Map.get(state, todostr) |> MapSet.member?(time)
      else
        false
      end

    {:reply, matched_todo, state}
  end

  # marks the todo as sent
  def handle_call({:sent_todo, todostr, time}, _from, state) do
    new_time_set = Map.get(state, todostr, MapSet.new()) |> MapSet.put(time)
    new_state = Map.put(state, todostr, new_time_set)
    {:reply, :ok, new_state}
  end
end
