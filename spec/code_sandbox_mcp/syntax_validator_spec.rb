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

    context 'with TypeScript' do
      it 'returns nil (skips validation)' do
        expect(described_class.validate('typescript', 'const x: string = "Hello"')).to be_nil
      end
    end
  end
end
