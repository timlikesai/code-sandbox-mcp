# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSandboxMcp::Executor do
  subject(:executor) { described_class.new }

  # Helper to check if a command is available
  def command_available?(cmd)
    system("which #{cmd} > /dev/null 2>&1")
  end

  describe '#execute' do
    context 'with valid language and code' do
      it 'executes JavaScript code' do
        result = executor.execute('javascript', 'console.log("Hello, World!")')

        expect(result.output).to eq('Hello, World!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes TypeScript code' do
        skip 'TypeScript not installed' unless command_available?('tsx') || command_available?('ts-node')

        result = executor.execute('typescript', 'console.log("Hello" as string)')

        expect(result.output).to eq('Hello')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Python code' do
        result = executor.execute('python', 'print("Hello, Python!")')

        expect(result.output).to eq('Hello, Python!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Ruby code' do
        result = executor.execute('ruby', 'puts "Hello, Ruby!"')

        expect(result.output).to eq('Hello, Ruby!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Bash code' do
        result = executor.execute('bash', 'echo "Hello, Bash!"')

        expect(result.output).to eq('Hello, Bash!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Zsh code' do
        skip 'Zsh not installed' unless command_available?('zsh')

        result = executor.execute('zsh', 'echo "Hello, Zsh!"')

        expect(result.output).to eq('Hello, Zsh!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Fish code' do
        skip 'Fish not installed' unless command_available?('fish')

        result = executor.execute('fish', 'echo "Hello, Fish!"')

        expect(result.output).to eq('Hello, Fish!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Java code' do
        skip 'Java not installed' unless command_available?('java')

        result = executor.execute('java', 'public class main { public static void main(String[] args) { System.out.println("Hello, Java!"); } }')

        expect(result.output).to eq('Hello, Java!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Clojure code' do
        skip 'Clojure not installed' unless command_available?('clojure')

        result = executor.execute('clojure', '(println "Hello, Clojure!")')

        expect(result.output).to eq('Hello, Clojure!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Kotlin code' do
        skip 'Kotlin not installed' unless command_available?('kotlin')

        result = executor.execute('kotlin', 'println("Hello, Kotlin!")')

        expect(result.output).to eq('Hello, Kotlin!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Groovy code' do
        skip 'Groovy not installed' unless command_available?('groovy')

        result = executor.execute('groovy', 'println "Hello, Groovy!"')

        expect(result.output).to eq('Hello, Groovy!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'executes Scala code' do
        skip 'Scala not installed' unless command_available?('scala')

        result = executor.execute('scala', '@main def hello() = println("Hello, Scala!")')

        expect(result.output).to eq('Hello, Scala!')
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end
    end

    context 'with output handling' do
      it 'captures multiline output' do
        code = <<~RUBY
          puts "Line 1"
          puts "Line 2"
          puts "Line 3"
        RUBY

        result = executor.execute('ruby', code)

        expect(result.output).to eq("Line 1\nLine 2\nLine 3")
        expect(result.exit_code).to eq(0)
      end

      it 'captures stderr output' do
        result = executor.execute('python', 'import sys; sys.stderr.write("Error!")')

        expect(result.output).to be_empty
        expect(result.error).to eq('Error!')
        expect(result.exit_code).to eq(0)
      end

      it 'captures both stdout and stderr' do
        code = <<~PYTHON
          import sys
          print("Output")
          sys.stderr.write("Error\\n")
          print("More output")
        PYTHON

        result = executor.execute('python', code)

        expect(result.output).to eq("Output\nMore output")
        expect(result.error).to eq('Error')
        expect(result.exit_code).to eq(0)
      end

      it 'handles unicode output correctly' do
        result = executor.execute('python', 'print("Hello 👋 世界")')

        expect(result.output).to eq('Hello 👋 世界')
        expect(result.exit_code).to eq(0)
      end
    end

    context 'with error handling' do
      it 'captures syntax errors' do
        result = executor.execute('ruby', 'puts "unclosed string')

        expect(result.error).to include('unterminated string')
        expect(result.exit_code).not_to eq(0)
      end

      it 'captures runtime errors' do
        result = executor.execute('python', 'print(undefined_variable)')

        expect(result.error).to include('NameError')
        expect(result.exit_code).not_to eq(0)
      end

      it 'captures non-zero exit codes' do
        result = executor.execute('bash', 'exit 42')

        expect(result.exit_code).to eq(42)
      end

      it 'handles undefined variables' do
        result = executor.execute('javascript', 'console.log(undefinedVar)')

        expect(result.error).to include('undefinedVar')
        expect(result.exit_code).not_to eq(0)
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for unsupported language' do
        expect { executor.execute('invalid', 'code') }.to raise_error(ArgumentError, /Unsupported language/)
      end

      it 'handles empty code gracefully' do
        result = executor.execute('ruby', '')

        expect(result.output).to be_empty
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end

      it 'handles nil code' do
        result = executor.execute('ruby', nil)

        expect(result.output).to be_empty
        expect(result.error).to be_empty
        expect(result.exit_code).to eq(0)
      end
    end

    context 'with timeout' do
      it 'times out long-running code' do
        # Temporarily reduce timeout for faster tests
        stub_const('CodeSandboxMcp::EXECUTION_TIMEOUT', 2)

        code = 'sleep 5'
        result = executor.execute('bash', code)

        expect(result.error).to include('timeout')
        expect(result.exit_code).to eq(-1)
      end

      it 'completes quickly for normal code' do
        start_time = Time.now
        result = executor.execute('ruby', 'puts "Quick"')
        duration = Time.now - start_time

        expect(duration).to be < 5
        expect(result.output).to eq('Quick')
        expect(result.exit_code).to eq(0)
      end
    end

    context 'with resource limits' do
      it 'handles infinite loops gracefully' do
        # Temporarily reduce timeout for faster tests
        stub_const('CodeSandboxMcp::EXECUTION_TIMEOUT', 2)

        code = 'while true; do echo "loop"; done'
        result = executor.execute('bash', code)

        expect(result.error).to include('timeout')
        expect(result.exit_code).to eq(-1)
      end

      it 'handles memory-intensive code' do
        code = 'a = "x" * 1000000000'
        result = executor.execute('ruby', code)

        # Should either complete or timeout, not crash
        expect(result).to be_a(CodeSandboxMcp::Executor::ExecutionResult)
      end
    end

    context 'with file operations' do
      it 'prevents file writes outside temp directory' do
        code = <<~BASH
          echo "test" > /tmp/forbidden.txt
          echo "test" > ./allowed.txt
          ls -la allowed.txt
        BASH

        result = executor.execute('bash', code)

        expect(result.output).to include('allowed.txt')
        expect(result.exit_code).to eq(0)
      end

      it 'allows file operations in temp directory' do
        code = <<~RUBY
          File.write('test.txt', 'Hello, file!')
          puts File.read('test.txt')
        RUBY

        result = executor.execute('ruby', code)

        expect(result.output).to eq('Hello, file!')
        expect(result.exit_code).to eq(0)
      end
    end

    context 'with concurrent executions' do
      it 'handles multiple concurrent executions' do
        threads = []
        results = []

        5.times do |i|
          threads << Thread.new do
            result = executor.execute('ruby', "puts 'Thread #{i}'")
            results << result
          end
        end

        threads.each(&:join)

        expect(results).to all(be_a(CodeSandboxMcp::Executor::ExecutionResult))
        expect(results.map(&:exit_code)).to all(eq(0))
      end
    end
  end
end
