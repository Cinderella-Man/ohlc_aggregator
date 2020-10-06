defmodule Temp.Streamer do
  use WebSockex

  require Logger

  defmodule State do
    @enforce_keys [:symbol]
    defstruct [:symbol]
  end

  @stream_endpoint "wss://stream.binance.com:9443/ws/"

  def start_link(symbol) do
    symbol = String.downcase(symbol)
    url = "#{@stream_endpoint}#{symbol}@trade"
    Logger.info("Starting streaming on #{symbol}")
    Logger.debug("#{url}")

    WebSockex.start_link(
      url,
      __MODULE__,
      %State{
        symbol: symbol
      },
      name: :"#{__MODULE__}-#{symbol}"
    )
  end

  def handle_frame({_type, msg}, state) do
    case Jason.decode(msg) do
      {:ok, event} -> process_event(event)
      {:error, _} -> throw("Unable to parse msg: #{msg}")
    end

    {:ok, state}
  end

  def process_event(%{"e" => "trade"} = event) do
    trade_event = %Temp.TradeEvent{
      :event_type => event["e"],
      :event_time => event["E"],
      :symbol => event["s"],
      :trade_id => event["t"],
      :price => event["p"],
      :quantity => event["q"],
      :buyer_order_id => event["b"],
      :seller_order_id => event["a"],
      :trade_time => event["T"],
      :buyer_market_maker => event["m"]
    }

    # Logger.debug(
    #   "Trade event received " <>
    #     "#{trade_event.symbol}@#{trade_event.price}"
    # )

    Temp.Worker.notify(:trade_event, trade_event)
  end
end