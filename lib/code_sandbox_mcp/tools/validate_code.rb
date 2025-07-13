# frozen_string_literal: true

require_relative 'base'
require_relative '../syntax_validator'

module CodeSandboxMcp
  module Tools
    class ValidateCode < Base
      tool_name 'validate_code'
      description 'Validate code syntax without execution - fast feedback for errors, types, compilation. ' \
                  'Returns detailed error messages with line numbers and suggestions. ' \
                  'Supports all 12 languages with language-specific validation rules. ' \
                  'Use before execute_code to catch issues early. Can save files to session.'
      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Programming language for syntax validation. Each language uses appropriate validators.',
            enum: LANGUAGES.keys
          },
          code: {
            type: 'string',
            description: 'Source code to validate for syntax errors, type issues, and compilation problems.'
          },
          filename: {
            type: 'string',
            description: 'Filename for validation context - affects import resolution and language-specific rules.'
          },
          save: {
            type: 'boolean',
            description: 'Save validated file to session directory after validation for multi-file projects.'
          },
          session_id: {
            type: 'string',
            description: 'Session ID for saving validated files. Links to execute_code sessions for seamless workflow.'
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
            create_content_block(message, status: 'valid'),
            create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language))
          ]
          MCP::Tool::Response.new(content)
        end

        def save_code_to_session(session_id, language, code, filename)
          require_relative '../session_manager'
          SessionManager.instance.save_code_to_session(session_id, language, code, filename)
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
