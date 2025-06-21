defmodule Bot.Event do
  defstruct [
    :time,
    :currency,
    :actual,
    :event_name,
    :impact,
    :forecast,
    :previous,
    :event_id,
    :event_url
  ]
end
