defmodule Temp.Ohlc do
  defstruct [
    :symbol,
    :start_time,
    :end_time,
    :open,
    :high,
    :low,
    :close
  ]
end
