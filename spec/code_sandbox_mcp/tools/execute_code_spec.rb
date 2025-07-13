# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/execute_code'
require 'code_sandbox_mcp/session_manager'

RSpec.describe CodeSandboxMcp::Tools::ExecuteCode do
  before do
    # Clear all sessions to ensure test isolation
    CodeSandboxMcp::SessionManager.instance.clear_all_sessions
  end

  describe '.call' do
    context 'with valid code' do
      it 'executes Python code successfully' do
        result = described_class.call(
          language: 'python',
          code: 'print("Hello from Python")'
        )

        expect_successful_response(result, expected_stdout: 'Hello from Python')

        content = result.to_h[:content]
        expect(content[0][:text]).to eq('print("Hello from Python")')
        expect(content[0][:annotations][:mime_type]).to eq('text/x-python')

        final_block = content.find { |c| c.dig(:annotations, :final) }
        expect(final_block[:text]).to include('Exit code: 0')
        expect(final_block[:text]).to match(/Execution time: \d+\.\d+s/)
      end

      it 'executes Ruby code successfully' do
        result = described_class.call(
          language: 'ruby',
          code: 'puts "Hello from Ruby"'
        )

        expect_successful_response(result, expected_stdout: 'Hello from Ruby')
      end

      it 'executes JavaScript code successfully' do
        result = described_class.call(
          language: 'javascript',
          code: 'console.log("Hello from JS")'
        )

        expect_successful_response(result, expected_stdout: 'Hello from JS')
      end

      it 'handles multiline output' do
        result = described_class.call(
          language: 'python',
          code: "for i in range(3):\n    print(f'Line {i}')"
        )

        expect_successful_response(result, expected_stdout: "Line 0\nLine 1\nLine 2")
      end
    end

    context 'with code that produces errors' do
      it 'captures stderr output' do
        result = described_class.call(
          language: 'python',
          code: 'import sys; sys.stderr.write("Error message\\n")'
        )

        expect(result.to_h[:isError]).to be false
        stderr_block = result.to_h[:content].find { |c| c.dig(:annotations, :role) == 'stderr' }
        expect(stderr_block[:text]).to eq('Error message')
      end

      it 'handles runtime errors' do
        result = described_class.call(
          language: 'python',
          code: 'undefined_variable'
        )

        expect(result.to_h[:isError]).to be false
        stderr_block = result.to_h[:content].find { |c| c.dig(:annotations, :role) == 'stderr' }
        expect(stderr_block[:text]).to include('NameError')

        final_block = result.to_h[:content].find { |c| c.dig(:annotations, :final) }
        expect(final_block[:text]).to include('Exit code: 1')
      end

      it 'handles syntax errors' do
        result = described_class.call(
          language: 'python',
          code: 'print("unclosed string'
        )

        expect(result.to_h[:isError]).to be false
        stderr_block = result.to_h[:content].find { |c| c.dig(:annotations, :role) == 'stderr' }
        expect(stderr_block[:text]).to include('SyntaxError')
      end
    end

    context 'with different languages' do
      it 'executes Bash code' do
        result = described_class.call(
          language: 'bash',
          code: 'echo "Bash works"'
        )

        expect_successful_response(result, expected_stdout: 'Bash works')
      end

      it 'executes Zsh code' do
        skip_if_command_unavailable('zsh')

        result = described_class.call(
          language: 'zsh',
          code: 'echo "Zsh works"'
        )

        expect_successful_response(result, expected_stdout: 'Zsh works')
      end

      it 'executes Fish code' do
        skip_if_command_unavailable('fish')

        result = described_class.call(
          language: 'fish',
          code: 'echo "Fish works"'
        )

        expect_successful_response(result, expected_stdout: 'Fish works')
      end

      it 'executes TypeScript code' do
        skip_if_command_unavailable('tsx')

        result = described_class.call(
          language: 'typescript',
          code: 'console.log("TypeScript works")'
        )

        expect_successful_response(result, expected_stdout: 'TypeScript works')
      end
    end

    context 'with edge cases' do
      it 'handles empty output' do
        result = described_class.call(
          language: 'python',
          code: 'pass'
        )

        expect(result.to_h[:isError]).to be false
        content = result.to_h[:content]

        # Should have code block and final block, but no stdout/stderr
        expect(content.size).to eq(2)
        expect(content[0][:text]).to eq('pass')
        expect(content[1][:annotations][:final]).to be true
      end

      it 'handles code with both stdout and stderr' do
        result = described_class.call(
          language: 'python',
          code: "print('Output'); import sys; sys.stderr.write('Error\\n')"
        )

        expect(result.to_h[:isError]).to be false
        content = result.to_h[:content]

        stdout_block = content.find { |c| c.dig(:annotations, :role) == 'stdout' }
        stderr_block = content.find { |c| c.dig(:annotations, :role) == 'stderr' }

        expect(stdout_block[:text]).to eq('Output')
        expect(stderr_block[:text]).to eq('Error')
      end

      it 'handles very long output' do
        result = described_class.call(
          language: 'python',
          code: "for i in range(1000):\n    print(f'Line {i}')"
        )

        expect(result.to_h[:isError]).to be false
        stdout_block = result.to_h[:content].find { |c| c.dig(:annotations, :role) == 'stdout' }

        lines = stdout_block[:text].split("\n")
        expect(lines.size).to eq(1000)
        expect(lines.first).to eq('Line 0')
        expect(lines.last).to eq('Line 999')
      end
    end

    context 'with invalid input' do
      it 'handles unsupported language' do
        result = described_class.call(
          language: 'unsupported',
          code: 'some code'
        )

        expect_error_response(result, expected_message: 'Unsupported language: unsupported')
      end
    end
  end

  describe 'tool metadata' do
    it 'has valid metadata' do
      expect_valid_tool_metadata(described_class, 'execute_code')
      expect(described_class.description_value).to include('Execute code in a secure Docker sandbox')
    end
  end
end
