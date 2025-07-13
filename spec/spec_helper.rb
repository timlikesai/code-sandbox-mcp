# frozen_string_literal: true

if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.coverage_dir ENV.fetch('COVERAGE_DIR', 'coverage')

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

WebMock.disable_net_connect!(allow_localhost: true)

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

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.run_all_when_everything_filtered = true

  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  config.profile_examples = 10

  config.warnings = true
  config.disable_monkey_patching!

  config.after do
    Timecop.return
  end

  config.include CodeSandboxMcp::SpecHelpers if defined?(CodeSandboxMcp::SpecHelpers)
end
