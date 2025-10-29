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

      output_schema(
        type: 'object',
        properties: {
          exit_code: { type: 'integer' },
          execution_time_s: { type: 'number' },
          filename: { type: %w[string null] },
          stdout: { type: 'string' },
          stderr: { type: 'string' }
        }
      )

      class << self
        def call(language:, code:, **options)
          with_error_handling do
            filename = options[:filename]
            instrument(:execute_start, language: language, filename: filename)
            result = executor.execute(language, code)
            instrument(:execute_end, language: language, filename: filename, exit_code: result.exit_code)
            build_response(code, language, result, filename)
          end
        end

        private

        def build_response(code, language, result, filename = nil)
          content = build_content_blocks(code, language, result, filename)
          create_response(content, structured: build_structured_payload(result, filename))
        end

        def build_content_blocks(code, language, result, filename)
          [
            code_block(code, language),
            stdout_block(result),
            stderr_block(result),
            final_block(result, filename)
          ].compact
        end

        def code_block(code, language)
          create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language))
        end

        def stdout_block(result)
          output_block(result.output, 'stdout')
        end

        def stderr_block(result)
          output_block(result.error, 'stderr')
        end

        def final_block(result, filename)
          create_content_block(execution_metadata(result, filename), final: true)
        end

        def build_structured_payload(result, filename)
          {
            exit_code: result.exit_code,
            execution_time_s: result.execution_time,
            filename: filename,
            stdout: present_or_nil(result.output),
            stderr: present_or_nil(result.error)
          }.compact
        end

        def present_or_nil(value)
          value.to_s.empty? ? nil : value
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
