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

    class << self
      def validate(language, code)
        validator_method = "validate_#{language}"
        return unless respond_to?(validator_method, true)

        send(validator_method, code)
      end

      private

      def validate_python(code)
        Tempfile.create(['syntax_check', '.py']) do |file|
          file.write(code)
          file.flush

          _, stderr, status = Open3.capture3('python3', '-m', 'py_compile', file.path)
          parse_python_error(stderr, code) unless status.success?
        end
      end

      def validate_ruby(code)
        _, stderr, status = Open3.capture3('ruby', '-c', '-e', code)
        return if status.success?

        parse_ruby_error(stderr)
      end

      def validate_javascript(code)
        Tempfile.create(['syntax_check', '.js']) do |file|
          file.write(code)
          file.flush

          _, stderr, status = Open3.capture3('node', '--check', file.path)
          parse_javascript_error(stderr, code) unless status.success?
        end
      end

      def validate_typescript(_code)
        # TypeScript validation requires tsc which may not be available
        # For now, we'll skip validation and let execution handle errors
        nil
      end

      def validate_bash(code)
        _, stderr, status = Open3.capture3('bash', '-n', '-c', code)
        return if status.success?

        parse_bash_error(stderr)
      end

      def validate_zsh(code)
        _, stderr, status = Open3.capture3('zsh', '-n', '-c', code)
        return if status.success?

        parse_shell_error(stderr, 'zsh')
      end

      def validate_fish(code)
        _, stderr, status = Open3.capture3('fish', '--no-execute', '-c', code)
        return if status.success?

        parse_shell_error(stderr, 'fish')
      end

      def parse_python_error(stderr, code)
        if stderr =~ /File ".*", line (\d+)/
          line_num = ::Regexp.last_match(1).to_i
          error_line = code.split("\n")[line_num - 1]

          if stderr.include?('SyntaxError')
            message = stderr[/SyntaxError: (.+)/, 1] || 'Invalid syntax'
            raise ValidationError.new("Python syntax error on line #{line_num}: #{message}",
                                      line: line_num, details: error_line)
          end
        end

        raise ValidationError, "Python syntax error: #{stderr.strip}"
      end

      def parse_ruby_error(stderr)
        if stderr =~ /-e:(\d+): (.+)/
          line_num = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2)
          raise ValidationError.new("Ruby syntax error on line #{line_num}: #{message}", line: line_num)
        end

        raise ValidationError, "Ruby syntax error: #{stderr.strip}"
      end

      def parse_javascript_error(stderr, code)
        error_msg = extract_js_error_message(stderr)
        line_num = extract_js_line_number(stderr)

        if line_num
          lines = code.split("\n")
          error_line = lines[line_num - 1] if line_num.positive? && line_num <= lines.length
          error_msg = check_for_python_comment(error_line, line_num) || error_msg

          raise ValidationError.new("JavaScript syntax error on line #{line_num}: #{error_msg}",
                                    line: line_num, details: error_line)
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

      def check_for_python_comment(error_line, _line_num)
        return unless error_line&.start_with?('#') && !error_line.start_with?('#!')

        "'#' is not valid comment syntax. Use '//' or '/* */'"
      end

      def parse_bash_error(stderr)
        if stderr =~ /line (\d+):(.*)/
          line_num = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("Bash syntax error on line #{line_num}: #{message}", line: line_num)
        end

        raise ValidationError, "Bash syntax error: #{stderr.strip}"
      end

      def parse_shell_error(stderr, shell_name)
        if stderr =~ /line (\d+):(.*)/
          line_num = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("#{shell_name.capitalize} syntax error on line #{line_num}: #{message}",
                                    line: line_num)
        end

        raise ValidationError, "#{shell_name.capitalize} syntax error: #{stderr.strip}"
      end
    end
  end
end
