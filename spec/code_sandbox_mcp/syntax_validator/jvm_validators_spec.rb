# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/syntax_validator'

RSpec.describe CodeSandboxMcp::SyntaxValidator::JvmValidators do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      extend CodeSandboxMcp::SyntaxValidator::JvmValidators
      extend(Module.new do
        def command_available?(_cmd)
          false
        end
      end)
    end
  end

  describe 'validator methods' do
    it 'returns nil when javac is not available' do
      expect(test_class.validate_java('class Main {}')).to be_nil
    end

    it 'returns nil when kotlinc-jvm is not available' do
      expect(test_class.validate_kotlin('fun main() {}')).to be_nil
    end

    it 'returns nil when scalac is not available' do
      expect(test_class.validate_scala('@main def hello(): Unit = {}')).to be_nil
    end

    it 'returns nil when groovy is not available' do
      expect(test_class.validate_groovy('println "Hello"')).to be_nil
    end

    it 'returns nil when clojure is not available' do
      expect(test_class.validate_clojure('(println "Hello")')).to be_nil
    end
  end

  describe 'error parsing methods' do
    # Define a stub module to avoid the constant definition warning
    before do
      stub_const('TestValidationError', Class.new(StandardError) do
        attr_reader :line

        def initialize(message, line: nil)
          super(message)
          @line = line
        end
      end)
    end

    let(:test_error_class) do
      error_class = TestValidationError
      Class.new do
        extend CodeSandboxMcp::SyntaxValidator::JvmValidators

        # Define ValidationError as a constant in the anonymous class
        const_set(:ValidationError, error_class)

        # Stub the raise_language_syntax_error method
        define_singleton_method(:raise_language_syntax_error) do |lang, stderr|
          raise error_class, "#{lang} syntax error: #{stderr}"
        end
      end
    end

    it 'parses Java errors with line numbers' do
      stderr = '/tmp/Main.java:5: error: \';\' expected'
      expect { test_error_class.send(:parse_java_error, stderr, '/tmp/Main.java') }
        .to raise_error do |error|
          expect(error.message).to include('line 5')
          expect(error.line).to eq(5)
        end
    end

    it 'parses Kotlin errors with line numbers' do
      stderr = '/tmp/test.kts:3:5: error: Expecting an element'
      expect { test_error_class.send(:parse_kotlin_error, stderr, '/tmp/test.kts') }
        .to raise_error do |error|
          expect(error.message).to include('line 3')
          expect(error.line).to eq(3)
        end
    end

    it 'parses Scala errors with line numbers' do
      stderr = '/tmp/test.scala:7: error: not found: value x'
      expect { test_error_class.send(:parse_scala_error, stderr, '/tmp/test.scala') }
        .to raise_error do |error|
          expect(error.message).to include('line 7')
          expect(error.line).to eq(7)
        end
    end

    it 'parses Groovy errors with line numbers' do
      stderr = 'unexpected token: } at line 10, column 1'
      expect { test_error_class.send(:parse_groovy_error, stderr, '/tmp/test.groovy') }
        .to raise_error do |error|
          expect(error.message).to include('line 10')
          expect(error.line).to eq(10)
        end
    end

    it 'parses Clojure errors with line numbers' do
      stderr = 'Syntax error compiling at (test.clj:15:3).'
      expect { test_error_class.send(:parse_clojure_error, stderr) }
        .to raise_error do |error|
          expect(error.message).to include('line 15')
          expect(error.line).to eq(15)
        end
    end
  end
end
