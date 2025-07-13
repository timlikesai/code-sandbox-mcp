# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools'

RSpec.describe 'Tools Integration' do
  describe 'ExecuteCode and ValidateCode workflow' do
    it 'validates and then executes valid code' do
      code = 'print("Integration test successful!")'
      language = 'python'

      # First validate
      validation_result = CodeSandboxMcp::Tools::ValidateCode.call(
        language: language,
        code: code
      )

      expect_successful_response(validation_result)
      expect(validation_result.to_h[:content].first[:text]).to eq('Syntax validation successful')

      # Then execute
      execution_result = CodeSandboxMcp::Tools::ExecuteCode.call(
        language: language,
        code: code
      )

      expect_successful_response(execution_result, expected_stdout: 'Integration test successful!')
    end

    it 'validates invalid code and reports error' do
      code = 'print("missing quote'
      language = 'python'

      # Validate should fail
      validation_result = CodeSandboxMcp::Tools::ValidateCode.call(
        language: language,
        code: code
      )

      expect_error_response(validation_result, expected_message: 'syntax error')

      # Execute should also fail but with different error
      execution_result = CodeSandboxMcp::Tools::ExecuteCode.call(
        language: language,
        code: code
      )

      expect_successful_response(execution_result)
      stderr_block = execution_result.to_h[:content].find { |c| c.dig(:annotations, :role) == 'stderr' }
      expect(stderr_block[:text]).to include('SyntaxError')

      final_block = execution_result.to_h[:content].find { |c| c.dig(:annotations, :final) }
      expect(final_block[:text]).to include('Exit code: 1')
    end
  end

  describe 'Multiple language support' do
    let(:test_cases) do
      {
        'python' => 'print("Python integration")',
        'ruby' => 'puts "Ruby integration"',
        'javascript' => 'console.log("JavaScript integration")',
        'bash' => 'echo "Bash integration"'
      }
    end

    let(:expected_outputs) do
      {
        'python' => 'Python integration',
        'ruby' => 'Ruby integration',
        'javascript' => 'JavaScript integration',
        'bash' => 'Bash integration'
      }
    end

    it 'validates and executes code for all supported languages' do
      test_cases.each do |language, code|
        # Validate
        validation_result = CodeSandboxMcp::Tools::ValidateCode.call(
          language: language,
          code: code
        )

        expect_successful_response(validation_result)

        # Execute
        execution_result = CodeSandboxMcp::Tools::ExecuteCode.call(
          language: language,
          code: code
        )

        expect_successful_response(execution_result, expected_stdout: expected_outputs[language])
      end
    end
  end

  describe 'Tool registration' do
    it 'includes all tools in the ALL constant' do
      expect(CodeSandboxMcp::Tools::ALL).to include(
        CodeSandboxMcp::Tools::ExecuteCode,
        CodeSandboxMcp::Tools::ValidateCode,
        CodeSandboxMcp::Tools::ResetSession
      )
      expect(CodeSandboxMcp::Tools::ALL.size).to eq(3)
    end

    it 'tools have unique names' do
      names = CodeSandboxMcp::Tools::ALL.map(&:name_value)
      expect(names).to eq(%w[execute_code validate_code reset_session])
      expect(names.uniq.size).to eq(names.size)
    end

    it 'tools have proper descriptions' do
      CodeSandboxMcp::Tools::ALL.each do |tool|
        expect(tool.description_value).not_to be_empty
        expect(tool.description_value).to be_a(String)
      end
    end

    it 'tools have valid input schemas' do
      CodeSandboxMcp::Tools::ALL.each do |tool|
        schema = tool.input_schema_value.to_h
        expect(schema[:type]).to eq('object')
        expect(schema[:properties]).to be_a(Hash)
        expect(schema[:required]).to be_an(Array) if schema[:required]

        # Only ExecuteCode and ValidateCode require language and code
        if [CodeSandboxMcp::Tools::ExecuteCode, CodeSandboxMcp::Tools::ValidateCode].include?(tool)
          expect(schema[:required]).to include(:language, :code)
        end
      end
    end
  end

  describe 'Error handling consistency' do
    it 'handles executor errors gracefully in both tools' do
      # Mock the session manager to raise an error
      allow_any_instance_of(CodeSandboxMcp::SessionManager).to receive(:execute_in_session)
        .and_raise(StandardError, 'Mock error')

      execution_result = CodeSandboxMcp::Tools::ExecuteCode.call(
        language: 'python',
        code: 'print("test")'
      )

      expect(execution_result.to_h[:isError]).to be true
      expect(execution_result.to_h[:content].first[:text]).to include('Error: Mock error')
    end

    it 'handles validation errors gracefully' do
      # Mock the validator to raise an error
      allow(CodeSandboxMcp::SyntaxValidator).to receive(:validate)
        .and_raise(StandardError, 'Mock validation error')

      validation_result = CodeSandboxMcp::Tools::ValidateCode.call(
        language: 'python',
        code: 'print("test")'
      )

      expect(validation_result.to_h[:isError]).to be true
      expect(validation_result.to_h[:content].first[:text]).to include('Validation error: Mock validation error')
    end
  end

  describe 'Response format consistency' do
    it 'both tools return MCP::Tool::Response objects' do
      execute_result = CodeSandboxMcp::Tools::ExecuteCode.call(
        language: 'python',
        code: 'print("test")'
      )

      validate_result = CodeSandboxMcp::Tools::ValidateCode.call(
        language: 'python',
        code: 'print("test")'
      )

      expect(execute_result).to be_a(MCP::Tool::Response)
      expect(validate_result).to be_a(MCP::Tool::Response)
    end

    it 'all content blocks have required fields' do
      result = CodeSandboxMcp::Tools::ExecuteCode.call(
        language: 'python',
        code: 'print("test")'
      )

      result.to_h[:content].each do |block|
        expect(block).to have_key(:type)
        expect(block).to have_key(:text)
        expect(block[:type]).to eq('text')
        expect(block[:text]).to be_a(String)
      end
    end
  end
end
