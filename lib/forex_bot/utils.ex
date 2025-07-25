defmodule ForexBot.Utils do
  @compile {:inline, [today_id: 0, localtime_now: 0]}

  @spec datetime_id(DateTime.t()) :: String.t()
  def datetime_id(date) do
    date
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "")
  end

  @spec localtime_now() :: DateTime.t()
  def localtime_now, do: DateTime.now("Asia/Ho_Chi_Minh") |> elem(1)

  @spec today_id() :: String.t()
  def today_id, do: localtime_now() |> datetime_id()
end
