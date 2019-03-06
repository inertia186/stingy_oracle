class Stingy::PostIndexerJob
  TRENDING_SEGMENT = 3
  
  def perform(options = {pretend: false, relative_days: 0, payout: 0.0})
    pretend = !!options[:pretend]
    relative_days = options[:relative_days] || 0
    payout = options[:payout] || 0.0
    
    pretend = true if relative_days != 0
    pretend = true if payout != 0.0
    
    if !!pretend
      puts 'Not performing post index (pretend mode) ...'
    else
      puts 'Performing post index ...'
    end
    
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
    
    payout_start_at = Stingy::State.latest_payout_at || 1.day.ago
    payout_start_at += relative_days.days if relative_days < 0
    payout_end_at = Time.now
    payout_end_at += relative_days.days if relative_days > 0
    
    if relative_days == 0
      puts "Looking for new posts since: #{payout_start_at}"
    else
      puts "Looking for new posts between #{payout_start_at} and #{payout_end_at}"
    end
    
    posts = if payout < 0.001
      # We want the payout zero.
      Hive::PostsCache.where('payout = 0').where("rshares < 0")
    else
      # We want the payout in the range of zero and n.
      Hive::PostsCache.where('payout BETWEEN 0 AND ?', payout)
    end
    
    posts = if relative_days > 0
      # Not paid yet (peeking into the future).
      posts.where("is_paidout = 'f'")
    else
      # Paid in the past.
      posts.where("is_paidout = 't'")
    end
    
    # We want some downvotes.
    posts = posts.where("total_votes > up_votes").
      # We only need these fields in the result.
      select(:post_id, :votes, :payout_at).
      # Set a window in the past to work from.
      where("payout_at BETWEEN ? AND ?", payout_start_at, payout_end_at).
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
        
        unless !!pretend
          Stingy::Post.create(params)
          
          if Stingy::State.latest_payout_at < p.payout_at
            Stingy::State.latest_payout_at = p.payout_at
          end
        end
      end
      
      unless !!pretend
        if Stingy::State.latest_payout_at.nil? || Stingy::State.latest_payout_at < payout_end_at
          Stingy::State.latest_payout_at = payout_end_at
        end
      end
    end
  end
end
