defmodule TodotxtDeadlineNotify.Notify do
  @doc """
  Send notification to me whenever a deadline is approaching
  """
  def notify(message) when is_bitstring(message) do
    IO.puts("Sending reminder: #{message}")

    # send a message to a discord webhook
    discord_webhook_url = Application.get_env(:todotxt_deadline_notify, :discord_webhook)
    headers = [Accept: "application/json", "Content-Type": "application/json"]

    embed_data = %{
      "embeds" => [
        %{
          "title" => "Reminder",
          "description" => message
        }
      ]
    }

    post_body = Poison.encode!(embed_data)

    case HTTPoison.post(discord_webhook_url, post_body, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        cond do
          status_code > 200 and status_code < 400 ->
            IO.puts("Sent reminder to discord: #{message}")
            :ok

          true ->
            IO.puts(:stderr, "Failed with status #{status_code}: #{body}")
            :error
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect({:error, reason})
        :error
    end
  end
end