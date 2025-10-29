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
                  'Use before execute_code to catch issues early.'
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
          }
        },
        required: %w[language code]
      )

      output_schema(
        oneOf: [
          {
            type: 'object',
            properties: {
              status: { const: 'valid' },
              filename: { type: %w[string null] }
            },
            required: %w[status]
          },
          {
            type: 'object',
            properties: {
              status: { const: 'invalid' },
              message: { type: 'string' },
              line: { type: 'integer' },
              column: { type: 'integer' }
            },
            required: %w[status message]
          }
        ]
      )

      class << self
        def call(language:, code:, filename: nil, **_options)
          SyntaxValidator.validate(language, code)
          success_response(language, code, filename)
        rescue SyntaxValidator::ValidationError => e
          error_response(e)
        rescue StandardError => e
          create_error_response("Validation error: #{e.message}")
        end

        private

        def success_response(language, code, filename = nil)
          message = 'Syntax validation successful'
          message += " for #{filename}" if filename

          content = [
            create_content_block(message, status: 'valid'),
            create_content_block(code, mime_type: CodeSandboxMcp.mime_type_for(language))
          ]
          create_response(content, structured: {
            status: 'valid',
            filename: filename
          }.compact)
        end

        def error_response(error)
          details = format_validation_error(error)
          annotations = { status: 'invalid', line: error.line, column: error.column }.compact
          content = [create_content_block(details, annotations)]
          create_response(content, error: true, structured: {
            status: 'invalid',
            message: error.message,
            line: error.line,
            column: error.column
          }.compact)
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
