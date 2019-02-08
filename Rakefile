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

task :posts, [:limit] do |t, args|
  # Getting more than 100 is probably a bad idea because the current median
  # price and recent claims are not relevant on historical posts.
  limit = (args[:limit] || '100').to_i
  output = []
  output << '| Payout | Link | Upvote Value | Overflag |'
  output << '|-|-|-:|-|'

  output += Stingy::Post.limit(limit).order(payout_at: :desc).reverse.map do |p|
    payout_at = p.payout_at.getlocal.strftime('%F %l:%M %p')
    upvote_value = p.estimated_value(:upvote_rshares)
    overflag_value = p.estimated_value(:downvote_rshares) - upvote_value
    upvote_value = '%.3f SBD' % upvote_value
    overflag_value = '%.3f SBD' % overflag_value
    
    "| #{payout_at} | https://steemit.com/#{p.slug} | #{upvote_value} | #{overflag_value} |"
  end
  
  puts TTY::Markdown.parse output.join("\n"), width: 288
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
