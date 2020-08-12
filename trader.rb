require 'alpaca/trade/api'
require 'pry'

# Alpaca::Trade::Api.configure do |config|
#   config.endpoint = 'https://paper-api.alpaca.markets'
#   config.key_id = 'xxxxxxxx'
#   config.key_secret = 'xxxxx'
# end

client =  Alpaca::Trade::Api::Client.new
binding.pry

x=1
