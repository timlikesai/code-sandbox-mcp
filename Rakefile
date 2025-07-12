# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# RSpec task with coverage enabled by default
RSpec::Core::RakeTask.new(:spec) do |_t|
  ENV['COVERAGE'] = 'true'
end

# RuboCop task
RuboCop::RakeTask.new

# Reek task
desc 'Run reek code smell detector'
task :reek do
  sh 'bundle exec reek'
end

# Security audit task
desc 'Run bundler-audit security check'
task :audit do
  sh 'bundle exec bundler-audit check --update'
end

# All quality checks
desc 'Run all code quality checks'
task quality: %i[spec rubocop reek audit]

# Docker tasks
namespace :docker do
  desc 'Build test Docker image'
  task :build_test do
    sh 'docker compose build code-sandbox-test'
  end

  desc 'Build production Docker image'
  task :build do
    sh 'docker compose build code-sandbox'
  end

  desc 'Build all Docker images'
  task build_all: %i[build_test build]

  desc 'Run tests in Docker container'
  task test: :build_test do
    puts '🧪 Running tests in Docker container...'
    sh 'docker compose run --rm code-sandbox-test bundle exec rspec'

    puts '✅ Running code quality checks...'
    sh 'docker compose run --rm code-sandbox-test bundle exec rubocop'
    sh 'docker compose run --rm code-sandbox-test bundle exec reek'
    sh 'docker compose run --rm code-sandbox-test bundle exec bundler-audit check'

    puts '🎉 All tests and quality checks passed!'
  end

  desc 'Open shell in test container'
  task shell: :build_test do
    sh 'docker compose run --rm code-sandbox-test bash'
  end
end

# Default task
task default: %i[spec rubocop reek]
