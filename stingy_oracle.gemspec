# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stingy/version'

Gem::Specification.new do |spec|
  spec.name = 'stingy'
  spec.version = Stingy::VERSION
  spec.authors = ['Anthony Martin (inertia)']
  spec.email = ['stingy@martin-studio.com']

  spec.summary = %q{STINGY Token Oracle}
  spec.description = %q{Predict a particular post will be downvoted to zero payout.}
  spec.homepage = 'https://github.com/inertia186/stingy_oracle'
  spec.license = 'CC0-1.0'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 12.1', '>= 12.1.0'
  spec.add_development_dependency 'rb-readline', '~> 0.5', '>= 0.5.5'
  spec.add_development_dependency 'pry', '~> 0.12', '>= 0.12.2'
  spec.add_development_dependency 'highline', '~> 2.0', '>= 2.0.1'
    
  spec.add_dependency 'activerecord', '>= 4', '< 6'
  spec.add_dependency 'standalone_migrations', '~> 5.2', '>= 5.2.6'
  spec.add_dependency 'hivemind-ruby', '~> 0.1', '>= 0.1.0'
  spec.add_dependency 'steem-mechanize', '~> 0.0', '>= 0.0.5'
  spec.add_dependency 'tty-markdown', '~> 0.5', '>= 0.5.0'
end
