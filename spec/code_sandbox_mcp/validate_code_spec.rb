# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/server'

RSpec.describe 'validate_code tool' do
  let(:server) { CodeSandboxMcp::Server.new(input: StringIO.new, output: StringIO.new) }

  describe 'tool definition' do
    it 'appears in tools/list' do
      request = { 'id' => 1, 'method' => 'tools/list' }
      response = server.handle_request(request)

      tool_names = response[:result][:tools].map { |t| t[:name] }
      expect(tool_names).to include('validate_code')
    end

    it 'has correct tool definition' do
      request = { 'id' => 1, 'method' => 'tools/list' }
      response = server.handle_request(request)

      validate_tool = response[:result][:tools].find { |t| t[:name] == 'validate_code' }
      expect(validate_tool[:description]).to include('Validate code syntax without execution')
      expect(validate_tool[:inputSchema][:required]).to eq(%w[language code])
      expect(validate_tool[:outputSchema][:required]).to eq(%w[code language valid])
      expect(validate_tool[:annotations][:readOnlyHint]).to eq(true)
      expect(validate_tool[:annotations][:supportsStreaming]).to eq(false)
    end
  end

  describe 'validation functionality' do
    context 'with valid code' do
      it 'returns valid=true for correct JavaScript' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'javascript',
              'code' => 'console.log("Hello");'
            }
          }
        }

        response = server.handle_request(request)
        expect(response[:result][:structuredContent][:valid]).to eq(true)
        expect(response[:result][:structuredContent][:error]).to be_nil
      end

      it 'returns valid=true for correct Python' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'python',
              'code' => 'print("Hello, World!")'
            }
          }
        }

        response = server.handle_request(request)
        expect(response[:result][:structuredContent][:valid]).to eq(true)
      end

      it 'includes success message in content' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'ruby',
              'code' => 'puts "Hello"'
            }
          }
        }

        response = server.handle_request(request)
        success_content = response[:result][:content].find { |c| c[:annotations][:role] == 'success' }
        expect(success_content[:text]).to eq('✓ Syntax is valid')
      end
    end

    context 'with invalid code' do
      it 'returns valid=false with error details for invalid JavaScript' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'javascript',
              'code' => "# Invalid JS comment\nconsole.log(\"test\")"
            }
          }
        }

        response = server.handle_request(request)
        structured = response[:result][:structuredContent]

        expect(structured[:valid]).to eq(false)
        expect(structured[:error]).to be_a(Hash)
        expect(structured[:error][:message]).to include("'#' is not valid comment syntax")
        expect(structured[:error][:line]).to eq(1)
        expect(structured[:error][:details]).to eq('# Invalid JS comment')
      end

      it 'returns valid=false for syntax errors' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'python',
              'code' => 'print "Hello"  # Missing parentheses in Python 3'
            }
          }
        }

        response = server.handle_request(request)
        expect(response[:result][:structuredContent][:valid]).to eq(false)
        expect(response[:result][:structuredContent][:error][:message]).to include('syntax error')
      end
    end

    context 'with missing parameters' do
      it 'returns error for missing code' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'javascript'
            }
          }
        }

        response = server.handle_request(request)
        expect(response[:result][:isError]).to eq(true)
        expect(response[:result][:content].first[:text]).to include('Missing required parameter: code')
      end

      it 'returns error for missing language' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'code' => 'console.log("test")'
            }
          }
        }

        response = server.handle_request(request)
        expect(response[:result][:isError]).to eq(true)
        expect(response[:result][:content].first[:text]).to include('Missing required parameter: language')
      end
    end

    context 'with unsupported language' do
      it 'returns valid=true for languages without validators' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'typescript',
              'code' => 'const x: string = "Hello";'
            }
          }
        }

        response = server.handle_request(request)
        # TypeScript validation is not implemented, so it returns valid
        expect(response[:result][:structuredContent][:valid]).to eq(true)
      end
    end

    context 'response format' do
      it 'includes all required fields in structuredContent' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'javascript',
              'code' => 'console.log("test");'
            }
          }
        }

        response = server.handle_request(request)
        structured = response[:result][:structuredContent]

        expect(structured).to include(:code, :language, :mimeType, :valid, :validationTime, :timestamp)
        expect(structured[:validationTime]).to match(/\d+ms/)
        expect(structured[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
      end

      it 'sets isError to false even for invalid code' do
        request = {
          'id' => 1,
          'method' => 'tools/call',
          'params' => {
            'name' => 'validate_code',
            'arguments' => {
              'language' => 'javascript',
              'code' => 'console.log(' # Invalid
            }
          }
        }

        response = server.handle_request(request)
        # Invalid code is not an MCP error, just a validation failure
        expect(response[:result][:isError]).to eq(false)
      end
    end
  end
end
