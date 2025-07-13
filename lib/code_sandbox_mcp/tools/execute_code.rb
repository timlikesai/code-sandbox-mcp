# frozen_string_literal: true

require_relative 'base'
require_relative '../executor'
require_relative '../session_manager'

module CodeSandboxMcp
  module Tools
    class ExecuteCode < Base
      tool_name 'execute_code'
      description 'Execute code in a secure Docker sandbox with automatic session management. ' \
                  'State is preserved between executions for each language. ' \
                  'Supports Python, JavaScript, TypeScript, Ruby, Bash, Zsh, Fish, ' \
                  'Java, Clojure, Kotlin, Groovy, and Scala.'
      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Programming language',
            enum: LANGUAGES.keys
          },
          code: {
            type: 'string',
            description: 'Code to execute'
          },
          session_id: {
            type: 'string',
            description: 'Optional session ID. If not provided, uses default session for the language.'
          },
          reset_session: {
            type: 'boolean',
            description: 'Reset the session before executing (default: false)'
          },
          filename: {
            type: 'string',
            description: 'Optional filename to use instead of default "main" + extension'
          },
          save: {
            type: 'boolean',
            description: 'Save the file to session directory for persistence (default: false)'
          }
        },
        required: %w[language code]
      )

      class << self
        def call(language:, code:, session_id: nil, reset_session: false, filename: nil, save: false)
          # Use default session for language if no session_id provided
          session_id ||= "default-#{language}"

          # Reset session if requested
          session_manager.clear_session(session_id) if reset_session

          # Execute in session
          result = session_manager.execute_in_session(session_id, language, code, executor, filename: filename,
                                                                                            save: save)
          build_response(code, language, result, session_id, filename)
        rescue StandardError => e
          create_error_response("Error: #{e.message}")
        end

        private

        def build_response(code, language, result, session_id, filename = nil)
          content = [
            create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language)),
            output_block(result.output, 'stdout'),
            output_block(result.error, 'stderr'),
            create_content_block(execution_metadata(result, session_id, filename), final: true)
          ].compact

          MCP::Tool::Response.new(content)
        end

        def output_block(output, role)
          return nil if output.to_s.empty?

          create_content_block(output, role: role)
        end

        def execution_metadata(result, session_id, filename = nil)
          lines = ["Exit code: #{result.exit_code}"]
          execution_time = result.execution_time
          lines << "Execution time: #{format('%.2f', execution_time)}s" if execution_time
          lines << "Session: #{session_id}" if session_id && !session_id.start_with?('default-')
          lines << "File: #{filename}" if filename
          lines << "Saved: #{result.saved_path}" if result.respond_to?(:saved_path) && result.saved_path
          lines.join("\n")
        end

        def executor
          @executor ||= Executor.new
        end

        def session_manager
          SessionManager.instance
        end
      end
    end
  end
end
