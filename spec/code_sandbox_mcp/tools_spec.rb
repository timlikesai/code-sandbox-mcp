# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/tools'

RSpec.describe CodeSandboxMcp::Tools do
  describe 'ALL constant' do
    it 'contains all available tool classes' do
      expect(described_class::ALL).to be_an(Array)
      expect(described_class::ALL).to be_frozen
      expect(described_class::ALL.size).to eq(3)
    end

    it 'contains ExecuteCode tool' do
      expect(described_class::ALL).to include(CodeSandboxMcp::Tools::ExecuteCode)
    end

    it 'contains ValidateCode tool' do
      expect(described_class::ALL).to include(CodeSandboxMcp::Tools::ValidateCode)
    end

    it 'contains ResetSession tool' do
      expect(described_class::ALL).to include(CodeSandboxMcp::Tools::ResetSession)
    end

    it 'all tools inherit from MCP::Tool' do
      described_class::ALL.each do |tool_class|
        expect(tool_class).to be < MCP::Tool
      end
    end

    it 'all tools are properly configured' do
      described_class::ALL.each do |tool_class|
        # Each tool should have a name
        expect(tool_class.name_value).to be_a(String)
        expect(tool_class.name_value).not_to be_empty

        # Each tool should have a description
        expect(tool_class.description_value).to be_a(String)
        expect(tool_class.description_value).not_to be_empty

        # Each tool should have an input schema
        schema = tool_class.input_schema_value
        expect(schema).not_to be_nil

        schema_hash = schema.to_h
        expect(schema_hash[:type]).to eq('object')
        expect(schema_hash[:properties]).to be_a(Hash)
        expect(schema_hash[:required]).to be_an(Array) if schema_hash[:required]

        # Each tool should respond to call method
        expect(tool_class).to respond_to(:call)
      end
    end

    it 'tools have unique names' do
      names = described_class::ALL.map(&:name_value)
      expect(names.uniq.size).to eq(names.size)
    end
  end

  describe 'module structure' do
    it 'defines the Tools module within CodeSandboxMcp' do
      expect(defined?(CodeSandboxMcp::Tools)).to be_truthy
      expect(CodeSandboxMcp::Tools).to be_a(Module)
    end

    it 'has ExecuteCode class defined' do
      expect(defined?(CodeSandboxMcp::Tools::ExecuteCode)).to be_truthy
      expect(CodeSandboxMcp::Tools::ExecuteCode).to be_a(Class)
    end

    it 'has ValidateCode class defined' do
      expect(defined?(CodeSandboxMcp::Tools::ValidateCode)).to be_truthy
      expect(CodeSandboxMcp::Tools::ValidateCode).to be_a(Class)
    end

    it 'has ResetSession class defined' do
      expect(defined?(CodeSandboxMcp::Tools::ResetSession)).to be_truthy
      expect(CodeSandboxMcp::Tools::ResetSession).to be_a(Class)
    end
  end
end
