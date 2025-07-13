# frozen_string_literal: true

require_relative 'tools/base'
require_relative 'tools/execute_code'
require_relative 'tools/validate_code'

module CodeSandboxMcp
  module Tools
    ALL = [
      ExecuteCode,
      ValidateCode
    ].freeze
  end
end
