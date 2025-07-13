# frozen_string_literal: true

require_relative 'base'
require_relative '../syntax_validator'

module CodeSandboxMcp
  module Tools
    class ValidateCode < Base
      tool_name 'validate_code'
      description 'Validate code syntax before execution. Returns syntax errors with line numbers when available.'
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
            description: 'Code to validate'
          },
          filename: {
            type: 'string',
            description: 'Optional filename to use for validation context'
          },
          save: {
            type: 'boolean',
            description: 'Save the file to session directory after validation (default: false)'
          },
          session_id: {
            type: 'string',
            description: 'Optional session ID for saving files'
          }
        },
        required: %w[language code]
      )

      class << self
        def call(language:, code:, filename: nil, save: false, session_id: nil)
          SyntaxValidator.validate(language, code)

          saved_path = nil
          saved_path = save_code_to_session(session_id, language, code, filename) if save && session_id

          success_response(language, code, filename, saved_path)
        rescue SyntaxValidator::ValidationError => e
          error_response(e)
        rescue StandardError => e
          create_error_response("Validation error: #{e.message}")
        end

        private

        def success_response(language, code, filename = nil, saved_path = nil)
          message = 'Syntax validation successful'
          message += " for #{filename}" if filename
          message += " (saved to #{saved_path})" if saved_path

          content = [
            create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language)),
            create_content_block(message, status: 'valid')
          ]
          MCP::Tool::Response.new(content)
        end

        def save_code_to_session(session_id, language, code, filename)
          require_relative '../session_manager'

          session_manager = SessionManager.instance
          session = session_manager.get_session(session_id)

          unless session
            session_id = session_manager.create_session(session_id: session_id)
            session = session_manager.get_session(session_id)
          end

          lang_config = LANGUAGES[language]
          extension = lang_config[:extension]
          filename ||= "main#{extension}"
          filename += extension unless filename.end_with?(extension)

          file_path = File.join(session[:directory], 'data', filename)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, code)

          file_path
        end

        def error_response(error)
          details = format_validation_error(error)
          annotations = { status: 'invalid', line: error.line, column: error.column }.compact
          content = [create_content_block(details, annotations)]
          MCP::Tool::Response.new(content, true)
        end

        def format_validation_error(error)
          parts = [error.message]
          details = error.details
          parts << "Details: #{details}" if details
          parts.join("\n")
        end
      end
    end
  end
end
