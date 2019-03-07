require 'bundler/gem_tasks'
require 'rake/testtask'
require 'stingy'
require 'standalone_migrations'
require 'tty-markdown'
require 'highline'
require 'haml'

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

task :health_check do
  latest_block_num = Stingy::State.latest_block_num
  api = Steem::DatabaseApi.new
  
  api.get_dynamic_global_properties do |dgpo|
    time = Time.parse(dgpo.time + 'Z')
    time_diff = Time.now - time
    block_diff = dgpo.head_block_number - latest_block_num
    
    puts "Current blockchain time: #{time} (#{time_diff} seconds from now)"
    puts "Distance from head block_num: #{block_diff} (#{block_diff * 3} seconds behind)"
    
    exit(-1) if block_diff > 42 # twice irreversible
    exit(0)
  end
end

task :post_indexer, [:pretend, :relative_days, :payout] do |t, args|
  pretend = (args[:pretend] || 'false') == 'true'
  relative_days = (args[:relative_days] || '0').to_i
  payout = (args[:payout] || '0.0').to_f
  
  pretend = true if relative_days != 0
  pretend = true if payout != 0.0
  
  job = Stingy::PostIndexerJob.new
  job.perform(pretend: pretend, relative_days: relative_days, payout: payout)
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
    
    "| #{payout_at} | `https://steemit.com/#{p.slug}` | #{upvote_value} | #{overflag_value} |"
  end
  
  puts TTY::Markdown.parse output.join("\n"), width: 288
  
  exit(posts_count)
end

task :report, [:render_markdown] do |t, args|
  render_markdown = (args[:render_markdown] || 'false') == 'true'
  posts = Stingy::Post.where("created_at BETWEEN ? AND ?", 30.days.ago, Time.now)
  pending_posts = posts.stingy_payout_applied(false)
  symbol = Stingy::STEEM_ENGINE_TOKEN_SYMBOL
  agent = Stingy::Agent.new
  token = agent.token_details(symbol)
  template = File.read('support/report.md.haml')
  haml_engine = Haml::Engine.new(template)
  flags = {}
  
  posts.find_each do |post|
    post.downvoters.each do |flagger|
      flags[flagger] ||= 0
      flags[flagger] += 1
    end
  end

  users = Stingy::User.where(name: flags.keys)
  users_pending_payout = users.pluck(:name)
  users_pending_payout = users_pending_payout & pending_posts.map(&:downvoters).flatten.uniq
  users = users.where.not(stingy_payout_amount: 0.0).
    order(stingy_payout_amount: :desc)
  output = haml_engine.render(binding)
  
  if !!render_markdown
    puts TTY::Markdown.parse output, width: 288
  else
    puts output
  end
  
  puts "\n===\nPending payout: %d (users: %d)" % [pending_posts.count, users_pending_payout.size]
  
  exit(users_pending_payout.size)
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


task :issue, [:amount, :to, :memo] do |t, args|
  amount = (args[:amount] || abort("Amount required.")).to_f
  to = args[:to] || abort("To required.")
  memo = args[:memo] || abort("Memo required.")
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
      contractName: "tokens",
      contractAction: "issue",
      contractPayload: {
        symbol: Stingy::STEEM_ENGINE_TOKEN_SYMBOL,
        to: to,
        quantity: '%.8f' % amount,
        memo: memo
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

task :check_posts_cache do |t|
  after =  Stingy::State.latest_payout_at
  posts = Hive::Post.after(after)
  posts_count = posts.count
  posts_cache = Hive::PostsCache.after(after)
  posts_cache_count = posts_cache.count
  
  if posts_count != posts_cache_count
    puts 'Posts count: %d' % posts_count
    puts 'Posts Cache count: %d' % posts_cache_count
    puts 'Difference: %d' % (posts_count - posts_cache_count)
    
    Arel.sql("CONCAT('@', author, '/', permlink)").tap do |slugs|
      posts_slugs = posts.pluck(slugs)
      posts_cache_slugs = posts_cache.pluck(slugs)
    
      if (extra_posts_cache_slugs = posts_slugs - posts_cache_slugs).any?
        puts "Missing posts:"
        puts extra_posts_cache_slugs.map { |slug| "https://steemit.com/#{slug}"}
      end
      
      if (extra_posts_slugs = posts_cache_slugs - posts_slugs).any?
        puts "Missing posts cache:"
        puts extra_posts_slugs.map { |slug| "https://steemit.com/#{slug}"}
      end
    end
    
    exit(-1)
  end
  
  exit(0)
end
