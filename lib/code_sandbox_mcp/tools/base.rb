# frozen_string_literal: true

require 'mcp'
require_relative '../languages'

module CodeSandboxMcp
  module Tools
    class Base < MCP::Tool
      def self.common_input_schema
        {
          type: 'object',
          properties: {
            language: {
              type: 'string',
              description: 'Programming language',
              enum: LANGUAGES.keys
            },
            code: {
              type: 'string',
              description: 'Code content'
            }
          },
          required: %w[language code]
        }
      end

      private_class_method def self.create_content_block(text, annotations = {})
        {
          type: 'text',
          text: text,
          annotations: annotations
        }.compact
      end

      private_class_method def self.create_error_response(message)
        MCP::Tool::Response.new(
          [create_content_block(message)],
          true
        )
      end
    end
  end
end
