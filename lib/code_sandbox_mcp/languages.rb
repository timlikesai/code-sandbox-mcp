# frozen_string_literal: true

# CodeSandboxMcp provides secure code execution capabilities for multiple programming languages
# through the Model Context Protocol (MCP). It supports containerized execution with
# real-time output streaming and comprehensive error handling.
module CodeSandboxMcp
  LANGUAGES = {
    'python' => { command: %w[python3], extension: '.py', mime_type: 'text/x-python' },
    'javascript' => { command: %w[node], extension: '.js', mime_type: 'application/javascript' },
    'typescript' => { command: %w[tsx], extension: '.ts', mime_type: 'application/typescript' },
    'ruby' => { command: %w[ruby], extension: '.rb', mime_type: 'text/x-ruby' },
    'bash' => { command: %w[bash], extension: '.sh', mime_type: 'application/x-sh' },
    'zsh' => { command: %w[zsh], extension: '.zsh', mime_type: 'application/x-sh' },
    'fish' => { command: %w[fish], extension: '.fish', mime_type: 'application/x-sh' }
  }.freeze

  EXECUTION_TIMEOUT = ENV.fetch('EXECUTION_TIMEOUT', '30').to_i

  def self.mime_type_for(language)
    LANGUAGES.dig(language, :mime_type) || 'text/plain'
  end
end
