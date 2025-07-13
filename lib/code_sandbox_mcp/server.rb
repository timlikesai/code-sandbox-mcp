# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'
require 'securerandom'
require_relative 'version'
require_relative 'syntax_validator'

module CodeSandboxMcp
  # Server implements the Model Context Protocol (MCP) for secure code execution.
  # It handles JSON-RPC requests over stdin/stdout and provides streaming code execution
  # capabilities with comprehensive error handling and validation.
  class Server
    attr_reader :logger

    # Constants for better maintainability
    PROTOCOL_VERSION = '2024-11-05'
    SERVER_NAME = 'code-sandbox-mcp'
    JSONRPC_VERSION = '2.0'

    def initialize(input: $stdin, output: $stdout, logger: Logger.new($stderr))
      @input = input
      @output = output
      @logger = logger
    end

    def run
      logger.info "Code Sandbox MCP Server v#{VERSION} starting..."

      loop do
        line = @input.gets
        break unless line

        line = line.strip
        next if line.empty?

        request = JSON.parse(line)
        response = handle_request(request)

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

    def execute_code_tool_definition
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
        outputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'Original code that was executed'
            },
            language: {
              type: 'string',
              description: 'Programming language used'
            },
            mimeType: {
              type: 'string',
              description: 'MIME type of the code'
            },
            stdout: {
              type: 'array',
              items: { type: 'string' },
              description: 'Lines written to stdout'
            },
            stderr: {
              type: 'array',
              items: { type: 'string' },
              description: 'Lines written to stderr'
            },
            exitCode: {
              type: 'integer',
              description: 'Process exit code'
            },
            executionTime: {
              type: 'string',
              description: 'Total execution time'
            },
            timestamp: {
              type: 'string',
              description: 'ISO8601 timestamp of completion'
            }
          },
          required: %w[code language exitCode stdout stderr]
        },
        annotations: {
          readOnlyHint: false,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false,
          supportsStreaming: true
        }
      }
    end

    def validate_code_tool_definition
      {
        name: 'validate_code',
        description: 'Validate code syntax without execution. Supports Python, JavaScript, ' \
                     'Ruby, Bash, Zsh, and Fish. Returns validation results with detailed error messages.',
        inputSchema: {
          type: 'object',
          properties: {
            language: {
              type: 'string',
              enum: LANGUAGES.keys.sort,
              description: 'Programming language to validate'
            },
            code: {
              type: 'string',
              description: 'Code to validate'
            }
          },
          required: %w[language code]
        },
        outputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'Original code that was validated'
            },
            language: {
              type: 'string',
              description: 'Programming language used'
            },
            mimeType: {
              type: 'string',
              description: 'MIME type of the code'
            },
            valid: {
              type: 'boolean',
              description: 'Whether the code syntax is valid'
            },
            error: {
              type: 'object',
              description: 'Validation error details (only present if invalid)',
              properties: {
                message: { type: 'string', description: 'Error message' },
                line: { type: 'integer', description: 'Line number where error occurred' },
                details: { type: 'string', description: 'The problematic line of code' }
              }
            },
            validationTime: {
              type: 'string',
              description: 'Time taken to validate'
            },
            timestamp: {
              type: 'string',
              description: 'ISO8601 timestamp of validation'
            }
          },
          required: %w[code language valid]
        },
        annotations: {
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false,
          supportsStreaming: false
        }
      }
    end

    def json_response(id, result: nil, error: nil)
      response = { jsonrpc: JSONRPC_VERSION, id: id }
      response[:result] = result if result
      response[:error] = error if error
      response
    end

    def content_block(text, **options)
      block = { type: 'text', text: text }

      mime_type = options[:mime_type]
      block[:mimeType] = mime_type if mime_type

      annotations = build_annotations(options)
      block[:annotations] = annotations unless annotations.empty?

      block
    end

    def build_annotations(options)
      annotations = {}
      role = options[:role]
      annotations[:role] = role if role
      annotations[:streamed] = true if options[:streamed]
      annotations[:final] = true if options[:final]
      annotations
    end

    def add_output_lines(content, lines, role)
      lines.each do |line|
        content << content_block(line, role: role, streamed: true)
      end
    end

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
      return build_parameter_error_response(request_id, 'Missing required parameter: code') unless valid_code?(args)

      unless valid_language?(args)
        return build_parameter_error_response(request_id,
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

    def build_parameter_error_response(request_id, message)
      json_response(request_id, result: {
                      content: [content_block(message, role: 'error')],
                      isError: true
                    })
    end

    def execute_code_with_streaming(language, code)
      streaming_executor = StreamingExecutor.new
      stdout_lines = []
      stderr_lines = []
      exit_code = 0
      start_time = Time.now

      streaming_executor.execute_streaming(language, code) do |chunk|
        next unless chunk[:type] == 'content'

        content = chunk[:content]
        role = content.dig(:annotations, :role)
        text = content[:text]

        case role
        when 'stdout'
          stdout_lines << text
        when 'stderr'
          stderr_lines << text
        when 'result'
          if content.dig(:annotations, :final)
            begin
              result_data = JSON.parse(text)
              exit_code = result_data['exit_code'] || 0
            rescue JSON::ParserError
              # Silent failure - exit_code remains 0
            end
          end
        end
      end

      end_time = Time.now
      {
        stdout: stdout_lines,
        stderr: stderr_lines,
        exit_code: exit_code,
        execution_time: ((end_time - start_time) * 1000).round
      }
    end

    def build_success_response(request_id, execution_result, language, code)
      mime_type = CodeSandboxMcp.mime_type_for(language)
      stdout = execution_result[:stdout]
      stderr = execution_result[:stderr]
      exit_code = execution_result[:exit_code]
      execution_time_ms = "#{execution_result[:execution_time]}ms"
      timestamp = Time.now.iso8601

      content = []

      code_block = content_block(code, role: 'code', mime_type: mime_type)
      code_block[:annotations][:language] = language
      content << code_block

      add_output_lines(content, stdout, 'stdout')
      add_output_lines(content, stderr, 'stderr')

      result_metadata = {
        exit_code: exit_code,
        outputLines: stdout.size,
        errorLines: stderr.size,
        executionTime: execution_time_ms,
        timestamp: timestamp
      }
      content << content_block(JSON.pretty_generate(result_metadata), role: 'result', final: true)

      structured_content = {
        code: code,
        language: language,
        mimeType: mime_type,
        stdout: stdout,
        stderr: stderr,
        exitCode: exit_code,
        executionTime: execution_time_ms,
        timestamp: timestamp
      }

      json_response(request_id, result: {
                      content: content,
                      structuredContent: structured_content,
                      isError: false
                    })
    end

    def build_syntax_error_response(request_id, error, language, code, start_time)
      current_time = Time.now
      execution_time = ((current_time - start_time) * 1000).round
      mime_type = CodeSandboxMcp.mime_type_for(language)

      content = []

      # Add the original code block
      code_block = content_block(code, role: 'code', mime_type: mime_type)
      code_block[:annotations][:language] = language
      content << code_block

      # Add clear error message
      error_text = error.message
      error_text += "\n\nLine #{error.line}: #{error.details}" if error.details
      content << content_block(error_text, role: 'error')

      # Add metadata
      metadata = {
        exitCode: -1,
        syntaxError: true,
        errorLine: error.line,
        executionTime: "#{execution_time}ms",
        language: language,
        timestamp: current_time.iso8601
      }
      content << content_block(JSON.pretty_generate(metadata), role: 'result', final: true)

      structured_content = {
        code: code,
        language: language,
        mimeType: mime_type,
        stdout: [],
        stderr: [error.message],
        exitCode: -1,
        executionTime: "#{execution_time}ms",
        timestamp: current_time.iso8601,
        syntaxError: true,
        errorLine: error.line
      }

      json_response(request_id, result: {
                      content: content,
                      structuredContent: structured_content,
                      isError: true
                    })
    end

    def build_validation_success_response(request_id, language, code, start_time)
      current_time = Time.now
      validation_time = ((current_time - start_time) * 1000).round
      mime_type = CodeSandboxMcp.mime_type_for(language)

      content = []

      # Add the original code block
      code_block = content_block(code, role: 'code', mime_type: mime_type)
      code_block[:annotations][:language] = language
      content << code_block

      # Add success message
      content << content_block('✓ Syntax is valid', role: 'success')

      structured_content = {
        code: code,
        language: language,
        mimeType: mime_type,
        valid: true,
        validationTime: "#{validation_time}ms",
        timestamp: current_time.iso8601
      }

      json_response(request_id, result: {
                      content: content,
                      structuredContent: structured_content,
                      isError: false
                    })
    end

    def build_validate_tool_error_response(request_id, error, language, code, start_time)
      current_time = Time.now
      validation_time = ((current_time - start_time) * 1000).round
      mime_type = CodeSandboxMcp.mime_type_for(language)

      content = []

      # Add the original code block
      code_block = content_block(code, role: 'code', mime_type: mime_type)
      code_block[:annotations][:language] = language
      content << code_block

      # Add error message
      error_text = error.message
      error_text += "\n\nLine #{error.line}: #{error.details}" if error.details
      content << content_block(error_text, role: 'error')

      structured_content = {
        code: code,
        language: language,
        mimeType: mime_type,
        valid: false,
        error: {
          message: error.message,
          line: error.line,
          details: error.details
        }.compact,
        validationTime: "#{validation_time}ms",
        timestamp: current_time.iso8601
      }

      json_response(request_id, result: {
                      content: content,
                      structuredContent: structured_content,
                      isError: false # Not an error in the MCP sense, just invalid code
                    })
    end

    def build_error_response(request_id, error, language, start_time)
      current_time = Time.now
      execution_time = ((current_time - start_time) * 1000).round

      content = [
        content_block("Execution failed: #{error.message}\n\nBacktrace:\n#{error.backtrace.first(5).join("\n")}",
                      role: 'error'),
        content_block(JSON.pretty_generate({
                                             exitCode: -1,
                                             executionTime: "#{execution_time}ms",
                                             language: language,
                                             timestamp: current_time.iso8601,
                                             errorClass: error.class.name
                                           }),
                      role: 'metadata',
                      mime_type: 'application/json')
      ]

      json_response(request_id, result: {
                      content: content,
                      isError: true
                    })
    end

    def handle_initialize(request)
      json_response(request['id'], result: {
                      protocolVersion: PROTOCOL_VERSION,
                      serverInfo: {
                        name: SERVER_NAME,
                        version: VERSION
                      },
                      capabilities: {
                        tools: {}
                      }
                    })
    end

    def handle_list_tools(request)
      json_response(request['id'], result: {
                      tools: [execute_code_tool_definition, validate_code_tool_definition]
                    })
    end

    def handle_call_tool(request)
      params = request['params']
      tool_name = params['name']

      case tool_name
      when 'execute_code'
        handle_execute_code(request, params)
      when 'validate_code'
        handle_validate_code(request, params)
      else
        error_response(request['id'], -32_602, "Unknown tool: #{tool_name}")
      end
    end

    def handle_validate_code(request, params)
      args = params['arguments']
      request_id = request['id']

      validation_error = validate_parameters(request_id, args)
      return validation_error if validation_error

      language = args['language']
      code = args['code']
      start_time = Time.now

      begin
        # Attempt to validate the code
        SyntaxValidator.validate(language, code)

        # If no exception was raised, the code is valid
        build_validation_success_response(request_id, language, code, start_time)
      rescue SyntaxValidator::ValidationError => e
        # If validation failed, return the error details
        build_validate_tool_error_response(request_id, e, language, code, start_time)
      rescue StandardError => e
        # Handle unexpected errors
        error_response(request_id, -32_603, "Internal error during validation: #{e.message}")
      end
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
        # Validate syntax before execution
        SyntaxValidator.validate(language, code)

        execution_result = execute_code_with_streaming(language, code)
        build_success_response(request_id, execution_result, language, code)
      rescue SyntaxValidator::ValidationError => e
        build_syntax_error_response(request_id, e, language, code, start_time)
      rescue StandardError => e
        build_error_response(request_id, e, language, start_time)
      end
    end

    def error_response(id, code, message)
      json_response(id, error: {
                      code: code,
                      message: message
                    })
    end

    def send_error_response(id:, code:, message:)
      response = error_response(id, code, message)
      @output.puts JSON.generate(response)
      @output.flush
    end
  end
end
