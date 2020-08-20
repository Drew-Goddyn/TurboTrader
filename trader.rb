require 'alpaca/trade/api'
require 'pry'
require 'colorize'
require 'action_view'
require 'action_view/helpers'
require "alphavantagerb"

Alpaca::Trade::Api.configure do |config|
  # config.endpoint = 'https://paper-api.alpaca.markets'
  config.key_id = ''
  config.key_secret = 's'
end

# Kucoin.configure do |config|
#   config.key          =   "5f35b7445b13f0000649853b"
#   config.secret       =   "1cca491c-675e-47a4-8d88-32c08087875d"
#   config.passphrase   =   "kryptonite"
# end

class Trader
  include ActionView::Helpers::DateHelper

  attr_reader :position, :symbol, :percentage_diff, :current_price, :total_profit
  attr_accessor :mode, :last_trade_price, :last_trade_at, :last_sell_order, :last_buy_order

  DIP_THRESHOLD = -0.1
  UPWARD_TREND_THRESHOLD = 1.0

  PROFIT_THRESHOLD = 0.1
  STOP_LOSS_THRESHOLD = -1.0

  def initialize(symbol)
    @symbol = symbol.to_sym
    # refresh_position
    @mode = position&.qty.nil? ? :buy : :sell
    # # @last_trade_value = position&.avg_entry_price.to_d * position&.qty
    @last_trade_at = 0
    @last_trade_price = position.nil? ? 0 : position.avg_entry_price.to_d
    @total_profit = 0
  end

  def position
      @position ||= refresh_position
  end

  def refresh_position
    @position = client.position(symbol: symbol)
  rescue Alpaca::Trade::Api::NoPositionForSymbol
    nil
  end

  def client
    @client ||= Alpaca::Trade::Api::Client.new
  end


  def trade
    loop do
      puts "-------------------------------------"
      refresh_position
      puts position_details
      case mode
      when :sell
        if sell?
          puts "[ Seems like a good time to sell... ]"
          self.last_sell_order = place_order(:sell, qty: 1)
          calculate_profit
          self.last_trade_at = Time.now
          self.last_trade_price = last_sell_order.filled_avg_price.to_d
          self.mode = :buy
        end
      when :buy
        if buy?
          puts "* Looks like a good time to buy... *"
          self.last_buy_order = place_order(:buy, qty: 1)
          self.last_trade_at = Time.now
          self.last_trade_price = last_buy_order.filled_avg_price.to_d
          self.mode = :sell
        end
      end

      sleep 4
    end
  end

  def calculate_profit
      bought_value = last_buy_order.filled_qty.to_d * last_buy_order.filled_avg_price.to_d
      sell_value =  last_sell_order.filled_qty.to_d * last_sell_order.filled_avg_price.to_d
      @total_profit += (sell_value - bought_value)
  end

  def sell?
    profitable = percentage_diff >= PROFIT_THRESHOLD
    runaway = percentage_diff <= STOP_LOSS_THRESHOLD

    if profitable || runaway
      puts "* Reason: Profitable. Percentage diff: #{percentage_diff.to_f.round(2)}, PROFIT_THRESHOLD: #{PROFIT_THRESHOLD}" if profitable
      puts "* Runaway: runaway. Percentage diff: #{percentage_diff.to_f.round(2)}, STOP_LOSS_THRESHOLD: #{STOP_LOSS_THRESHOLD}" if runaway
      true
    else
      false
    end
  end

  def buy?
    first_buy = position.nil?

    if first_buy
      puts "* Should buy first stock... *"
      return true
    end

     profitable = percentage_diff <= DIP_THRESHOLD
     runaway = percentage_diff >= UPWARD_TREND_THRESHOLD

    if profitable || runaway
      puts "* Reason: Profitable. Percentage diff: #{percentage_diff.to_f.round(2)}, UPWARD_TREND_THRESHOLD: #{UPWARD_TREND_THRESHOLD}" if profitable
      puts "* Runaway: runaway. Percentage diff: #{percentage_diff.to_f.round(2)}, DIP_THRESHOLD: #{DIP_THRESHOLD}" if runaway
      true
    else
      false
    end
  end

  def current_price
    return 0 unless position

    position.current_price.to_d
  end

  def percentage_diff
    return 0 unless position

    (current_price - last_trade_price) / last_trade_price * 100
  end

  def relative_profit
    return 0 unless position

    (average_difference / total_value) * 100
  end

  def average_difference
    return 0 unless position

    position.market_value.to_d - (position.avg_entry_price.to_d * position.qty.to_d)
  end

  def total_value
    return 0 unless position

    position.qty.to_d * position.avg_entry_price.to_d
  end

  def position_details
    <<~START
      Timestamp: #{Time.now}
      Symbol: #{symbol}
      Total Profit: #{total_profit.to_f.round(5)}
      Currently owned: #{position&.qty}
      Mode: #{mode == :buy ? mode.to_s.upcase.blue : mode.to_s.upcase.red}
      Last traded: #{time_ago_in_words(last_trade_at) } ago
      Last trade price: $#{last_trade_price.to_f.round(2)}
      Current price: #{current_price.to_f.round(4)}
      Average profit: $#{average_difference.to_f.round(4)}
      Percentage Diff #{percentage_diff.to_f.round(4)}%
    START
  end

  def last_trade_details
    <<~MSG
    Last traded at: #{last_trade}
    MSG
  end

  def place_order(side, qty: nil)
    puts "* #{side}ing #{qty} stocks of #{symbol} *"
    qty = qty || position&.qty

    order_id = client.new_order(symbol: symbol, qty: qty, side: side, type: :market, time_in_force: :day).id

    raise "order failed" unless order_id
    filled_order = poll_for_filled_order(order_id)


    filled_order
  end

  def poll_for_filled_order(order_id)
    loop do
      puts "* Checking if order filled *"
      order =  client.order(id: order_id)
      break order if order.filled_at

      sleep 5
    end

    puts "* Order filled *"
    client.order(id: order_id)
  end

  def sell
    qty = position.qty.filled_average_price
  end
end


$details

Trader.new($ARGV[0]).trade

# threads = [:AAPL, :MSFT, :TSLA, :GOOGL, :AMZN].map do |symbol|
#     Thread.new { Trader.new(symbol: symbol).trade }
# end

# threads.each(&:join)
