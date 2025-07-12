# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'json'

RSpec.describe 'Streaming Integration' do
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:server) { CodeSandboxMcp::Server.new(input: input, output: output) }

  describe 'execute_code tool' do
    it 'includes streamed output in response' do
      request = {
        'jsonrpc' => '2.0',
        'id' => 1,
        'method' => 'tools/call',
        'params' => {
          'name' => 'execute_code',
          'arguments' => {
            'language' => 'ruby',
            'code' => '3.times { |i| puts "Line #{i}" }'
          }
        }
      }

      input.string = "#{JSON.generate(request)}\n"
      input.rewind

      # Run server in thread
      thread = Thread.new { server.run }
      sleep 0.2
      thread.kill

      output.rewind
      response = JSON.parse(output.read.strip)

      expect(response['id']).to eq(1)
      expect(response['result']).to be_a(Hash)

      content = response['result']['content']
      expect(content).to be_an(Array)

      # Should have stdout content marked as streamed
      stdout_chunks = content.select { |c| c.dig('annotations', 'role') == 'stdout' }
      expect(stdout_chunks).not_to be_empty
      expect(stdout_chunks.all? { |c| c.dig('annotations', 'streamed') == true }).to be true

      # Should include all output lines
      stdout_text = stdout_chunks.map { |c| c['text'] }
      expect(stdout_text).to eq(['Line 0', 'Line 1', 'Line 2'])

      # Should have result metadata
      result_chunk = content.find { |c| c.dig('annotations', 'role') == 'result' }
      expect(result_chunk).not_to be_nil
      expect(result_chunk.dig('annotations', 'final')).to be true

      metadata = JSON.parse(result_chunk['text'])
      expect(metadata['exit_code']).to eq(0)
      expect(metadata['outputLines']).to eq(3)
    end

    it 'handles errors with proper annotations' do
      request = {
        'jsonrpc' => '2.0',
        'id' => 2,
        'method' => 'tools/call',
        'params' => {
          'name' => 'execute_code',
          'arguments' => {
            'language' => 'ruby',
            'code' => 'puts "Start"; raise "Error occurred"; puts "End"'
          }
        }
      }

      input.string = "#{JSON.generate(request)}\n"
      input.rewind

      thread = Thread.new { server.run }
      sleep 0.3
      thread.kill

      output.rewind
      response = JSON.parse(output.read.strip)

      content = response['result']['content']

      # Should capture stdout before error
      stdout_chunks = content.select { |c| c.dig('annotations', 'role') == 'stdout' }
      expect(stdout_chunks.first['text']).to eq('Start')

      # Should capture stderr with error
      stderr_chunks = content.select { |c| c.dig('annotations', 'role') == 'stderr' }
      expect(stderr_chunks).not_to be_empty
      expect(stderr_chunks.map { |c| c['text'] }.join("\n")).to include('Error occurred')

      # Should have non-zero exit code
      result_chunk = content.find { |c| c.dig('annotations', 'role') == 'result' }
      metadata = JSON.parse(result_chunk['text'])
      expect(metadata['exit_code']).not_to eq(0)
    end
  end
end
