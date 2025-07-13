# frozen_string_literal: true

require 'open3'
require 'tempfile'

module CodeSandboxMcp
  class SyntaxValidator
    class ValidationError < StandardError
      attr_reader :line, :column, :details

      def initialize(message, line: nil, column: nil, details: nil)
        super(message)
        @line = line
        @column = column
        @details = details
      end
    end

    VALIDATORS = {
      'python' => :validate_python,
      'ruby' => :validate_ruby,
      'javascript' => :validate_javascript,
      'typescript' => :validate_typescript,
      'bash' => :validate_bash,
      'zsh' => :validate_zsh,
      'fish' => :validate_fish
    }.freeze

    class << self
      def validate(language, code)
        validator = VALIDATORS[language]
        send(validator, code) if validator
      end

      private

      def validate_python(code)
        validate_with_tempfile(code, '.py') do |file_path|
          ['python3', '-m', 'py_compile', file_path]
        end
      end

      def validate_ruby(code)
        validate_with_command(['ruby', '-c', '-e', code]) do |stderr|
          parse_ruby_error(stderr)
        end
      end

      def validate_javascript(code)
        validate_with_tempfile(code, '.js') do |file_path|
          ['node', '--check', file_path]
        end
      end

      def validate_typescript(_code)
        # TypeScript validation requires tsc which may not be available
        # For now, we'll skip validation and let execution handle errors
        nil
      end

      def validate_bash(code)
        validate_with_command(['bash', '-n', '-c', code]) do |stderr|
          parse_bash_error(stderr)
        end
      end

      def validate_zsh(code)
        validate_with_command(['zsh', '-n', '-c', code]) do |stderr|
          parse_shell_error(stderr, 'zsh')
        end
      end

      def validate_fish(code)
        validate_with_command(['fish', '--no-execute', '-c', code]) do |stderr|
          parse_shell_error(stderr, 'fish')
        end
      end

      def validate_with_command(command)
        _stdout, stderr, status = Open3.capture3(*command)
        return if status.success?

        yield(stderr)
      end

      def validate_with_tempfile(code, extension)
        Tempfile.create(['syntax_check', extension]) do |file|
          file.write(code)
          file.flush
          command = yield(file.path)
          validate_with_command(command) do |stderr|
            case extension
            when '.py'
              parse_python_error(stderr, code)
            when '.js'
              parse_javascript_error(stderr, code)
            end
          end
        end
      end

      def parse_python_error(stderr, code)
        if stderr =~ /File ".*", line (\d+)/
          line_number = ::Regexp.last_match(1).to_i
          error_line = code.split("\n")[line_number - 1]

          if stderr.include?('SyntaxError')
            message = stderr[/SyntaxError: (.+)/, 1] || 'Invalid syntax'
            raise ValidationError.new("Python syntax error on line #{line_number}: #{message}",
                                      line: line_number, details: error_line)
          end
        end

        raise ValidationError, "Python syntax error: #{stderr.strip}"
      end

      def parse_ruby_error(stderr)
        if stderr =~ /-e:(\d+): (.+)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2)
          raise ValidationError.new("Ruby syntax error on line #{line_number}: #{message}", line: line_number)
        end

        raise ValidationError, "Ruby syntax error: #{stderr.strip}"
      end

      def parse_javascript_error(stderr, code)
        error_msg = extract_js_error_message(stderr)
        line_number = extract_js_line_number(stderr)

        if line_number
          lines = code.split("\n")
          error_line = lines[line_number - 1] if line_number.positive? && line_number <= lines.length
          error_msg = check_for_python_comment(error_line, line_number) || error_msg

          raise ValidationError.new("JavaScript syntax error on line #{line_number}: #{error_msg}",
                                    line: line_number, details: error_line)
        end

        raise ValidationError, "JavaScript syntax error: #{stderr.strip}"
      end

      def extract_js_error_message(stderr)
        stderr[/SyntaxError: (.+)/, 1] || 'Invalid syntax'
      end

      def extract_js_line_number(stderr)
        match = stderr.match(/:(\d+)/) || stderr.match(/at.*:(\d+):\d+/)
        match[1].to_i if match
      end

      def check_for_python_comment(error_line, _line_number)
        return unless error_line&.start_with?('#') && !error_line.start_with?('#!')

        "'#' is not valid comment syntax. Use '//' or '/* */'"
      end

      def parse_bash_error(stderr)
        if stderr =~ /line (\d+):(.*)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("Bash syntax error on line #{line_number}: #{message}", line: line_number)
        end

        raise ValidationError, "Bash syntax error: #{stderr.strip}"
      end

      def parse_shell_error(stderr, shell_name)
        capitalized_shell = shell_name.capitalize
        if stderr =~ /line (\d+):(.*)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("#{capitalized_shell} syntax error on line #{line_number}: #{message}",
                                    line: line_number)
        end

        raise ValidationError, "#{capitalized_shell} syntax error: #{stderr.strip}"
      end
    end
  end
end
