# frozen_string_literal: true

module CodeSandboxMcp
  class SyntaxValidator
    # JVM language validators
    module JvmValidators
      def validate_java(code)
        return unless command_available?('javac')

        # Extract class name from code or use default
        class_name = code[/public\s+class\s+(\w+)/, 1] || 'Main'
        Tempfile.create([class_name, '.java']) do |file|
          file.write(code)
          file.flush
          validate_with_command(['javac', '-Xlint:all', file.path]) do |stderr|
            parse_java_error(stderr, file.path)
          end
        end
      end

      def validate_kotlin(code)
        return unless command_available?('kotlinc-jvm')

        validate_with_tempfile(code, '.kts') do |file_path|
          ['kotlinc-jvm', '-script', '-nowarn', file_path]
        end
      end

      def validate_scala(code)
        return unless command_available?('scalac')

        validate_with_tempfile(code, '.scala') do |file_path|
          ['scalac', '-Ystop-after:parser', file_path]
        end
      end

      def validate_groovy(code)
        return unless command_available?('groovy')

        validate_with_tempfile(code, '.groovy') do |file_path|
          # Groovy doesn't have a pure syntax check, so we parse the file
          ['groovy', '-e', "new GroovyShell().parse(new File('#{file_path}'))"]
        end
      end

      def validate_clojure(code)
        return unless command_available?('clojure')

        validate_with_tempfile(code, '.clj') do |file_path|
          # Use Clojure's reader to check syntax
          clojure_code = <<~CLJ.tr("\n", ' ')
            (try
              (clojure.core/load-file "#{file_path}")
              (System/exit 0)
              (catch Exception e
                (binding [*out* *err*]
                  (println (.getMessage e)))
                (System/exit 1)))
          CLJ
          ['clojure', '-e', clojure_code]
        end
      end

      private

      def parse_java_error(stderr, file_path)
        # javac error format: file.java:line: error: message
        if stderr =~ /#{Regexp.escape(file_path)}:(\d+): error: (.+)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("Java syntax error on line #{line_number}: #{message}", line: line_number)
        end
        raise_language_syntax_error('Java', stderr)
      end

      def parse_kotlin_error(stderr, file_path)
        # kotlinc error format: file.kts:line:col: error: message
        if stderr =~ /#{Regexp.escape(file_path)}:(\d+):\d+: error: (.+)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("Kotlin syntax error on line #{line_number}: #{message}", line: line_number)
        end
        raise_language_syntax_error('Kotlin', stderr)
      end

      def parse_scala_error(stderr, file_path)
        # scalac error format: file.scala:line: error: message
        if stderr =~ /#{Regexp.escape(file_path)}:(\d+): error: (.+)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("Scala syntax error on line #{line_number}: #{message}", line: line_number)
        end
        raise_language_syntax_error('Scala', stderr)
      end

      def parse_groovy_error(stderr, file_path)
        # groovy error format varies, check for common patterns
        if stderr =~ /at line (\d+), column \d+/
          line_number = ::Regexp.last_match(1).to_i
          message = stderr[/(.+?) at line/, 1] || 'Syntax error'
          raise ValidationError.new("Groovy syntax error on line #{line_number}: #{message}", line: line_number)
        elsif stderr =~ /#{Regexp.escape(file_path)}: (\d+): (.+)/
          line_number = ::Regexp.last_match(1).to_i
          message = ::Regexp.last_match(2).strip
          raise ValidationError.new("Groovy syntax error on line #{line_number}: #{message}", line: line_number)
        end
        raise_language_syntax_error('Groovy', stderr)
      end

      def parse_clojure_error(stderr)
        # Clojure error format varies, look for common patterns
        if stderr =~ /Syntax error.*at \(.*:(\d+):\d+\)/
          line_number = ::Regexp.last_match(1).to_i
          message = stderr[/Syntax error (.+?) at/, 1] || 'Invalid syntax'
          raise ValidationError.new("Clojure syntax error on line #{line_number}: #{message}", line: line_number)
        elsif stderr =~ /line (\d+), column \d+/
          line_number = ::Regexp.last_match(1).to_i
          message = stderr[/RuntimeException: (.+)/, 1] || 'Syntax error'
          raise ValidationError.new("Clojure syntax error on line #{line_number}: #{message}", line: line_number)
        end
        raise_language_syntax_error('Clojure', stderr)
      end
    end
  end
end
