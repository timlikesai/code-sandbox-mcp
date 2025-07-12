# frozen_string_literal: true

# Coverage setup
if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                   SimpleCov::Formatter::HTMLFormatter,
                                                                   SimpleCov::Formatter::Console
                                                                 ])

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/backup/'
    minimum_coverage 90
    minimum_coverage_by_file 80
  end
end

require 'rspec'
require 'pry'
require 'timecop'
require 'webmock/rspec'
require_relative '../lib/code_sandbox_mcp'

# Disable external requests in tests
WebMock.disable_net_connect!(allow_localhost: true)

# Support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  # Metadata behavior
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Filtering
  config.filter_run_when_matching :focus
  config.run_all_when_everything_filtered = true

  # Output
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.default_formatter = 'doc' if config.files_to_run.one?

  # Randomization
  config.order = :random
  Kernel.srand config.seed

  # Profiling
  config.profile_examples = 10

  # Warnings
  config.warnings = true
  config.disable_monkey_patching!

  # Hooks
  config.before(:suite) do
    # Ensure clean state
  end

  config.after do
    # Reset any global state
    Timecop.return
  end

  # Include helpers
  config.include CodeSandboxMcp::SpecHelpers if defined?(CodeSandboxMcp::SpecHelpers)
end
