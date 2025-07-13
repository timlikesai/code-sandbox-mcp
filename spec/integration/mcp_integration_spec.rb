# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe 'MCP Integration' do
  let(:server) { CodeSandboxMcp::Server.new }

  it 'completes a full MCP session' do
    # Initialize
    init_request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'initialize'
    }

    response = server.handle_request(init_request)
    expect(response[:result][:protocolVersion]).to eq('2024-11-05')

    # Send initialized notification
    initialized_request = {
      'jsonrpc' => '2.0',
      'method' => 'initialized'
    }

    response = server.handle_request(initialized_request)
    expect(response).to be_nil # notifications don't get responses

    # List tools
    list_request = {
      'jsonrpc' => '2.0',
      'id' => 2,
      'method' => 'tools/list'
    }

    response = server.handle_request(list_request)
    expect(response[:result][:tools].size).to eq(2)
    expect(response[:result][:tools].map { |t| t[:name] }).to include('execute_code', 'validate_code')

    # Execute code
    execute_request = {
      'jsonrpc' => '2.0',
      'id' => 3,
      'method' => 'tools/call',
      'params' => {
        'name' => 'execute_code',
        'arguments' => {
          'language' => 'python',
          'code' => 'print("MCP integration test successful!")'
        }
      }
    }

    response = server.handle_request(execute_request)
    expect(response[:result][:isError]).to be false

    content = response[:result][:content]
    stdout_blocks = content.select { |c| c.dig(:annotations, :role) == 'stdout' }
    expect(stdout_blocks.first[:text]).to eq('MCP integration test successful!')
  end

  it 'handles multiple language executions' do
    languages = {
      'python' => 'print("Python works")',
      'ruby' => 'puts "Ruby works"',
      'javascript' => 'console.log("JavaScript works")',
      'bash' => 'echo "Bash works"'
    }

    languages.each do |language, code|
      request = {
        'jsonrpc' => '2.0',
        'id' => 1,
        'method' => 'tools/call',
        'params' => {
          'name' => 'execute_code',
          'arguments' => {
            'language' => language,
            'code' => code
          }
        }
      }

      response = server.handle_request(request)
      expect(response[:result][:isError]).to be false

      content = response[:result][:content]
      stdout_blocks = content.select { |c| c.dig(:annotations, :role) == 'stdout' }
      expect(stdout_blocks).not_to be_empty
      expect(stdout_blocks.first[:text]).to include('works')
    end
  end
end
