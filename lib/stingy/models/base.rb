class Stingy::Base < ActiveRecord::Base
  self.abstract_class = true
  
  def self.database_api
    @database_api = Steem::DatabaseApi.new
  end
  
  def self.condenser_api
    @condenser_api = Steem::CondenserApi.new
  end
end
