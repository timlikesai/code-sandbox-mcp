# frozen_string_literal: true

require_relative 'base'
require_relative '../session_manager'

module CodeSandboxMcp
  module Tools
    # MCP tool for resetting code execution sessions
    class ResetSession < Base
      tool_name 'reset_session'
      description 'Reset the code execution session for a specific language or all languages.'

      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Language to reset. If not provided, resets all language sessions.',
            enum: LANGUAGES.keys + ['all']
          }
        }
      )

      class << self
        def call(language: 'all')
          if language == 'all'
            # Clear all default language sessions
            LANGUAGES.each_key do |lang|
              session_manager.clear_session("default-#{lang}")
            end
            message = 'All language sessions have been reset.'
          else
            # Clear specific language session
            session_manager.clear_session("default-#{language}")
            message = "#{language.capitalize} session has been reset."
          end

          content = [create_content_block(message)]
          MCP::Tool::Response.new(content)
        rescue StandardError => e
          create_error_response("Error: #{e.message}")
        end

        private

        def session_manager
          SessionManager.instance
        end
      end
    end
  end
end
