require 'steem'

class Stingy::Post < Stingy::Base
  validates_uniqueness_of :permlink, scope: :author
  
  DEFAULT_STINGY_PAYOUT_AMOUNT = 1.0
  
  scope :stingy_payout_applied, lambda { |stingy_payout_applied|
    where(stingy_payout_applied: stingy_payout_applied)
  }
  
  def slug
    "@#{author}/#{permlink}"
  end
  
  def hive_post
    Hive::Post.find_by_author_and_permlink(author, permlink)
  end
  
  def vote_log
    @vote_log ||= self.class.database_api.find_votes(author: author, permlink: permlink) do |result|
      result.votes.sort_by do |v|
        v.last_update
      end
    end
  end
  
  def upvotes; vote_log.select{ |v| v.rshares.to_i > 0 }; end
  def downvotes; vote_log.select{ |v| v.rshares.to_i < 0 }; end
  def unvotes; vote_log.select{ |v| v.rshares.to_i == 0 }; end
    
  def upvoters; upvotes.map(&:voter); end
  def downvoters; downvotes.map(&:voter); end
  def unvoters; unvotes.map(&:voter); end
  
  def downvote_ratios
    opt_in_downvotes = downvotes.select do |v|
      Stingy::User.opt_in.where(name: v.voter).any?
    end
    
    total_rshares = opt_in_downvotes.map{ |v| v.rshares.to_f.abs }.sum
    
    opt_in_downvotes.map do |v|
      [v.voter, v.rshares.to_f.abs / total_rshares]
    end.to_h
  end
  
  def apply_stingy_payout!(options = {})
    return if stingy_payout_applied?
    
    transaction do
      op_values = []
      original_payout = remaining_payout = stingy_payout_amount
      
      downvote_ratios.each do |user_name, ratio|
        break if remaining_payout < 0.00000001
        
        if !!user = Stingy::User.opt_in.find_by_name(user_name)
          stingy_payout_share = original_payout * ratio
          decrement(:stingy_payout_amount, stingy_payout_share)
          remaining_payout -= stingy_payout_share
          save
          
          if stingy_payout_share >= 0.00000001
            amount = stingy_payout_share.round(8)
            user.increment(:stingy_payout_amount, amount) # Just for our records.
            user.save
            
            json = {
              contractName: "tokens",
              contractAction: "issue",
              contractPayload: {
                symbol: Stingy::STEEM_ENGINE_TOKEN_SYMBOL,
                to: user.name,
                quantity: amount,
                memo: "@#{author}/#{permlink}"
              }
            }
            
            current_op_len = op_values.last.to_json.size rescue 0
            current_op_len += json.to_json.size
            
            if op_values.empty? || current_op_len > 1500
              op_values << {
                required_auths: ['inertia'],
                required_posting_auths: [],
                id: Stingy::STEEM_ENGINE_OP_ID
              }
            end
            
            # Most of the time, there will only be one op.  But because the op
            # might have more than one payment, we use an array of actions in
            # the json payload, which steem-engine supports.  If the json
            # payload gets too large, *then* we might issue more than one
            # transaction, but this shouldn't be common.

            op_values.last[:json] ||= []
            op_values.last[:json] << json
          end
        end
      end
      
      if op_values.any?
        puts "Paying #{op_values.size} author(s) ..."
        
        op_values.each_with_index do |v, i|
          op_values[i][:json] = v[:json].to_json
        end
        
        op_values.each do |value|
          builder = Steem::TransactionBuilder.new(wif: options[:wif])
          puts value.to_json
          builder.put(custom_json: value)
          trx = builder.transaction
          api = Steem::CondenserApi.new
          result = api.broadcast_transaction_synchronous(trx)
          puts result
        end
      end
      
      update_attribute(:stingy_payout_applied, true)
    end
  end
  
  def estimated_value(rshares)
    self.class.condenser_api.get_reward_fund('post') do |fund|
      recent_claims = fund.recent_claims.to_f
      reward_balance = fund.reward_balance.to_f
      
      self.class.condenser_api.get_current_median_history_price do |price|
        sbd_median_price = price.base.to_f / price.quote.to_f
        send(rshares) / recent_claims * reward_balance * sbd_median_price
      end
    end
  end
end
