require 'mechanize'

module Stingy
  class Agent < Mechanize
    CONTRACTS_URL = case Stingy::STINGY_ENV
    when 'production' then 'https://api.steem-engine.com/rpc/contracts'
    when 'staging' then 'https://api.steem-engine.com/rpc/contracts'
    else; 'https://testapi.steem-engine.com/contracts'
    end
    
    POST_HEADERS = {
      'Content-Type' => 'application/json; charset=utf-8',
      'User-Agent' => Stingy::AGENT_ID
    }
    
    def initialize
      super
      
      self.user_agent = Stingy::AGENT_ID
      self.max_history = 0
      self.default_encoding = 'UTF-8'
    end
    
    def uri
      @uri ||= URI.parse(CONTRACTS_URL)
    end
    
    def http_post
      @http_post ||= Net::HTTP::Post.new(uri.request_uri, POST_HEADERS)
    end

    def token_details(token)
      request_body = {
        jsonrpc: "2.0",
        method: :findOne,
        params: {
          contract: :tokens,
          table: :tokens,
          query: {
            symbol: token.to_s
          }
        },
        id: 1
      }.to_json
      
      response = request_with_entity :post, CONTRACTS_URL, request_body, POST_HEADERS
      
      JSON[response.body]["result"]
    end

    def token_balances(token)
      request_body = {
        jsonrpc: "2.0",
        method: :find,
        params: {
          contract: :tokens,
          table: :balances,
          query: {
            symbol: token.to_s
          }
        },
        id: 1
      }.to_json
      
      response = request_with_entity :post, CONTRACTS_URL, request_body, POST_HEADERS
      
      JSON[response.body]["result"]
    end
  end
end
