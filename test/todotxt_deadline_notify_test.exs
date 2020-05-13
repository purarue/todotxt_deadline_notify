defmodule TodotxtDeadlineNotifyTest do
  use ExUnit.Case
  alias TodotxtDeadlineNotify.Parser

  test "parses easy todo" do
    todo = Parser.from_string("5 do something at +home")
    assert todo.projects == ["+home"]
    assert todo.creation_date == nil
    assert todo.id == 5
    assert todo.contexts |> Enum.empty?()
    assert todo.additional_tags |> Enum.empty?()
  end

  test "parses complex todo" do
    todo =
      Parser.from_string(
        "3 (B) 2020-05-13 finish elixir  discord notifier +elixir +programming @home deadline:2020-05-14-10-00 for:myself"
      )

    assert todo.id == 3
    assert todo.projects == ["+elixir", "+programming"]
    assert todo.creation_date == ~D[2020-05-13]
    assert todo.contexts == ["@home"]
    assert todo.additional_tags == %{"deadline" => "2020-05-14-10-00", "for" => "myself"}
    assert todo.priority == "(B)"
  end

  test "parses file contents" do
    [first | [second | _rest]] =
      "\n5 do something at +work\n\n3 (B) 2020-05-13 finish elixir  discord notifier +elixir +programming @home deadline:2020-05-14-10-00 for:myself"
      |> Parser.parse_file_contents()

    assert first.projects == ["+work"]
    assert first.creation_date == nil
    assert first.id == 5
    assert first.contexts |> Enum.empty?()
    assert first.additional_tags |> Enum.empty?()

    assert second.id == 3
    assert second.projects == ["+elixir", "+programming"]
    assert second.creation_date == ~D[2020-05-13]
    assert second.contexts == ["@home"]
    assert second.additional_tags == %{"deadline" => "2020-05-14-10-00", "for" => "myself"}
    assert second.priority == "(B)"
  end

  test "parsing id fails" do
    todo = Parser.from_string("do something at +home")
    assert todo.id == nil
  end
end
