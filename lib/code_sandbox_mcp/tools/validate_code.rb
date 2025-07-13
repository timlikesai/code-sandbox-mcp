# frozen_string_literal: true

require_relative 'base'
require_relative '../syntax_validator'

module CodeSandboxMcp
  module Tools
    class ValidateCode < Base
      tool_name 'validate_code'
      description 'Validate code syntax before execution. Returns syntax errors with line numbers when available.'
      input_schema(common_input_schema)

      class << self
        def call(language:, code:)
          SyntaxValidator.validate(language, code)
          success_response
        rescue SyntaxValidator::ValidationError => e
          error_response(e)
        rescue StandardError => e
          create_error_response("Validation error: #{e.message}")
        end

        private

        def success_response
          content = [create_content_block('Syntax validation successful', status: 'valid')]
          MCP::Tool::Response.new(content)
        end

        def error_response(error)
          details = format_validation_error(error)
          annotations = { status: 'invalid', line: error.line, column: error.column }.compact
          content = [create_content_block(details, annotations)]
          MCP::Tool::Response.new(content, true)
        end

        def format_validation_error(error)
          parts = [error.message]
          parts << "Details: #{error.details}" if error.details
          parts.join("\n")
        end
      end
    end
  end
end
