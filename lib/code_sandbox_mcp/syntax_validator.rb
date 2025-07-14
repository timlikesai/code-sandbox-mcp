# frozen_string_literal: true

require 'open3'
require 'tempfile'
require_relative 'syntax_validator/jvm_validators'

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
      'fish' => :validate_fish,
      'java' => :validate_java,
      'kotlin' => :validate_kotlin,
      'scala' => :validate_scala,
      'groovy' => :validate_groovy,
      'clojure' => :validate_clojure
    }.freeze

    class << self
      include JvmValidators

      def validate(language, code)
        validator = VALIDATORS[language]
        send(validator, code) if validator
      end

      private

      def raise_language_syntax_error(language, stderr)
        raise ValidationError, "#{language} syntax error: #{stderr.strip}"
      end

      def parse_error_with_line(stderr, pattern, language)
        if stderr =~ pattern
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2)&.strip || 'syntax error'
          raise ValidationError.new("#{language} syntax error on line #{line_number}: #{message}", line: line_number)
        end
        raise_language_syntax_error(language, stderr)
      end

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
        # TypeScript validation is complex because we need type checking
        # For now, skip validation since we don't have a good way to validate TS syntax
        # without the TypeScript compiler
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

      def command_available?(command)
        system("which #{command} > /dev/null 2>&1")
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
            parse_error_for_extension(extension, stderr, code, file.path)
          end
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def parse_error_for_extension(extension, stderr, code, file_path)
        case extension
        when '.py' then parse_python_error(stderr, code)
        when '.js' then parse_javascript_error(stderr, code)
        when '.java' then parse_java_error(stderr, file_path)
        when '.kts' then parse_kotlin_error(stderr, file_path)
        when '.scala' then parse_scala_error(stderr, file_path)
        when '.groovy' then parse_groovy_error(stderr, file_path)
        when '.clj' then parse_clojure_error(stderr)
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

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

        raise_language_syntax_error('Python', stderr)
      end

      def parse_ruby_error(stderr)
        parse_error_with_line(stderr, /-e:(\d+): (.+)/, 'Ruby')
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

        raise_language_syntax_error('JavaScript', stderr)
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
        parse_error_with_line(stderr, /line (\d+):(.*)/, 'Bash')
      end

      def parse_shell_error(stderr, shell_name)
        parse_error_with_line(stderr, /line (\d+):(.*)/, shell_name.capitalize)
      end
    end
  end
end
