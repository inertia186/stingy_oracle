class Stingy::PostIndexerJob
  TRENDING_SEGMENT = 3
  
  def perform
    puts "Performing post index ..."
    
    # To find current trending rshares average ...
    avg_rshares = if Stingy::State.refresh_latest_avg_rshares?
      # Only grab posts that have not yet paid
      avg = Hive::PostsCache.where("is_paidout = 'f'")

      count = avg.count / TRENDING_SEGMENT
      avg = avg.order(sc_trend: :desc).limit(count)
      puts "Posts in 1/#{TRENDING_SEGMENT} of pending posts: #{count}"

      avg = avg.sum(:rshares) / count
      puts "Average rshares of 1/#{TRENDING_SEGMENT} pending posts: #{avg}"
      
      Stingy::State.latest_avg_rshares = avg
      
      avg
    else
      Stingy::State.latest_avg_rshares
    end
    
    payout_at = Stingy::State.latest_payout_at || 1.day.ago
    now = Time.now
    
    puts "Looking for new posts since: #{payout_at}"
    
    Hive::PostsCache.
      # We want the payout zero and paid in the past.
      where("is_paidout = 't' AND payout = 0").
      # We want some downvotes.
      where("total_votes > up_votes").
      # But more downvotes than upvotes in rshares.
      where("rshares < 0").
      # We only need these fields in the result.
      select(:post_id, :votes, :payout_at).
      # Set a window in the past to work from.
      where("payout_at BETWEEN ? AND ?", payout_at, now).
      # We can use find_each as long as we don't use limit or order.
      find_each do |p|
      
      # This gives us posts to check for upvotes.  Now we check if the upvotes
      # rshares would have put this post on trending.

      votes = p.votes.split("\n").map do |v|
        v = v.split(",")
        [v[0], v[1].to_i]
      end.sort_by { |v| v[1] }.to_h
      
      # We need to a) know what the upvote rshares for this post was apart from
      # the downvotes and b) what the current trending rshares average is (from
      # avg_rshares).
      
      upvote_rshares = votes.values.map do |rshares|
        rshares > 0 ? rshares : 0
      end.sum

      downvote_rshares = votes.values.map do |rshares|
        rshares < 0 ? rshares : 0
      end.sum.abs # Note, we are storing a positive integer here.
      
      # post could have been above the current
      # trending rshares average but got downvoted
      # to zero payout
      if upvote_rshares > avg_rshares
        puts "Found #{p.post.slug} ..."
        
        top_downvoter = votes.keys.first
        top_upvoter = votes.keys.last
        params = {
          author: p.post.author,
          permlink: p.post.permlink,
          top_upvoter: top_upvoter,
          top_downvoter: top_downvoter,
          upvote_rshares: upvote_rshares,
          downvote_rshares: downvote_rshares,
          payout_at: p.payout_at
        }
        
        Stingy::Post.create(params)
        
        if Stingy::State.latest_payout_at < p.payout_at
          Stingy::State.latest_payout_at = p.payout_at
        end
      end
      
      if Stingy::State.latest_payout_at.nil? || Stingy::State.latest_payout_at < now
        Stingy::State.latest_payout_at = now
      end
    end
  end
end
