# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/execute_code'

RSpec.describe 'Instrumentation hooks' do
  it 'emits start/end events for execute_code' do
    events = []
    logger = proc { |event, payload| events << [event, payload] }
    CodeSandboxMcp::Tools::ExecuteCode.on_instrumentation(logger)

    CodeSandboxMcp::Tools::ExecuteCode.call(language: 'python', code: 'print("x")')

    names = events.map(&:first)
    expect(names).to include('execute_start', 'execute_end')
    end_payload = events.find { |e| e.first == 'execute_end' }&.last
    expect(end_payload).to include(:exit_code)
  ensure
    # reset handler to avoid affecting other tests
    CodeSandboxMcp::Tools::ExecuteCode.on_instrumentation(nil)
  end
end
