# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSandboxMcp::Executor::ExecutionResult do
  describe '#initialize' do
    it 'creates result with all attributes' do
      result = described_class.new(
        output: 'Hello, World!',
        error: 'Warning: something',
        exit_code: 0
      )

      expect(result.output).to eq('Hello, World!')
      expect(result.error).to eq('Warning: something')
      expect(result.exit_code).to eq(0)
    end
  end

  describe '#to_h' do
    it 'converts to hash with all attributes' do
      result = described_class.new(
        output: 'Hello',
        error: 'Error',
        exit_code: 1
      )

      hash = result.to_h

      expect(hash).to eq({
                           output: 'Hello',
                           error: 'Error',
                           exit_code: 1
                         })
    end
  end

  describe '#to_json' do
    it 'converts to JSON string' do
      result = described_class.new(
        output: 'Hello',
        error: 'Warning',
        exit_code: 0
      )

      json = result.to_h.to_json
      parsed = JSON.parse(json)

      expect(parsed).to eq({
                             'output' => 'Hello',
                             'error' => 'Warning',
                             'exit_code' => 0
                           })
    end

    it 'handles special characters in output' do
      result = described_class.new(
        output: "Line 1\nLine 2\tTabbed",
        error: 'Error with "quotes"',
        exit_code: 0
      )

      json = result.to_h.to_json
      parsed = JSON.parse(json)

      expect(parsed['output']).to eq("Line 1\nLine 2\tTabbed")
      expect(parsed['error']).to eq('Error with "quotes"')
    end

    it 'handles unicode characters' do
      result = described_class.new(
        output: 'Hello 👋 世界',
        error: '',
        exit_code: 0
      )

      json = result.to_h.to_json
      parsed = JSON.parse(json)

      expect(parsed['output']).to eq('Hello 👋 世界')
    end
  end

  describe 'equality' do
    it 'considers results with same attributes equal' do
      result1 = described_class.new(
        output: 'Hello',
        error: '',
        exit_code: 0
      )

      result2 = described_class.new(
        output: 'Hello',
        error: '',
        exit_code: 0
      )

      expect(result1).to eq(result2)
    end

    it 'considers results with different attributes not equal' do
      result1 = described_class.new(
        output: 'Hello',
        error: '',
        exit_code: 0
      )

      result2 = described_class.new(
        output: 'Hello',
        error: '',
        exit_code: 1
      )

      expect(result1).not_to eq(result2)
    end
  end
end
