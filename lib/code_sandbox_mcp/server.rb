# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'
require 'securerandom'
require_relative 'version'

module CodeSandboxMcp
  # Server implements the Model Context Protocol (MCP) for secure code execution.
  # It handles JSON-RPC requests over stdin/stdout and provides streaming code execution
  # capabilities with comprehensive error handling and validation.
  class Server
    attr_reader :logger

    def initialize(input: $stdin, output: $stdout, logger: Logger.new($stderr))
      @input = input
      @output = output
      @logger = logger
      @executor = Executor.new
    end

    def run
      logger.info "Code Sandbox MCP Server v#{VERSION} starting..."

      loop do
        line = @input.gets
        break unless line

        # Skip empty lines
        line = line.strip
        next if line.empty?

        request = JSON.parse(line)
        response = handle_request(request)

        # Only output response if not nil (notifications don't get responses)
        if response
          @output.puts JSON.generate(response)
          @output.flush
        end
      rescue JSON::ParserError => e
        log_and_handle_parse_error(e)
      rescue StandardError => e
        log_unexpected_error(e)
      end
    end

    def handle_request(request)
      request_id = request['id']
      method_name = request['method']

      case method_name
      when 'initialize'
        handle_initialize(request)
      when 'initialized'
        # Notification - no response
        return nil unless request_id

        {}
      when 'tools/list'
        handle_list_tools(request)
      when 'tools/call'
        handle_call_tool(request)
      else
        error_response(request_id, -32_601, "Method not found: #{method_name}")
      end
    rescue StandardError => e
      error_message = e.message
      logger.error "Error handling request: #{error_message}"
      error_response(request_id, -32_603, "Internal error: #{error_message}")
    end

    private

    def log_and_handle_parse_error(e)
      error_message = e.message
      logger.error "Invalid JSON: #{error_message}"
      send_error_response(id: nil, code: -32_700, message: 'Parse error')
    end

    def log_unexpected_error(e)
      error_message = e.message
      logger.error "Unexpected error: #{error_message}"
      logger.error e.backtrace.join("\n")
    end

    def validate_parameters(request_id, args)
      return build_validation_error_response(request_id, 'Missing required parameter: code') unless valid_code?(args)

      unless valid_language?(args)
        return build_validation_error_response(request_id,
                                               'Missing required parameter: language')
      end

      nil
    end

    def valid_code?(args)
      args&.dig('code')&.then { |code| !code.empty? }
    end

    def valid_language?(args)
      args&.dig('language')&.then { |language| !language.empty? }
    end

    def build_validation_error_response(request_id, message)
      {
        jsonrpc: '2.0',
        id: request_id,
        result: {
          content: [
            {
              type: 'text',
              text: message,
              annotations: {
                role: 'error'
              }
            }
          ],
          isError: true
        }
      }
    end

    def execute_code_with_streaming(language, code)
      streaming_executor = StreamingExecutor.new
      content_chunks = []

      streaming_executor.execute_streaming(language, code) do |chunk|
        content_chunks << chunk[:content] if chunk[:type] == 'content'
      end

      content_chunks
    end

    def build_success_response(request_id, content_chunks)
      {
        jsonrpc: '2.0',
        id: request_id,
        result: {
          content: content_chunks,
          isError: content_chunks.any? { |chunk| chunk.dig(:annotations, :role) == 'error' }
        }
      }
    end

    def build_error_response(request_id, error, language, start_time)
      current_time = Time.now
      execution_time = ((current_time - start_time) * 1000).round

      {
        jsonrpc: '2.0',
        id: request_id,
        result: {
          content: [
            {
              type: 'text',
              text: "Execution failed: #{error.message}\n\nBacktrace:\n#{error.backtrace.first(5).join("\n")}",
              annotations: {
                role: 'error'
              }
            },
            {
              type: 'text',
              text: JSON.pretty_generate({
                                           exitCode: -1,
                                           executionTime: "#{execution_time}ms",
                                           language: language,
                                           timestamp: current_time.iso8601,
                                           errorClass: error.class.name
                                         }),
              mimeType: 'application/json',
              annotations: {
                role: 'metadata'
              }
            }
          ],
          isError: true
        }
      }
    end

    def handle_initialize(request)
      {
        jsonrpc: '2.0',
        id: request['id'],
        result: {
          protocolVersion: '2024-11-05',
          serverInfo: {
            name: 'code-sandbox-mcp',
            version: VERSION
          },
          capabilities: {
            tools: {}
          }
        }
      }
    end

    def handle_list_tools(request)
      {
        jsonrpc: '2.0',
        id: request['id'],
        result: {
          tools: [
            {
              name: 'execute_code',
              description: 'Execute code in a secure Docker sandbox. Supports Python, JavaScript, ' \
                           'TypeScript, Ruby, Bash, Zsh, and Fish. Output is streamed in real-time.',
              inputSchema: {
                type: 'object',
                properties: {
                  language: {
                    type: 'string',
                    enum: LANGUAGES.keys.sort,
                    description: 'Programming language to execute'
                  },
                  code: {
                    type: 'string',
                    description: 'Code to execute'
                  }
                },
                required: %w[language code]
              },
              annotations: {
                readOnlyHint: false,
                destructiveHint: false,
                idempotentHint: true,
                openWorldHint: false,
                supportsStreaming: true
              }
            }
          ]
        }
      }
    end

    def handle_call_tool(request)
      params = request['params']
      tool_name = params['name']

      return error_response(request['id'], -32_602, "Unknown tool: #{tool_name}") unless tool_name == 'execute_code'

      # Execute with streaming for real-time output
      handle_execute_code(request, params)
    end

    def handle_execute_code(request, params)
      args = params['arguments']
      request_id = request['id']

      validation_error = validate_parameters(request_id, args)
      return validation_error if validation_error

      language = args['language']
      code = args['code']
      start_time = Time.now

      begin
        content_chunks = execute_code_with_streaming(language, code)
        build_success_response(request_id, content_chunks)
      rescue StandardError => e
        build_error_response(request_id, e, language, start_time)
      end
    end

    def error_response(id, code, message)
      {
        jsonrpc: '2.0',
        id: id,
        error: {
          code: code,
          message: message
        }
      }
    end

    def send_error_response(id:, code:, message:)
      response = error_response(id, code, message)
      @output.puts JSON.generate(response)
      @output.flush
    end
  end
end
