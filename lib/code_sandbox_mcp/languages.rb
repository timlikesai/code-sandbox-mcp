# frozen_string_literal: true

module CodeSandboxMcp
  LANGUAGES = {
    'python' => { command: %w[python3], extension: '.py', mime_type: 'text/x-python' },
    'javascript' => { command: %w[node], extension: '.js', mime_type: 'application/javascript' },
    'typescript' => { command: %w[tsx], extension: '.ts', mime_type: 'application/typescript' },
    'ruby' => { command: %w[ruby], extension: '.rb', mime_type: 'text/x-ruby' },
    'bash' => { command: %w[bash], extension: '.sh', mime_type: 'application/x-sh' },
    'zsh' => { command: %w[zsh], extension: '.zsh', mime_type: 'application/x-sh' },
    'fish' => { command: %w[fish], extension: '.fish', mime_type: 'application/x-sh' },
    'java' => { command: %w[java], extension: '.java', mime_type: 'text/x-java' },
    'clojure' => { command: %w[clojure], extension: '.clj', mime_type: 'text/x-clojure' },
    'kotlin' => { command: %w[kotlin], extension: '.kts', mime_type: 'text/x-kotlin' },
    'groovy' => { command: %w[groovy], extension: '.groovy', mime_type: 'text/x-groovy' },
    'scala' => { command: %w[scala], extension: '.scala', mime_type: 'text/x-scala' }
  }.freeze

  EXECUTION_TIMEOUT = ENV.fetch('EXECUTION_TIMEOUT', '30').to_i

  def self.mime_type_for(language)
    LANGUAGES.dig(language, :mime_type) || 'text/plain'
  end
end
