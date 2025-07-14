# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/syntax_validator'

RSpec.describe CodeSandboxMcp::SyntaxValidator do
  describe '.validate' do
    context 'with valid code' do
      it 'returns nil for valid Python' do
        expect(described_class.validate('python', 'print("Hello")')).to be_nil
      end

      it 'returns nil for valid Ruby' do
        expect(described_class.validate('ruby', 'puts "Hello"')).to be_nil
      end

      it 'returns nil for valid JavaScript' do
        expect(described_class.validate('javascript', 'console.log("Hello")')).to be_nil
      end

      it 'returns nil for valid Bash' do
        expect(described_class.validate('bash', 'echo "Hello"')).to be_nil
      end

      it 'returns nil for valid Zsh' do
        expect(described_class.validate('zsh', 'echo "Hello"')).to be_nil
      end

      it 'returns nil for valid Fish' do
        expect(described_class.validate('fish', 'echo "Hello"')).to be_nil
      end
    end

    context 'with invalid syntax' do
      context 'Python' do
        it 'raises ValidationError for invalid syntax' do
          expect { described_class.validate('python', 'print "Hello"') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
        end

        it 'includes line number for syntax errors' do
          code = "print('Hello')\nprint 'World'"
          expect { described_class.validate('python', code) }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError) do |error|
              expect(error.line).to eq(2)
            end
        end
      end

      context 'Ruby' do
        it 'raises ValidationError for invalid syntax' do
          expect { described_class.validate('ruby', 'puts "Hello" do') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
        end

        it 'includes line number for syntax errors' do
          expect { described_class.validate('ruby', 'if true\nputs "Hello"') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError) do |error|
              expect(error.line).to be_a(Integer)
            end
        end
      end

      context 'JavaScript' do
        it 'raises ValidationError for Python-style comments' do
          expect { described_class.validate('javascript', '# This is a comment\nconsole.log("Hello")') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError,
                            /is not valid comment syntax/)
        end

        it 'raises ValidationError for syntax errors' do
          expect { described_class.validate('javascript', 'console.log("Hello"') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
        end

        it 'includes line number and details for errors' do
          code = "console.log('Hello');\n# Invalid comment"
          expect { described_class.validate('javascript', code) }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError) do |error|
              expect(error.line).to eq(2)
              expect(error.details).to include('# Invalid comment')
            end
        end
      end

      context 'Bash' do
        it 'raises ValidationError for invalid syntax' do
          expect { described_class.validate('bash', 'if [ true ]; then') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
        end
      end

      context 'Shell languages' do
        it 'raises ValidationError for unclosed quotes in Zsh' do
          expect { described_class.validate('zsh', 'echo "Hello') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
        end

        it 'raises ValidationError for invalid syntax in Fish' do
          expect { described_class.validate('fish', 'if true\necho Hello') }
            .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
        end
      end
    end

    context 'with unsupported language' do
      it 'returns nil' do
        expect(described_class.validate('unsupported', 'some code')).to be_nil
      end
    end

    context 'fallback error handling when regex patterns fail' do
      it 'handles Python errors that do not match line number patterns' do
        allow(Open3).to receive(:capture3).with('python3', '-m', 'py_compile', anything)
                                          .and_return(['', 'SyntaxError: some weird python error format', double(success?: false)])

        expect { described_class.validate('python', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /Python.*some weird python error format/)
      end

      it 'handles Ruby errors that do not match line number patterns' do
        allow(Open3).to receive(:capture3).with('ruby', '-c', '-e', 'invalid code')
                                          .and_return(['', 'syntax error: weird ruby error format', double(success?: false)])

        expect { described_class.validate('ruby', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /Ruby.*weird ruby error format/)
      end

      it 'handles JavaScript errors that do not match line number patterns' do
        allow(Open3).to receive(:capture3).with('node', '--check', anything)
                                          .and_return(['', 'weird javascript error format', double(success?: false)])

        expect { described_class.validate('javascript', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /JavaScript.*weird javascript error format/)
      end

      it 'handles Bash errors that do not match line number patterns' do
        allow(Open3).to receive(:capture3).with('bash', '-n', '-c', 'invalid code')
                                          .and_return(['', 'bash: weird bash error format', double(success?: false)])

        expect { described_class.validate('bash', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /Bash.*weird bash error format/)
      end

      it 'handles Zsh shell errors that do not match line number patterns' do
        allow(Open3).to receive(:capture3).with('zsh', '-n', '-c', 'invalid code')
                                          .and_return(['', 'zsh: weird shell error format', double(success?: false)])

        expect { described_class.validate('zsh', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /Zsh.*weird shell error format/)
      end

      it 'handles Fish shell errors that do not match line number patterns' do
        allow(Open3).to receive(:capture3).with('fish', '--no-execute', '-c', 'invalid code')
                                          .and_return(['', 'fish: weird shell error format', double(success?: false)])

        expect { described_class.validate('fish', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /Fish.*weird shell error format/)
      end

      it 'handles Zsh shell errors that DO match line number patterns (lines 175-177)' do
        allow(Open3).to receive(:capture3).with('zsh', '-n', '-c', 'invalid code')
                                          .and_return(['', 'zsh: line 5: syntax error near unexpected token', double(success?: false)])

        expect { described_class.validate('zsh', 'invalid code') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /Zsh syntax error on line 5.*syntax error near unexpected token/)
      end
    end

    context 'with TypeScript' do
      it 'returns nil for valid TypeScript (skips validation)' do
        expect(described_class.validate('typescript', 'const x: string = "Hello"')).to be_nil
      end

      it 'returns nil for invalid TypeScript syntax (skips validation)' do
        expect(described_class.validate('typescript', 'const x: string = ')).to be_nil
      end
    end

    context 'with Java' do
      before do
        skip 'javac not available' unless system('which javac > /dev/null 2>&1')
      end

      it 'returns nil for valid Java' do
        expect(described_class.validate('java', 'class Main { public static void main(String[] args) {} }')).to be_nil
      end

      it 'raises ValidationError for invalid Java syntax' do
        expect { described_class.validate('java', 'class Main { public static void main(String[] args) {') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
      end
    end

    context 'with Kotlin' do
      before do
        skip 'kotlinc-jvm not available' unless system('which kotlinc-jvm > /dev/null 2>&1')
      end

      it 'returns nil for valid Kotlin' do
        expect(described_class.validate('kotlin', 'fun main() { println("Hello") }')).to be_nil
      end

      it 'raises ValidationError for invalid Kotlin syntax' do
        expect { described_class.validate('kotlin', 'fun main() { println("Hello"') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
      end
    end

    context 'with Scala' do
      before do
        skip 'scalac not available' unless system('which scalac > /dev/null 2>&1')
      end

      it 'returns nil for valid Scala' do
        expect(described_class.validate('scala', '@main def hello(): Unit = println("Hello")')).to be_nil
      end

      it 'raises ValidationError for invalid Scala syntax' do
        expect { described_class.validate('scala', '@main def hello(): Unit = println("Hello"') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
      end
    end

    context 'with Groovy' do
      before do
        skip 'groovy not available' unless system('which groovy > /dev/null 2>&1')
      end

      it 'returns nil for valid Groovy' do
        expect(described_class.validate('groovy', 'println "Hello"')).to be_nil
      end

      it 'raises ValidationError for invalid Groovy syntax' do
        expect { described_class.validate('groovy', 'println "Hello') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
      end
    end

    context 'with Clojure' do
      before do
        skip 'clojure not available' unless system('which clojure > /dev/null 2>&1')
      end

      it 'returns nil for valid Clojure' do
        expect(described_class.validate('clojure', '(println "Hello")')).to be_nil
      end

      it 'raises ValidationError for invalid Clojure syntax' do
        expect { described_class.validate('clojure', '(println "Hello"') }
          .to raise_error(CodeSandboxMcp::SyntaxValidator::ValidationError, /syntax error/)
      end
    end
  end
end
