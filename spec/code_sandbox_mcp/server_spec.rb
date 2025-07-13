# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe CodeSandboxMcp::Server do
  subject(:server) { described_class.new }

  include CodeSandboxMcp::SpecHelpers

  describe '#initialize' do
    it 'sets up with default parameters' do
      default_server = described_class.new
      expect(default_server).to be_a(described_class)
      expect(default_server.logger).to be_a(Logger)
    end

    it 'accepts custom parameters' do
      custom_logger = Logger.new(StringIO.new)
      custom_server = described_class.new(logger: custom_logger)
      expect(custom_server.logger).to eq(custom_logger)
    end
  end

  describe '#handle_request' do
    context 'with initialize request' do
      let(:request) do
        {
          'jsonrpc' => '2.0',
          'id' => 1,
          'method' => 'initialize'
        }
      end

      it 'returns protocol version and capabilities' do
        response = server.handle_request(request)

        expect(response[:jsonrpc]).to eq('2.0')
        expect(response[:id]).to eq(1)
        expect(response[:result]).to include(
          protocolVersion: '2024-11-05',
          serverInfo: hash_including(
            name: 'code-sandbox-mcp',
            version: '0.1.0'
          ),
          capabilities: hash_including(
            tools: be_a(Hash)
          )
        )
      end
    end

    context 'with initialized notification' do
      let(:request) do
        {
          'jsonrpc' => '2.0',
          'method' => 'initialized'
        }
      end

      it 'returns no response for notification' do
        response = server.handle_request(request)
        expect(response).to be_nil
      end
    end

    context 'with tools/list request' do
      let(:request) do
        {
          'jsonrpc' => '2.0',
          'id' => 2,
          'method' => 'tools/list'
        }
      end

      it 'returns list of available tools' do
        response = server.handle_request(request)

        expect(response[:jsonrpc]).to eq('2.0')
        expect(response[:id]).to eq(2)
        expect(response[:result][:tools]).to be_an(Array)
        expect(response[:result][:tools].size).to eq(2)

        tool = response[:result][:tools].find { |t| t[:name] == 'execute_code' }
        expect(tool[:name]).to eq('execute_code')
        expect(tool[:description]).to include('Execute code in a secure Docker sandbox')
        expect(tool[:inputSchema]).to be_a(Hash)
        expect(tool[:inputSchema]).to include(
          type: 'object',
          required: %w[language code]
        )
        expect(tool[:annotations]).to include(
          readOnlyHint: false,
          destructiveHint: false,
          idempotentHint: true,
          supportsStreaming: true
        )
      end
    end

    context 'with tools/call request' do
      let(:base_request) do
        {
          'jsonrpc' => '2.0',
          'id' => 3,
          'method' => 'tools/call'
        }
      end

      context 'with valid code execution' do
        let(:request) do
          base_request.merge(
            'params' => {
              'name' => 'execute_code',
              'arguments' => {
                'language' => 'python',
                'code' => 'print("Hello, World!")'
              }
            }
          )
        end

        it 'executes code and returns streaming results' do
          response = server.handle_request(request)

          expect(response[:jsonrpc]).to eq('2.0')
          expect(response[:id]).to eq(3)
          expect(response[:result]).to include(
            content: be_an(Array),
            isError: false
          )

          content = response[:result][:content]

          # Should have at least stdout and result blocks
          expect(content.size).to be >= 2

          # Check stdout block
          stdout_block = content.find { |c| c.dig(:annotations, :role) == 'stdout' }
          expect(stdout_block).not_to be_nil
          expect(stdout_block[:type]).to eq('text')
          expect(stdout_block[:text]).to eq('Hello, World!')

          # Check result block
          result_block = content.find { |c| c.dig(:annotations, :role) == 'result' }
          expect(result_block).not_to be_nil
          expect(result_block[:text]).to include('"exit_code": 0')
        end

        it 'includes proper MIME types' do
          response = server.handle_request(request)
          content = response[:result][:content]

          # Should have code block with MIME type
          code_block = content.find { |c| c[:mimeType] }
          expect(code_block).not_to be_nil
          expect(code_block[:mimeType]).to eq('text/x-python')
        end

        it 'marks output as streamed' do
          response = server.handle_request(request)
          content = response[:result][:content]

          stdout_blocks = content.select { |c| c.dig(:annotations, :role) == 'stdout' }
          expect(stdout_blocks).to all(
            include(annotations: hash_including(streamed: true))
          )
        end
      end

      context 'with code that produces errors' do
        let(:request) do
          base_request.merge(
            'params' => {
              'name' => 'execute_code',
              'arguments' => {
                'language' => 'python',
                'code' => 'raise Exception("Test error")'
              }
            }
          )
        end

        it 'returns error output' do
          response = server.handle_request(request)

          expect(response[:result][:isError]).to be false # Tool itself didn't error

          content = response[:result][:content]

          # Check stderr block
          stderr_blocks = content.select { |c| c.dig(:annotations, :role) == 'stderr' }
          expect(stderr_blocks).not_to be_empty

          error_text = stderr_blocks.map { |b| b[:text] }.join("\n")
          expect(error_text).to include('Test error')

          # Check result block shows non-zero exit
          result_block = content.find { |c| c.dig(:annotations, :role) == 'result' }
          expect(result_block[:text]).to match(/"exit_code": [^0]/)
        end
      end

      context 'with unsupported language' do
        let(:request) do
          base_request.merge(
            'params' => {
              'name' => 'execute_code',
              'arguments' => {
                'language' => 'invalid',
                'code' => 'code'
              }
            }
          )
        end

        it 'returns error response' do
          response = server.handle_request(request)

          expect(response[:result][:isError]).to be true

          content = response[:result][:content]
          expect(content).to be_an(Array)
          expect(content.first[:type]).to eq('text')
          expect(content.first[:text]).to include('Unsupported language: invalid')
        end
      end

      context 'with missing required parameters' do
        let(:request) do
          base_request.merge(
            'params' => {
              'name' => 'execute_code',
              'arguments' => {
                'language' => 'python'
                # missing 'code' parameter
              }
            }
          )
        end

        it 'returns error response' do
          response = server.handle_request(request)

          expect(response[:result][:isError]).to be true
          expect(response[:result][:content].first[:text]).to include('Missing required parameter')
        end
      end

      context 'with unknown tool' do
        let(:request) do
          base_request.merge(
            'params' => {
              'name' => 'unknown_tool',
              'arguments' => {}
            }
          )
        end

        it 'returns error response' do
          response = server.handle_request(request)

          expect(response[:error]).to include(
            code: -32_602,
            message: 'Unknown tool: unknown_tool'
          )
        end
      end
    end

    context 'with unknown method' do
      let(:request) do
        {
          'jsonrpc' => '2.0',
          'id' => 4,
          'method' => 'unknown/method'
        }
      end

      it 'returns method not found error' do
        response = server.handle_request(request)

        expect(response[:error]).to include(
          code: -32_601,
          message: 'Method not found: unknown/method'
        )
      end
    end

    context 'with invalid JSON-RPC' do
      let(:request) do
        {
          'id' => 5,
          'method' => 'tools/list'
          # missing 'jsonrpc'
        }
      end

      it 'still processes the request' do
        response = server.handle_request(request)

        expect(response[:jsonrpc]).to eq('2.0')
        expect(response[:id]).to eq(5)
        expect(response[:result]).to have_key(:tools)
      end
    end
  end

  describe '#run' do
    let(:input) { StringIO.new }
    let(:output) { StringIO.new }

    before do
      allow($stdin).to receive(:gets).and_return(nil)
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
    end

    context 'with single request' do
      before do
        request = {
          jsonrpc: '2.0',
          id: 1,
          method: 'tools/list'
        }.to_json

        allow($stdin).to receive(:gets).and_return(request, nil)
      end

      it 'processes request and outputs response' do
        server.run

        output.rewind
        response_line = output.gets.chomp
        response = JSON.parse(response_line)

        expect(response['jsonrpc']).to eq('2.0')
        expect(response['id']).to eq(1)
        expect(response['result']['tools']).to be_an(Array)
      end
    end

    context 'with multiple requests' do
      before do
        request1 = { jsonrpc: '2.0', id: 1, method: 'initialize' }.to_json
        request2 = { jsonrpc: '2.0', method: 'initialized' }.to_json # notification
        request3 = { jsonrpc: '2.0', id: 2, method: 'tools/list' }.to_json

        allow($stdin).to receive(:gets).and_return(request1, request2, request3, nil)
      end

      it 'processes all requests' do
        server.run

        output.rewind
        lines = output.readlines.map(&:chomp).reject(&:empty?)

        # Should have 2 responses (notification doesn't get response)
        expect(lines.size).to eq(2)

        response1 = JSON.parse(lines[0])
        expect(response1['id']).to eq(1)
        expect(response1['result']['protocolVersion']).to eq('2024-11-05')

        response2 = JSON.parse(lines[1])
        expect(response2['id']).to eq(2)
        expect(response2['result']['tools']).to be_an(Array)
      end
    end

    context 'with malformed JSON' do
      before do
        allow($stdin).to receive(:gets).and_return('invalid json', nil)
      end

      it 'outputs parse error and continues' do
        server.run

        output.rewind
        response_line = output.gets.chomp
        response = JSON.parse(response_line)

        expect(response['error']).to include(
          'code' => -32_700,
          'message' => 'Parse error'
        )
      end
    end

    context 'with empty lines' do
      before do
        request = { jsonrpc: '2.0', id: 1, method: 'tools/list' }.to_json

        allow($stdin).to receive(:gets).and_return('', '  ', request, '', nil)
      end

      it 'skips empty lines and processes valid requests' do
        server.run

        output.rewind
        lines = output.readlines.map(&:chomp).reject(&:empty?)

        expect(lines.size).to eq(1)
        response = JSON.parse(lines.first)
        expect(response['id']).to eq(1)
      end
    end
  end

  describe 'error handling' do
    context 'when executor raises an exception' do
      let(:request) do
        {
          'jsonrpc' => '2.0',
          'id' => 10,
          'method' => 'tools/call',
          'params' => {
            'name' => 'execute_code',
            'arguments' => {
              'language' => 'python',
              'code' => 'print("test")'
            }
          }
        }
      end

      before do
        executor = instance_double(CodeSandboxMcp::StreamingExecutor)
        allow(CodeSandboxMcp::StreamingExecutor).to receive(:new).and_return(executor)
        allow(executor).to receive(:execute_streaming).and_raise(StandardError, 'Executor failed')
      end

      it 'returns error in result content' do
        response = server.handle_request(request)

        expect(response[:result][:isError]).to be true
        expect(response[:result][:content]).to be_an(Array)

        error_content = response[:result][:content].find { |c| c.dig(:annotations, :role) == 'error' }
        expect(error_content[:text]).to include('Executor failed')
      end

      it 'continues running after handling errors' do
        # First send invalid JSON, then valid request
        input_content = "invalid json\n#{JSON.generate({ jsonrpc: '2.0', id: 2, method: 'tools/list' })}\n"
        test_input = StringIO.new(input_content)
        test_output = StringIO.new
        test_server = described_class.new(input: test_input, output: test_output)

        # Server should handle error and continue
        thread = Thread.new { test_server.run }
        sleep 0.1
        thread.kill

        test_output.rewind
        lines = test_output.read.split("\n")

        # Should have error response and then successful response
        expect(lines.size).to eq(2)

        error_response = JSON.parse(lines[0])
        expect(error_response['error']['code']).to eq(-32_700)

        success_response = JSON.parse(lines[1])
        expect(success_response['result']['tools']).to be_an(Array)
      end
    end
  end

  describe 'error handling' do
    context 'when JSON parsing fails' do
      it 'handles JSON parse errors gracefully' do
        # Suppress error output during this test
        silent_logger = Logger.new(StringIO.new)
        server.instance_variable_set(:@logger, silent_logger)

        expect(server).to receive(:log_and_handle_parse_error).and_call_original

        # Mock stdin to provide invalid JSON
        allow($stdin).to receive(:gets).and_return('invalid json\n', nil)

        # Capture output
        output = StringIO.new
        server.instance_variable_set(:@output, output)

        server.run

        expect(output.string).to include('Parse error')
      end
    end

    context 'when unexpected errors occur in request handling' do
      let(:request) do
        {
          'jsonrpc' => '2.0',
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'execute_code',
            'arguments' => {
              'language' => 'python',
              'code' => 'print("test")'
            }
          }
        }
      end

      it 'handles unexpected errors in request processing' do
        # Suppress error output during this test
        silent_logger = Logger.new(StringIO.new)
        server.instance_variable_set(:@logger, silent_logger)

        # Force an unexpected error during request handling
        allow(server).to receive(:handle_call_tool).and_raise(StandardError.new('Unexpected error'))

        response = server.handle_request(request)

        expect(response[:error]).to include(
          code: -32_603,
          message: 'Internal error: Unexpected error'
        )
      end
    end

    context 'when unexpected errors occur during startup' do
      it 'logs unexpected errors during startup' do
        # Suppress error output during this test
        silent_logger = Logger.new(StringIO.new)
        server.instance_variable_set(:@logger, silent_logger)

        # Force an unexpected error in the main run loop
        $stdin.method(:gets)
        call_count = 0
        allow($stdin).to receive(:gets) do
          call_count += 1
          if call_count == 1
            '{"jsonrpc": "2.0", "id": 1, "method": "initialize"}'
          elsif call_count == 2
            raise StandardError, 'Startup error'
          end
        end

        expect(server).to receive(:log_unexpected_error).and_call_original

        server.run
      end
    end

    context 'when validation fails' do
      it 'handles missing language parameter' do
        request = {
          'jsonrpc' => '2.0',
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'execute_code',
            'arguments' => {
              'code' => 'print("test")'
              # missing language
            }
          }
        }

        response = server.handle_request(request)

        expect(response[:result][:isError]).to be true
        expect(response[:result][:content].first[:text]).to include('Missing required parameter: language')
      end
    end
  end
end
