# frozen_string_literal: true

require_relative 'base'
require_relative '../executor'

module CodeSandboxMcp
  module Tools
    class ExecuteCode < Base
      tool_name 'execute_code'
      description 'Execute code securely in isolated Docker containers. ' \
                  'Supports 12 languages: Python, JavaScript, TypeScript, Ruby, ' \
                  'Bash, Zsh, Fish, Java, Clojure, Kotlin, Groovy, Scala. ' \
                  'Network access enabled for package installation and API calls.'
      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Programming language for execution.',
            enum: LANGUAGES.keys
          },
          code: {
            type: 'string',
            description: 'Source code to execute.'
          },
          filename: {
            type: 'string',
            description: 'Custom filename (with or without extension) for the code file.'
          }
        },
        required: %w[language code]
      )

      class << self
        def call(language:, code:, **options)
          with_error_handling do
            filename = options[:filename]
            result = executor.execute(language, code)
            build_response(code, language, result, filename)
          end
        end

        private

        def build_response(code, language, result, filename = nil)
          content = [
            create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language)),
            output_block(result.output, 'stdout'),
            output_block(result.error, 'stderr'),
            create_content_block(execution_metadata(result, filename), final: true)
          ].compact

          MCP::Tool::Response.new(content)
        end

        def output_block(output, role)
          return nil if output.to_s.empty?

          create_content_block(output, role: role)
        end

        def execution_metadata(result, filename = nil)
          lines = ["Exit code: #{result.exit_code}"]
          execution_time = result.execution_time
          lines << "Execution time: #{format('%.2f', execution_time)}s" if execution_time
          lines << "File: #{filename}" if filename
          lines.join("\n")
        end

        def executor
          @executor ||= Executor.new
        end
      end
    end
  end
end
