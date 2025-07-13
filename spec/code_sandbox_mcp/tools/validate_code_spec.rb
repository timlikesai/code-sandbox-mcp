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

    context 'with save functionality' do
      let(:session_id) { 'test-session' }
      let(:temp_dir) { Dir.mktmpdir }

      before do
        allow(CodeSandboxMcp::SessionManager.instance).to receive(:get_session)
          .with(session_id).and_return(directory: temp_dir)
        allow(CodeSandboxMcp::SessionManager.instance).to receive(:create_session)
          .with(session_id: session_id).and_return(session_id)
        allow(CodeSandboxMcp::SessionManager.instance).to receive(:save_code_to_session) do |_session_id, language, code, filename|
          data_dir = File.join(temp_dir, 'data')
          FileUtils.mkdir_p(data_dir)
          
          lang_config = CodeSandboxMcp::LANGUAGES[language]
          extension = lang_config[:extension]
          filename ||= "main#{extension}"
          filename += extension unless filename.end_with?(extension)
          
          file_path = File.join(data_dir, filename)
          File.write(file_path, code)
          file_path
        end
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'saves validated file to session when save: true' do
        result = described_class.call(
          language: 'python',
          code: 'print("Hello, World!")',
          session_id: session_id,
          save: true,
          filename: 'test_script'
        )

        expect(result.to_h[:isError]).to be false
        expect(result.to_h[:content].first[:text]).to include('(saved to')

        saved_file = File.join(temp_dir, 'data', 'test_script.py')
        expect(File.exist?(saved_file)).to be true
        expect(File.read(saved_file)).to eq('print("Hello, World!")')
      end

      it 'uses default filename when none provided' do
        result = described_class.call(
          language: 'ruby',
          code: 'puts "Hello"',
          session_id: session_id,
          save: true
        )

        expect(result.to_h[:isError]).to be false
        saved_file = File.join(temp_dir, 'data', 'main.rb')
        expect(File.exist?(saved_file)).to be true
      end

      it 'adds extension if not present in filename' do
        result = described_class.call(
          language: 'javascript',
          code: 'console.log("test")',
          session_id: session_id,
          save: true,
          filename: 'script'
        )

        expect(result.to_h[:isError]).to be false
        saved_file = File.join(temp_dir, 'data', 'script.js')
        expect(File.exist?(saved_file)).to be true
      end

      it 'creates session if it does not exist' do
        allow(CodeSandboxMcp::SessionManager.instance).to receive(:save_code_to_session)
          .with(session_id, 'python', 'print("test")', nil)
          .and_return(File.join(temp_dir, 'data', 'main.py'))

        result = described_class.call(
          language: 'python',
          code: 'print("test")',
          session_id: session_id,
          save: true
        )

        expect(result.to_h[:isError]).to be false
        expect(CodeSandboxMcp::SessionManager.instance).to have_received(:save_code_to_session)
          .with(session_id, 'python', 'print("test")', nil)
      end
    end
  end

  describe 'tool metadata' do
    it 'has valid metadata' do
      expect_valid_tool_metadata(described_class, 'validate_code')
    end
  end
end
