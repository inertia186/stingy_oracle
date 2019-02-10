require 'bundler/gem_tasks'
require 'rake/testtask'
require 'stingy'
require 'standalone_migrations'
require 'tty-markdown'
require 'highline'

StandaloneMigrations::Tasks.load_tasks

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test

task :console do
  exec 'irb -r stingy -I ./lib'
end

task :op_indexer do
  job = Stingy::OperationIndexerJob.new
  job.perform
end

task :post_indexer do
  job = Stingy::PostIndexerJob.new
  job.perform
end

task :posts, [:payout_applied, :limit] do |t, args|
  payout_applied = (args[:payout_applied] || 'true') == 'true'
  # Getting more than 100 is probably a bad idea because the current median
  # price and recent claims are not relevant on historical posts.
  limit = (args[:limit] || '100').to_i
  posts = Stingy::Post.stingy_payout_applied(payout_applied).limit(limit)
  
  exit(0) if posts.none?
  
  posts_count = posts.count
  output = []
  output << '| Payout | Link | Upvote Value | Overflag |'
  output << '|-|-|-:|-|'

  output += posts.order(payout_at: :desc).reverse.map do |p|
    payout_at = p.payout_at.getlocal.strftime('%F %l:%M %p')
    upvote_value = p.estimated_value(:upvote_rshares)
    overflag_value = p.estimated_value(:downvote_rshares) - upvote_value
    upvote_value = '%.3f SBD' % upvote_value
    overflag_value = '%.3f SBD' % overflag_value
    
    "| #{payout_at} | https://steemit.com/#{p.slug} | #{upvote_value} | #{overflag_value} |"
  end
  
  puts TTY::Markdown.parse output.join("\n"), width: 288
  
  exit(posts_count)
end

task :report do |t, args|
  users = Stingy::User.opt_in
  posts = Stingy::Post.stingy_payout_applied(false)
  users_pending_payout = users.pluck(:name)
  users_pending_payout = users_pending_payout & posts.map(&:downvoters).flatten.uniq
  
  puts "Opt-in users: %d" % users.count
  puts "Pending payout: %d (users: %d)" % [posts.count, users_pending_payout.size]
end

task :payout, [:limit] do |t, args|
  limit = (args[:limit] || '-1').to_i
  pending = Stingy::Post.stingy_payout_applied(false)
  pending = pending.limit(limit) unless limit == -1
  
  abort 'Nothing to pay.' if pending.none?
  
  puts "About to payout: #{pending.count}"
  wif = if !!ENV['ACTIVE_WIF']
    ENV['ACTIVE_WIF']
  else
    cli = HighLine.new
    cli.ask 'Steem Active WIF:' do |q|
      q.echo = '*'
    end
  end
  
  abort 'WIF not supplied.' unless wif.present?
  
  pending.find_each do |post|
    post.apply_stingy_payout!(wif: wif)
    puts post.errors.messages if post.errors.any?
  end
end

task :update_url do |t|
  wif = if !!ENV['ACTIVE_WIF']
    ENV['ACTIVE_WIF']
  else
    cli = HighLine.new
    cli.ask 'Steem Active WIF:' do |q|
      q.echo = '*'
    end
  end
  
  abort 'WIF not supplied.' unless wif.present?
  
  custom_json = {
    required_auths: ['inertia'],
    required_posting_auths: [],
    id: Stingy::STEEM_ENGINE_OP_ID,
    json: {
      contractName: 'tokens',
      contractAction: 'updateUrl',
      contractPayload: {
        symbol: Stingy::STEEM_ENGINE_TOKEN_SYMBOL,
        url: 'https://steemit.com/steemengine/@inertia/stingy-token-powered-by-steem-engine'
      }
    }.to_json
  }
  
  builder = Steem::TransactionBuilder.new(wif: wif)
  builder.put(custom_json: custom_json)
  trx = builder.transaction
  api = Steem::CondenserApi.new
  result = api.broadcast_transaction_synchronous(trx)
  
  puts result
end
