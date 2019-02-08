class Stingy::OperationIndexerJob
  STINGY_OP_ID = 'stingy'
  OPT_IN_KEY = 'opt_in'
  
  # This method looks for the following custom_json:
  # 
  # Opt-in: https://app.steemconnect.com/sign/custom-json?id=stingy&json=%7B%22opt_in%22%3A%20true%7D
  # 
  # {
  #   "required_auths": [],
  #   "required_posting_auths": ["account_name"],
  #   "id": "stingy",
  #   "json": "{\"opt_in\": true}"
  # }
  # 
  # Note, the first block with opt-in is: 29983053
  # 
  # Opt-out: https://app.steemconnect.com/sign/custom-json?id=stingy&json=%7B%22opt_in%22%3A%20false%7D
  # 
  # {
  #   "required_auths": [],
  #   "required_posting_auths": ["account_name"],
  #   "id": "stingy",
  #   "json": "{\"opt_in\": false}"
  # }
  # 
  # Note, the first block with opt-out is: 29983652
  def perform
    stream = Steem::Stream.new
    options = {
      at_block_num: (Stingy::State.latest_block_num || 0) + 1,
      types: :custom_json_operation
    }
    
    puts "Resuming from latest block number: #{Stingy::State.latest_block_num} ..."
    
    stream.operations(options) do |op, _trx_id, block_num|
      if Stingy::State.latest_block_num < block_num
        Stingy::State.latest_block_num = block_num
      end
      
      custom_json_operation = op.value
      id = custom_json_operation.id
      
      # Only work with custom_json_operation.id == 'stingy'
      next unless id == STINGY_OP_ID
      
      auths = custom_json_operation.required_auths
      auths += custom_json_operation.required_posting_auths
      
      # Work with any auths.
      next if auths.empty?
       
      payload = JSON[custom_json_operation.json] rescue next
      
      # Only deal with Hash.
      next unless payload.instance_of? Hash
      
      # opt-in/opt-out events
      if payload.key? OPT_IN_KEY
        auths.each do |name|
          user = Stingy::User.find_or_create_by(name: name)
          
          if !!payload[OPT_IN_KEY]
            # Note, we could use the trx_id timestamp or just the wall clock.
            # It doesn't really matter because the timing of when the scripts
            # run is non-consensus.  The opt-in/opt-out events should just
            # happen before the next payout.
            user.opt_in_at = Time.now
          else
            user.opt_in_at = nil
          end
        
          user.save
        
          puts "#{user.name} opt-in: #{user.opt_in?}"
        end
      end
    end
  end
end
