defmodule ForexCalendar.Utils do
  @spec datetime_id(DateTime.t()) :: String.t()
  def datetime_id(date) do
    date
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "")
  end

  @spec localtime_now() :: DateTime.t()
  def localtime_now, do: DateTime.utc_now() |> DateTime.shift(hour: 7)
end
