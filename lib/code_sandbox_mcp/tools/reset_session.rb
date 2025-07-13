# frozen_string_literal: true

require_relative 'base'
require_relative '../session_manager'

module CodeSandboxMcp
  module Tools
    class ResetSession < Base
      tool_name 'reset_session'
      description 'Clear session state and files for clean restarts. ' \
                  'Removes all variables, functions, imports, classes, and saved files from the specified sessions. ' \
                  'Essential for starting fresh when sessions become cluttered or when switching between projects. ' \
                  'Can reset individual languages or all sessions at once. ' \
                  'Use before multi-file examples or when troubleshooting import/dependency issues.'

      input_schema(
        type: 'object',
        properties: {
          language: {
            type: 'string',
            description: 'Language session to reset (clears variables, functions, imports, files) or "all".',
            enum: LANGUAGES.keys + ['all']
          }
        }
      )

      class << self
        def call(language: 'all')
          if language == 'all'
            LANGUAGES.each_key do |lang|
              session_manager.clear_session("default-#{lang}")
            end
            message = 'All language sessions have been reset.'
          else
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
