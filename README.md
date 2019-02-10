# [STINGY Token Oracle](https://github.com/inertia186/stingy_oracle)

Initial logic based on:

https://steemit.com/steemit/@inertia/feature-request-flag-rewards

In a nutshell, if you can correctly predict a particular post will be downvoted to zero payout, you get a reward.

## TL;DR

First, click the opt-in link:

* [opt-in](https://app.steemconnect.com/sign/custom-json?id=stingy&json=%7B%22opt_in%22%3A%20true%7D)
* [opt-out](https://app.steemconnect.com/sign/custom-json?id=stingy&json=%7B%22opt_in%22%3A%20false%7D)

Go find stuff on Trending and be the first person to flag them.  If you flag something that later ends up getting flagged to zero, you get [STINGY tokens](https://steem-engine.com/?p=history&t=STINGY).

## A Little Deeper

We award STINGY tokens to the earliest voters who downvote a post that would have otherwise been on Trending.  It determines **a)** that a post was going to get a large payout and **b)** was instead downvoted to zero by the time payout arrived.

## Hivemind queries

### To find posts:

* `r = Hive::PostsCache.where("is_paidout = 't' AND payout = 0")`
  * We want the payout zero and paid in the past.
* `r = r.where("total_votes > up_votes")`
  * We want some downvotes.
* `r = r.where("rshares < 0")`
  * But more downvotes than upvotes in rshares.
* `r = r.select(:post_id, :votes)`
  * We only need these fields in the result.
* `r = r.where("payout_at BETWEEN ? AND CURRENT_TIMESTAMP", 1.day.ago)`
  * Set a window in the past to work from.

This gives us `r` to check for upvotes.  For each post in `r`, check if the upvotes rshares would have put the post on Trending.

Say we have 1000 results in `r`.  How many of these have the upvotes that are above the average rshares?  We need to **a)** know what the upvote rshares for each post was apart from the downvotes and **b)** what the current trending rshares average is.

```ruby
posts = []
r.each do |p|
  votes = p.votes.split("\n")
  upvote_rshares = votes.map do |v|
    rshares = v.split(",")[1].to_i
    rshares > 0 ? rshares : 0
  end.sum

  if upvote_rshares > avg_rshares
    # post could have been above the current
    # trending rshares average but got downvoted
    # to zero payout
    
    posts << p
  end
end
```

### To find current trending rshares average.

* `avg_rshares = Hive::PostsCache.where("is_paidout = 'f'")`
  * Only grab posts that have not yet paid
* `avg_rshares = avg_rshares.order(sc_trend: :desc).limit(avg_rshares.count / 3)`
  * Order by the sc_trend field, limit to top third.
* `avg_rshares = avg_rshares.sum(:rshares) / avg_rshares.count`
  * Sum of rshares divided by that third

## Payout

Each post qualifies for 1 STINGY if that post **a)** would have been on Trending, **b)** has instead been downvoted to zero, and **c)** has downvotes from accounts that opt-in.

* If only one account downvotes, that account gets the entire STINGY payout for that post.
  * E.g., the one and only downvote came from Alice and Alice opts into STINGY
* If multiple accounts downvote, only accounts that opt-in qualify for payout.
  * E.g., two downvotes: one came from Alice; Alice opts into STINGY; one came from Bob; Bob does not opt into STINGY
* If multiple opt-in accounts downvote, payout is split by absolute rshares.
  * E.g., both downvotes came from Alice and Bob; Alice and Bob both opt into STINGY
  * The downvoter with the most absolute rshares gets most of the STINGY.
  * Ties prefer the earliest voter.

## Opt-In / Consensus

As mentioned above, only posts that have downvotes from accounts that have opt-in records should be considered in the results.  It might be possible to optimize the query to only process posts that have downvotes from opt-in accounts, but this might not provide much optimization because the votes field in hivemind is a string.

We’re using a non-consensus hivemind database to determine payout.  This is probably ok, but it’s good to keep in mind that this may create some corner cases that aren’t fully specified.

Corner cases, like, extra payouts when there shouldn’t be any or missing payouts.

Since the hivemind database is non-consensus, certain elements like vote order must be queried at payout to determine the true order of votes.  This does not present much of a problem, but does require minimal API access for each payout phase.

Links:

* [opt-in](https://app.steemconnect.com/sign/custom-json?id=stingy&json=%7B%22opt_in%22%3A%20true%7D)
* [opt-out](https://app.steemconnect.com/sign/custom-json?id=stingy&json=%7B%22opt_in%22%3A%20false%7D)

## Gaming The System

One vector that might result in gaming the system is when Eve intentionally downvotes her own post just to farm STINGY.  Say Eve intentionally writes a plagiaristic post, uses a bid-bot, then downvotes her own post.  Later, Alice downvotes it back to zero.  Does Eve qualify for her own downvote prediction?

This is not mitigated by disqualifying the authors from their own posts because they could just as easily use alternate accounts (sybil).

Then again, is this something to worry about or just accept as part of the cost of having STINGY tokens?

Another vector is trailing a stakeholder who is routinely spreading upvotes for low quality posts.  Some stakeholders arbitrarily upvote with almost zero investigation on the validity of a post, only to have anti-plagiarism services downvote moments later.  An observant account could predict this behavior to farm STINGY.

Again, is this kind of thing something to worry about?

One way to mitigate some of these concerns is to only focus on posts that reach enough upvotes that would get very high on trending.  Technically, everything is on trending, if you scroll down enough and the post hasn’t paid out.  That’s why avg_rshares is calculated to the top third of the results, which filters out all posts with 50¢ worth of upvotes.

## Dealing With Unvotes

Let’s say Eve posts plagiarism and buys bid-bot votes.  Alice notices it and downvotes it early, seeking a STINGY payout.  Being that Alice is a STINGY super-star, bid-bots notice Alice’s votes and revoke their votes.  Now Alice will not receive a STINGY payout.  Technically, the post briefly made it to Trending but there’s no simple way to determine this without replaying the blockchain.

This is a win for the platform, but not for Alice.  In this situation, Alice might consider unvoting as well.

---

<center>
<img src="https://i.imgur.com/DqnmWS9.jpg" />
</center>
