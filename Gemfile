# frozen_string_literal: true

source 'https://rubygems.org'

# Core dependencies
gem 'json', '~> 2.15'
gem 'mcp', '~> 0.5.0'

group :development, :test do
  # Testing
  gem 'rspec', '~> 3.13'
  gem 'simplecov', '~> 0.22', require: false
  gem 'simplecov-console', '~> 0.9'

  # Code quality
  gem 'rubocop', '~> 1.81'
  gem 'rubocop-performance', '~> 1.26'

  # Security
  gem 'bundler-audit', '~> 0.9'

  # Development tools
  gem 'pry', '~> 0.14'
  gem 'pry-byebug', '~> 3.10'
  gem 'rake', '~> 13.1'

  # Documentation
  gem 'yard', '~> 0.9'
end

group :test do
  # Test helpers
  gem 'timecop', '~> 0.9'
  gem 'webmock', '~> 3.26'
end
