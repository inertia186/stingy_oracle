class Stingy::State < Stingy::Base
  self.table_name = :state
  
  def self.latest_block_num
    limit(1).last.latest_block_num
  end
  
  def self.latest_block_num=(latest_block_num)
    rec = limit(1).last || new
    rec.latest_block_num = latest_block_num
    rec.save
  end

  def self.latest_payout_at
    limit(1).any? ? limit(1).last.latest_payout_at : nil
  end
  
  def self.latest_payout_at=(latest_payout_at)
    rec = limit(1).last || new
    rec.latest_payout_at = latest_payout_at
    rec.save
  end
  
  def self.latest_avg_rshares
    limit(1).any? ? limit(1).last.latest_avg_rshares : nil
  end
  
  def self.latest_avg_rshares=(latest_avg_rshares)
    rec = limit(1).last || new
    rec.latest_avg_rshares_at = Time.now
    rec.latest_avg_rshares = latest_avg_rshares
    rec.save
  end
  
  def self.latest_avg_rshares_at
    limit(1).any? ? limit(1).last.latest_avg_rshares_at : nil
  end
  
  def self.latest_avg_rshares_at=(latest_avg_rshares_at)
    rec = limit(1).last || new
    rec.latest_avg_rshares_at = latest_avg_rshares_at
    rec.save
  end
  
  def self.refresh_latest_avg_rshares?
    latest_avg_rshares_at.nil? || Time.now - latest_avg_rshares_at > 300
  end
end
