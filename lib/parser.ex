defmodule TodotxtDeadlineNotify.Todo do
  defstruct priority: nil,
            creation_date: nil,
            text: "",
            reminders: [],
            projects: [],
            contexts: [],
            additional_tags: %{}
end

defmodule TodotxtDeadlineNotify.Parser do
  @moduledoc """
  Parses the todo.txt format into a map
  """
  alias TodotxtDeadlineNotify.Todo

  def from_string(todotxt_string) do
    # If Priority exists, parse it
    priority = (Regex.run(~r"\([A-Z]\)", todotxt_string) || []) |> List.first()

    # If creation date exists, parse it
    creation_date_str =
      (Regex.run(~r"\b\d{4}-\d{2}-\d{2}", todotxt_string) || [])
      |> List.first()

    {:ok, creation_parsed} =
      if creation_date_str do
        Date.from_iso8601(creation_date_str)
      else
        {:ok, nil}
      end

    contexts = Regex.scan(~r"@\w+", todotxt_string) |> List.flatten()
    tags = Regex.scan(~r"\+\w+", todotxt_string) |> List.flatten()

    additional_tags =
      Regex.scan(~r"([^(\s|:)]+):([^($|\s)]+)", todotxt_string)
      # remove first match
      |> Enum.map(&(&1 |> tl()))
      # convert to map
      |> Map.new(fn [k, v] -> {k, v} end)

    %Todo{
      priority: priority,
      creation_date: creation_parsed,
      text: todotxt_string,
      projects: tags,
      contexts: contexts,
      additional_tags: additional_tags
    }
  end

  def parse_file_contents(file_content_str) when is_binary(file_content_str) do
    file_content_str
    |> String.split("\n")
    # remove empty lines
    |> Enum.reject(fn line -> String.trim(line) == "" end)
    |> Enum.map(&from_string(&1))
  end
end

defmodule TodotxtDeadlineNotify.TodoUtils do
  @doc """
  Shifts naive datetime to the same day, but at 'morning_time'
  """
  def in_the_morning(datetime, morning_time) do
    case NaiveDateTime.new(
           datetime.year,
           datetime.month,
           datetime.day,
           morning_time[:hour],
           morning_time[:minute],
           datetime.second
         ) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

  @doc """
  Shfits naive datetime to the previous day, at 'night_time'
  """
  def for_prev_day(datetime, night_time) do
    yesterday =
      datetime
      # subtract a day
      |> NaiveDateTime.add(-86400, :second)

    case NaiveDateTime.new(
           yesterday.year,
           yesterday.month,
           yesterday.day,
           night_time[:hour],
           night_time[:minute],
           yesterday.second
         ) do
      {:ok, datetime} ->
        datetime

      _ ->
        nil
    end
  end

  def has_deadline?(todo) do
    Map.has_key?(todo.additional_tags, "deadline")
  end

  @doc """
  Parse the timezone from the string format to a datetime
  """
  def parse_deadline(todo) do
    if has_deadline?(todo) do
      # parses into naive datetime value
      naive_parsed_time =
        Timex.parse!(todo.additional_tags["deadline"], "%Y-%m-%d-%H-%M", :strftime)

      %{todo | additional_tags: Map.put(todo.additional_tags, "deadline", naive_parsed_time)}
    else
      todo
    end
  end

  @doc """
  Find out when this todo has to be notified for. Assumes the deadline is already parsed
  Returns a todo with the reminders: key on the struct updated

  the times for when to notify are configured in config/config.exs
  config/config.exs
  """
  def get_notification_times(todo, time_morning, time_night) do
    if not has_deadline?(todo) do
      todo
    else
      deadline = todo.additional_tags["deadline"]

      reminders =
        [
          # current day notification
          in_the_morning(deadline, time_morning),
          # previous day noficiation
          if todo.priority == "(A)" or todo.priority == "(B)" do
            for_prev_day(deadline, time_night)
          else
            nil
          end,
          # before the deadline is due notification
          case todo.priority do
            "(A)" ->
              NaiveDateTime.add(deadline, -120 * 60, :second)

            "(B)" ->
              NaiveDateTime.add(deadline, -60 * 60, :second)

            "(C)" ->
              NaiveDateTime.add(deadline, -30 * 60, :second)

            _ ->
              nil
          end
        ]
        |> Enum.reject(&is_nil/1)

      %{todo | reminders: reminders}
    end
  end
end
