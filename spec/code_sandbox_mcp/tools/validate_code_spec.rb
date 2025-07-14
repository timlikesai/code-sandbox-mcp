# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/validate_code'

RSpec.describe CodeSandboxMcp::Tools::ValidateCode do
  describe '.call' do
    context 'with valid code' do
      it 'returns success for valid Python code' do
        result = described_class.call(
          language: 'python',
          code: 'print("Hello, World!")'
        )

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('Syntax validation successful')
      end

      it 'returns success for valid Ruby code' do
        result = described_class.call(
          language: 'ruby',
          code: 'puts "Hello, World!"'
        )

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('Syntax validation successful')
      end
    end

    context 'with invalid code' do
      it 'returns error for invalid Python syntax' do
        result = described_class.call(
          language: 'python',
          code: 'print("Hello'
        )

        expect(result.to_h[:isError]).to be true
        content = result.to_h[:content].first
        expect(content[:text]).to include('syntax error')
        expect(content[:annotations][:status]).to eq('invalid')
      end

      it 'returns error for invalid Ruby syntax' do
        result = described_class.call(
          language: 'ruby',
          code: 'puts "Hello'
        )

        expect(result.to_h[:isError]).to be true
        content = result.to_h[:content].first
        expect(content[:text]).to include('syntax error')
        expect(content[:annotations][:status]).to eq('invalid')
      end
    end

    context 'with unsupported language' do
      it 'validates without error for languages without validators' do
        result = described_class.call(
          language: 'typescript',
          code: 'console.log("Hello")'
        )

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('Syntax validation successful')
      end
    end
  end

  describe 'tool metadata' do
    it 'has valid metadata' do
      expect_valid_tool_metadata(described_class, 'validate_code')
    end
  end
end
