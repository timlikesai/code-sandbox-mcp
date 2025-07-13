# frozen_string_literal: true

require_relative 'base'
require_relative '../executor'
require_relative '../session_manager'

module CodeSandboxMcp
  module Tools
    class ExecuteCode < Base
      tool_name 'execute_code'
      description 'Execute code securely in isolated Docker containers with persistent sessions. ' \
                  'Each language maintains its own session state - variables, functions, imports, and files persist. ' \
                  'Perfect for interactive development, multi-step tutorials, building multi-file applications, ' \
                  'and demonstrating complex workflows. Supports 12 languages: Python, JavaScript, TypeScript, Ruby, ' \
                  'Bash, Zsh, Fish, Java, Clojure, Kotlin, Groovy, Scala. ' \
                  'Use "save: true" and "filename" to create persistent files for multi-file projects. ' \
                  'Network access enabled for package installation and API calls.'
      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Programming language for execution. Each language has isolated sessions.',
            enum: LANGUAGES.keys
          },
          code: {
            type: 'string',
            description: 'Source code to execute. Can reference previously defined variables, functions, and modules.'
          },
          session_id: {
            type: 'string',
            description: 'Custom session identifier for isolation. Default sessions shared per language.'
          },
          reset_session: {
            type: 'boolean',
            description: 'Clear all session state before execution - removes variables, functions, imports, and files.'
          },
          filename: {
            type: 'string',
            description: 'Custom filename (with or without extension) for the code file. Enables importing/requiring.'
          },
          save: {
            type: 'boolean',
            description: 'Persist file in session directory for multi-file projects and imports.'
          }
        },
        required: %w[language code]
      )

      class << self
        def call(language:, code:, session_id: nil, reset_session: false, filename: nil, save: false)
          session_id ||= "default-#{language}"
          session_manager.clear_session(session_id) if reset_session

          result = execute_in_session(session_id, language, code, filename, save)
          build_response(code, language, result, session_id, filename)
        rescue StandardError => e
          create_error_response("Error: #{e.message}")
        end

        private

        def execute_in_session(session_id, language, code, filename, save)
          session_manager.execute_in_session(session_id, language, code, executor, filename: filename, save: save)
        end

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
