# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/execute_code'
require 'code_sandbox_mcp/tools/reset_session'
require 'code_sandbox_mcp/session_manager'

RSpec.describe 'Automatic Sessions in ExecuteCode' do
  include ToolHelpers

  before do
    # Reset all sessions before each test
    session_manager = CodeSandboxMcp::SessionManager.instance
    session_manager.clear_all_sessions
  end

  after do
    # Clean up after tests
    session_manager = CodeSandboxMcp::SessionManager.instance
    session_manager.clear_all_sessions
  end

  # Custom matcher for checking if response was successful
  RSpec::Matchers.define :be_success do
    match do |response|
      response.to_h[:isError] == false
    end
  end

  describe 'automatic state preservation' do
    it 'maintains state between executions' do
      # First execution - define a function
      result1 = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: "def greet(name):\n    return f'Hello, {name}!'"
      )

      expect(result1).to be_success
      expect(result1.content.last[:text]).to include('Exit code: 0')

      # Second execution - use the function
      result2 = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(greet("World"))'
      )

      expect(result2).to be_success
      expect(extract_stdout(result2.content)).to eq('Hello, World!')
    end

    it 'maintains separate sessions per language' do
      # Define variable in Python
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'x = 100'
      )

      # Define different variable in Ruby (using instance variable)
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'ruby',
        code: '@x = 200'
      )

      # Check Python still has its value
      result_python = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(x)'
      )
      expect(extract_stdout(result_python.content)).to eq('100')

      # Check Ruby has its own value
      result_ruby = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'ruby',
        code: 'puts @x'
      )
      expect(extract_stdout(result_ruby.content)).to eq('200')
    end

    it 'resets session when requested' do
      # Define a variable
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'message = "I should persist"'
      )

      # Verify it exists
      result1 = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(message)'
      )
      expect(extract_stdout(result1.content)).to eq('I should persist')

      # Execute with reset
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print("resetting")',
        reset_session: true
      )

      # Variable should no longer exist
      result2 = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(message)'
      )
      expect(result2.content.any? { |c| c[:annotations] && c[:annotations][:role] == 'stderr' }).to be true
      expect(extract_stderr(result2.content)).to include('NameError')
    end

    it 'allows custom session_id' do
      # Use custom session
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'custom_var = 42',
        session_id: 'my-custom-session'
      )

      # Default session should not have the variable
      result1 = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(custom_var)'
      )
      expect(extract_stderr(result1.content)).to include('NameError')

      # Custom session should have it
      result2 = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(custom_var)',
        session_id: 'my-custom-session'
      )
      expect(extract_stdout(result2.content)).to eq('42')
    end
  end

  describe 'ResetSession tool' do
    it 'resets specific language session' do
      # Set up state in Python
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'reset_test = "python value"'
      )

      # Set up state in Ruby
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'ruby',
        code: '@reset_test = "ruby value"'
      )

      # Reset only Python
      result = execute_tool(
        CodeSandboxMcp::Tools::ResetSession,
        language: 'python'
      )
      expect(result.content.first[:text]).to include('Python session has been reset')

      # Python should be cleared
      result_python = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(reset_test)'
      )
      expect(extract_stderr(result_python.content)).to include('NameError')

      # Ruby should still have its value
      result_ruby = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'ruby',
        code: 'puts @reset_test'
      )
      expect(extract_stdout(result_ruby.content)).to eq('ruby value')
    end

    it 'resets all sessions when language is "all"' do
      # Set up state in multiple languages
      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'all_test = "python"'
      )

      execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'javascript',
        code: 'const allTest = "javascript";'
      )

      # Reset all
      result = execute_tool(
        CodeSandboxMcp::Tools::ResetSession,
        language: 'all'
      )
      expect(result.content.first[:text]).to include('All language sessions have been reset')

      # Both should be cleared
      result_python = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'python',
        code: 'print(all_test)'
      )
      expect(extract_stderr(result_python.content)).to include('NameError')

      result_js = execute_tool(
        CodeSandboxMcp::Tools::ExecuteCode,
        language: 'javascript',
        code: 'console.log(allTest)'
      )
      expect(extract_stderr(result_js.content)).to include('ReferenceError')
    end
  end
end
