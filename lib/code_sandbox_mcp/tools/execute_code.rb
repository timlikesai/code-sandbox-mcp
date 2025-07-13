# frozen_string_literal: true

require_relative 'base'
require_relative '../executor'

module CodeSandboxMcp
  module Tools
    class ExecuteCode < Base
      tool_name 'execute_code'
      description 'Execute code in a secure Docker sandbox. ' \
                  'Supports Python, JavaScript, TypeScript, Ruby, Bash, Zsh, and Fish.'
      input_schema(common_input_schema)

      class << self
        def call(language:, code:)
          result = Executor.new.execute(language, code)
          build_response(code, language, result)
        rescue StandardError => e
          create_error_response("Error: #{e.message}")
        end

        private

        def build_response(code, language, result)
          content = [
            create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language)),
            output_block(result.output, 'stdout'),
            output_block(result.error, 'stderr'),
            create_content_block(execution_metadata(result), final: true)
          ].compact

          MCP::Tool::Response.new(content)
        end

        def output_block(output, role)
          return nil if output.nil? || output.empty?

          create_content_block(output, role: role)
        end

        def execution_metadata(result)
          lines = ["Exit code: #{result.exit_code}"]
          lines << "Execution time: #{format('%.2f', result.execution_time)}s" if result.execution_time
          lines.join("\n")
        end
      end
    end
  end
end
