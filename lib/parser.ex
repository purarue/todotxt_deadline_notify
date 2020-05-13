defmodule TodotxtDeadlineNotify.Todo do
  defstruct id: nil,
            priority: nil,
            creation_date: nil,
            text: "",
            projects: [],
            contexts: [],
            additional_tags: []
end

defmodule TodotxtDeadlineNotify.Parser do
  @moduledoc """
  Parses the todo.txt format into a map
  """
  alias TodotxtDeadlineNotify.Todo

  def from_string(todotxt_string) do
    [todo_id_str | _todo_parts] = String.split(todotxt_string)
    todo_id = case Integer.parse(todo_id_str) do
      {todo_id_int, _} ->
        todo_id_int
      _ ->
        nil
    end


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
      id: todo_id,
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
