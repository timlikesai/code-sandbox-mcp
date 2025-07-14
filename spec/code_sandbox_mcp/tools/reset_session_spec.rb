# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/reset_session'

RSpec.describe CodeSandboxMcp::Tools::ResetSession do
  describe '.call' do
    context 'when resetting all sessions' do
      it 'returns placeholder message for all sessions' do
        result = described_class.call(language: 'all')

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('All sessions reset.')
      end

      it 'defaults to all when no language specified' do
        result = described_class.call

        expect(result.to_h[:content].first[:text]).to eq('All sessions reset.')
      end
    end

    context 'when resetting specific language session' do
      it 'returns placeholder message for specific language' do
        result = described_class.call(language: 'python')

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('Python session reset.')
      end

      it 'capitalizes language name in response message' do
        result = described_class.call(language: 'javascript')

        expect(result.to_h[:content].first[:text]).to eq('Javascript session reset.')
      end
    end
  end

  describe 'tool metadata' do
    it 'has valid metadata' do
      expect(described_class.name_value).to eq('reset_session')
      expect(described_class.description_value).to be_a(String)
      expect(described_class.description_value).not_to be_empty

      schema_hash = described_class.input_schema_value.to_h
      expect(schema_hash[:type]).to eq('object')
      expect(schema_hash[:properties]).to include(:language)
      expect(schema_hash[:properties][:language]).to include(
        type: 'string',
        enum: CodeSandboxMcp::LANGUAGES.keys + ['all']
      )
    end
  end
end
