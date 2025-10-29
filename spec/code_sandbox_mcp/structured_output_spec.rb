# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/execute_code'
require 'code_sandbox_mcp/tools/validate_code'
require 'code_sandbox_mcp/tools/reset_session'

RSpec.describe 'Structured outputs and schemas' do
  describe CodeSandboxMcp::Tools::ExecuteCode do
    it 'declares an output schema' do
      schema = described_class.output_schema_value
      expect(schema).not_to be_nil
      expect(schema.to_h[:type]).to eq('object')
      expect(schema.to_h[:properties]).to include(:exit_code, :execution_time_s)
    end

    it 'returns structured payload with execution details' do
      result = described_class.call(language: 'python', code: 'print("ok")')
      h = result.to_h
      expect(h[:structuredContent]).to include(:exit_code)
      expect(h[:structuredContent][:exit_code]).to eq(0)
      expect(h[:structuredContent][:stdout]).to eq('ok')
    end
  end

  describe CodeSandboxMcp::Tools::ValidateCode do
    it 'declares an output schema' do
      schema = described_class.output_schema_value
      expect(schema).not_to be_nil
      expect(schema.to_h[:oneOf]).to be_an(Array)
    end

    it 'returns structured payload when valid' do
      result = described_class.call(language: 'python', code: 'print("hi")')
      expect(result.to_h[:structuredContent]).to include(status: 'valid')
    end

    it 'returns structured payload when invalid' do
      result = described_class.call(language: 'python', code: 'print("hi"')
      s = result.to_h[:structuredContent]
      expect(s[:status]).to eq('invalid')
      expect(s[:message]).to be_a(String)
    end
  end

  describe CodeSandboxMcp::Tools::ResetSession do
    it 'declares an output schema' do
      schema = described_class.output_schema_value
      expect(schema).not_to be_nil
      expect(schema.to_h[:properties]).to include(:status, :language)
    end

    it 'returns structured payload' do
      result = described_class.call(language: 'python')
      expect(result.to_h[:structuredContent]).to eq(status: 'reset', language: 'python')
    end
  end
end
