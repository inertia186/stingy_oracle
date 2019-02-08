class Stingy::User < Stingy::Base
  scope :opt_in, lambda { |opt_in = true|
    if opt_in
      where("opt_in_at IS NOT NULL")
    else
      where("opt_in_at IS NULL")
    end
  }
  
  def opt_in?
    opt_in_at.present?
  end
  
  def stingy_payout
    '%.8f %s' % [stingy_payout_amount, Stingy::STEEM_ENGINE_TOKEN_SYMBOL]
  end
end
