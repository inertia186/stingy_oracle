# This is the block before the first stingy op.
Stingy::State.create(latest_block_num: 29983052)

unless Stingy::STINGY_ENV == 'production'
  # These are test users that frequently qualify for STINGY rewards.  Only set
  # these as opt-in during tests.

  Stingy::User.create(name: 'steemcleaners', opt_in_at: Time.now)
  Stingy::User.create(name: 'spaminator', opt_in_at: Time.now)
end
