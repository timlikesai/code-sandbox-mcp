# frozen_string_literal: true

require_relative 'base'

module CodeSandboxMcp
  module Tools
    class ResetSession < Base
      tool_name 'reset_session'
      description 'Clear session state for clean restarts.'

      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Language session to reset or "all".',
            enum: LANGUAGES.keys + ['all']
          }
        }
      )

      class << self
        def call(language: 'all')
          with_error_handling do
            message = if language == 'all'
                        'All sessions reset.'
                      else
                        "#{language.capitalize} session reset."
                      end

            content = [create_content_block(message)]
            MCP::Tool::Response.new(content)
          end
        end
      end
    end
  end
end
