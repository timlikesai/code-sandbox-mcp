# frozen_string_literal: true

require 'mcp'
require_relative '../languages'

module CodeSandboxMcp
  module Tools
    class Base < MCP::Tool
      class << self
        # Lightweight instrumentation hook (set via on_instrumentation).
        def on_instrumentation(callback)
          @instrumentation_callback = callback
        end

        def instrument(event, payload = {})
          return unless @instrumentation_callback

          @instrumentation_callback.call(event.to_s, payload)
        rescue StandardError => e
          warn "[instrumentation] #{e.class}: #{e.message}" if ENV['RUNNER_DEBUG'] == '1' || ENV['VERBOSE'] == 'true'
        end

        def common_input_schema
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

        def create_content_block(text, annotations = {})
          {
            type: 'text',
            text: text,
            annotations: annotations
          }.compact
        end

        def create_response(content, error: false, structured: nil)
          MCP::Tool::Response.new(content, error: error, structured_content: structured)
        end

        def create_error_response(message)
          create_response([create_content_block(message)], error: true)
        end

        def with_error_handling
          yield
        rescue StandardError => e
          create_error_response("Error: #{e.message}")
        end
      end
    end
  end
end
