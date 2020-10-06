defmodule Temp.Worker do
  use GenServer

  require Logger

  @workers_map %{
    :"worker_#{60}"          => :"worker_#{60 * 5}",
    :"worker_#{60 * 5}"      => :"worker_#{60 * 15}",
    :"worker_#{60 * 15}"     => :"worker_#{60 * 60}", # hour
    :"worker_#{60 * 60}"     => :"worker_#{60 * 60 * 4}", # 4 hours
    :"worker_#{60 * 60 * 4}" => :"worker_#{60 * 60 * 8}", # 8 hours
    :"worker_#{60 * 60 * 8}" => :"worker_#{60 * 60 * 24}" # 8 hours
  }

  defmodule State do
    @enforce_keys [:range, :timeframe]
    defstruct timeframe: nil, range: nil, ohlcs: %{}
  end

  def start_link(range) do
    GenServer.start_link(__MODULE__, range, [name: :"worker_#{range}"])
  end

  def init(range) do
    {:ok, %State{
      timeframe: calculate_timeframe(:os.system_time(:seconds), range),
      range: range
    }}
  end

  def notify(:trade_event, trade_event) do
    GenServer.cast(:worker_60, {:trade_event, trade_event}) 
  end

  def handle_cast(
    {:trade_event, trade_event},
    %{
      timeframe: current_timeframe,
      range: range,
      ohlcs: ohlcs
    } = state
  ) do
    ohlc = convert_to_ohlc(trade_event, range)
    new_timeframe = calculate_timeframe(ohlc.start_time, range)
    new_ohlcs = if current_timeframe == new_timeframe do
      merge_ohlc(ohlc, ohlcs)
    else
      publishData(Map.get(ohlcs, ohlc.symbol), range)
      Map.put(ohlcs, ohlc.symbol, ohlc)
    end

    {:noreply, %{state | timeframe: new_timeframe, ohlcs: new_ohlcs}}
  end

  def handle_cast(
    {:new_ohlc, ohlc},
    %{
      timeframe: current_timeframe,
      range: range,
      ohlcs: ohlcs
    } = state
  ) do
    new_timeframe = calculate_timeframe(ohlc.start_time, range)
    new_ohlcs = if current_timeframe == new_timeframe do
      merge_ohlc(ohlc, ohlcs)
    else
      publishData(Map.get(ohlcs, ohlc.symbol), range)
      Map.put(ohlcs, ohlc.symbol, ohlc)
    end

    {:noreply, %{state | timeframe: new_timeframe, ohlcs: new_ohlcs}}
  end

  # time in seconds
  defp calculate_timeframe(time, range)
    when is_integer(range) and is_integer(time) do
    div(time, range)
  end

  defp convert_to_ohlc(%Temp.TradeEvent{} = trade_event, range) do
    start_time = calculate_start_time(trade_event.event_time, range)
    %Temp.Ohlc{
      symbol: trade_event.symbol,
      start_time: start_time,
      end_time: start_time + range,
      open: trade_event.price,
      high: trade_event.price,
      low: trade_event.price,
      close: trade_event.price
    }
  end

  # timestamp in ms
  defp calculate_start_time(event_time, range) do
    event_time
    |> div(1000)
    |> div(range)
    |> Kernel.*(range)
  end

  defp merge_ohlc(%Temp.Ohlc{} = ohlc, %{} = ohlcs) do
    current_ohlc = Map.get(ohlcs, ohlc.symbol, ohlc)
    new_ohlc = %Temp.Ohlc{
      symbol: ohlc.symbol,
      start_time: ohlc.start_time,
      end_time: ohlc.start_time,
      open: current_ohlc.open,
      high: max(current_ohlc.high, ohlc.high),
      low: min(current_ohlc.low, ohlc.low),
      close: ohlc.close
    }
    Map.put(ohlcs, ohlc.symbol, new_ohlc)
  end

  # when it will start and skip to new timeframe immediately
  defp publishData(nil, _range), do: nil
  defp publishData(%Temp.Ohlc{} = ohlc, range) do
    Logger.info("Worker_#{range} finished timeframe. ohlc: #{inspect(ohlc)}")
    case Map.get(@workers_map, :"worker_#{range}") do
      nil -> nil
      process_name -> 
        Logger.info("Streaming to #{process_name}")
        GenServer.cast(
          process_name,
          {:new_ohlc, ohlc}
        )
    end
  end
end