# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools/reset_session'

RSpec.describe CodeSandboxMcp::Tools::ResetSession do
  let(:session_manager) { instance_double(CodeSandboxMcp::SessionManager) }

  before do
    allow(CodeSandboxMcp::SessionManager).to receive(:instance).and_return(session_manager)
  end

  describe '.call' do
    context 'when resetting all sessions' do
      it 'clears all language sessions' do
        allow(session_manager).to receive(:clear_session)

        result = described_class.call(language: 'all')

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('All language sessions have been reset.')

        CodeSandboxMcp::LANGUAGES.each_key do |lang|
          expect(session_manager).to have_received(:clear_session).with("default-#{lang}")
        end
      end

      it 'defaults to all when no language specified' do
        allow(session_manager).to receive(:clear_session)

        result = described_class.call

        expect(result.to_h[:content].first[:text]).to eq('All language sessions have been reset.')
      end
    end

    context 'when resetting specific language session' do
      it 'clears only the specified language session' do
        allow(session_manager).to receive(:clear_session)

        result = described_class.call(language: 'python')

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to eq('Python session has been reset.')
        expect(session_manager).to have_received(:clear_session).with('default-python')
      end

      it 'capitalizes language name in response message' do
        allow(session_manager).to receive(:clear_session)

        result = described_class.call(language: 'javascript')

        expect(result.to_h[:content].first[:text]).to eq('Javascript session has been reset.')
      end
    end

    context 'when an error occurs' do
      it 'returns error response when session manager fails' do
        allow(session_manager).to receive(:clear_session).and_raise(StandardError, 'Session error')

        result = described_class.call(language: 'python')

        expect(result.to_h[:isError]).to be true
        expect(result.to_h[:content].first[:text]).to include('Error: Session error')
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
