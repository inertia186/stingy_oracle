require 'active_record'
require 'stingy/version'
require 'stingy/jobs/operation_indexer_job'
require 'stingy/jobs/post_indexer_job'
require 'stingy/models/base'
require 'stingy/models/state'
require 'stingy/models/post'
require 'stingy/models/user'
require 'hive'
require 'steem'

Bundler.require

module Stingy
  STINGY_ENV = ENV.fetch('STINGY_ENV', 'development')
  
  case STINGY_ENV
  when'production'
    STEEM_ENGINE_OP_ID = 'ssc-mainnet1'
    STEEM_ENGINE_TOKEN_SYMBOL = 'STINGY'
  when 'staging'
    # qa (testnet)
    STEEM_ENGINE_OP_ID = 'ssc-00000000000000000002'
    STEEM_ENGINE_TOKEN_SYMBOL = 'STINGY'
  else
    # qa (testnet)
    STEEM_ENGINE_OP_ID = 'ssc-00000000000000000002'
    STEEM_ENGINE_TOKEN_SYMBOL = 'SPAMMY'
  end
  
  require 'stingy/agent'
end

hive_database_url = ENV['DATABASE_URL']

if hive_database_url.present?
  database_uri = URI.parse(hive_database_url)
  database = database_uri.path.split('/').last

  HIVE_DATABASE = {
    adapter: database_uri.scheme,
    host: ENV.fetch('HIVE_HOST', database_uri.host),
    port: ENV.fetch('HIVE_PORT', database_uri.port),
    username: ENV.fetch('HIVE_USERNAME', database_uri.user),
    password: ENV.fetch('HIVE_PASSWORD', database_uri.password),
    database: ENV.fetch('HIVE_DATABASE', database),
    timeout: 60
  }
  
  Hive::Base.establish_connection(HIVE_DATABASE)
end

Stingy::Base.establish_connection({
  adapter: 'postgresql',
  database: "stingy_#{Stingy::STINGY_ENV == 'staging' ? 'development' : Stingy::STINGY_ENV}",
  host: 'localhost',
  port: 5432,
  timeout: 60
})
