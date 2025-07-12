# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSandboxMcp::StreamingExecutor do
  subject(:executor) { described_class.new }

  describe '#execute' do
    context 'with valid code' do
      it 'yields content blocks during execution' do
        blocks = []

        executor.execute_streaming('ruby', 'puts "Line 1"; puts "Line 2"') do |block|
          blocks << block
        end

        expect(blocks).to all(be_a(Hash))
        expect(blocks).to all(have_key(:type))

        # Only content blocks have :content key
        content_blocks = blocks.select { |b| b[:type] == 'content' }
        expect(content_blocks).to all(have_key(:content))

        # Find stdout blocks
        stdout_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stdout' }
        expect(stdout_blocks.size).to be >= 2

        # Check content
        texts = stdout_blocks.map { |b| b.dig(:content, :text) }
        expect(texts).to include('Line 1', 'Line 2')
      end

      it 'yields a final result block' do
        blocks = []

        executor.execute_streaming('python', 'print("Hello")') do |block|
          blocks << block
        end

        result_block = blocks.find { |b| b.dig(:content, :annotations, :role) == 'result' }
        expect(result_block).not_to be_nil
        expect(result_block.dig(:content, :text)).to include('"exit_code": 0')
      end

      it 'streams output line by line' do
        blocks = []

        code = <<~'RUBY'
          5.times do |i|
            puts "Progress: #{i + 1}/5"
            sleep 0.1
          end
        RUBY

        executor.execute_streaming('ruby', code) do |block|
          blocks << block
        end

        stdout_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stdout' }
        expect(stdout_blocks.size).to eq(5)

        stdout_blocks.each_with_index do |block, i|
          expect(block.dig(:content, :text)).to eq("Progress: #{i + 1}/5")
          expect(block.dig(:content, :annotations, :streamed)).to be true
        end
      end
    end

    context 'with stderr output' do
      it 'yields stderr blocks separately' do
        blocks = []

        code = 'import sys; sys.stderr.write("Error message\\n")'
        executor.execute_streaming('python', code) do |block|
          blocks << block
        end

        stderr_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stderr' }
        expect(stderr_blocks).not_to be_empty
        expect(stderr_blocks.first.dig(:content, :text)).to eq('Error message')
      end

      it 'captures both stdout and stderr' do
        blocks = []

        code = <<~PYTHON
          import sys
          print("Out 1")
          sys.stderr.write("Err 1\\n")
          print("Out 2")
          sys.stderr.write("Err 2\\n")
        PYTHON

        executor.execute_streaming('python', code) do |block|
          blocks << block
        end

        stdout_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stdout' }
        stderr_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stderr' }

        expect(stdout_blocks.map { |b| b.dig(:content, :text) }).to contain_exactly('Out 1', 'Out 2')
        expect(stderr_blocks.map { |b| b.dig(:content, :text) }).to contain_exactly('Err 1', 'Err 2')
      end
    end

    context 'with errors' do
      it 'yields error information in stderr' do
        blocks = []

        executor.execute_streaming('ruby', 'raise "Custom error"') do |block|
          blocks << block
        end

        stderr_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stderr' }
        expect(stderr_blocks).not_to be_empty

        error_text = stderr_blocks.map { |b| b.dig(:content, :text) }.join("\n")
        expect(error_text).to include('Custom error')
      end

      it 'includes non-zero exit code in result' do
        blocks = []

        executor.execute_streaming('bash', 'exit 42') do |block|
          blocks << block
        end

        result_block = blocks.find { |b| b.dig(:content, :annotations, :role) == 'result' }
        expect(result_block.dig(:content, :text)).to include('"exit_code": 42')
      end
    end

    context 'with timeout' do
      it 'yields timeout error for long-running code' do
        # Temporarily reduce timeout for faster tests
        stub_const('CodeSandboxMcp::EXECUTION_TIMEOUT', 2)

        blocks = []

        executor.execute_streaming('bash', 'sleep 5') do |block|
          blocks << block
        end

        stderr_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stderr' }
        expect(stderr_blocks).not_to be_empty

        error_text = stderr_blocks.map { |b| b.dig(:content, :text) }.join("\n")
        expect(error_text).to include('timeout')

        result_block = blocks.find { |b| b.dig(:content, :annotations, :role) == 'result' }
        expect(result_block.dig(:content, :text)).to include('"exit_code": -1')
      end
    end

    context 'with unicode output' do
      it 'correctly handles unicode characters' do
        blocks = []

        executor.execute_streaming('python', 'print("Hello 👋 世界")') do |block|
          blocks << block
        end

        stdout_block = blocks.find { |b| b.dig(:content, :annotations, :role) == 'stdout' }
        expect(stdout_block.dig(:content, :text)).to eq('Hello 👋 世界')
      end
    end

    context 'with empty output' do
      it 'still yields a result block for code with no output' do
        blocks = []

        executor.execute_streaming('ruby', 'x = 1 + 1') do |block|
          blocks << block
        end

        result_block = blocks.find { |b| b.dig(:content, :annotations, :role) == 'result' }
        expect(result_block).not_to be_nil
        expect(result_block.dig(:content, :text)).to include('"exit_code": 0')
      end
    end

    context 'with rapid output' do
      it 'handles rapid line output without loss' do
        blocks = []

        code = '100.times { |i| puts i }'
        executor.execute_streaming('ruby', code) do |block|
          blocks << block
        end

        stdout_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'stdout' }
        expect(stdout_blocks.size).to eq(100)

        numbers = stdout_blocks.map { |b| b.dig(:content, :text).to_i }
        expect(numbers).to eq((0..99).to_a)
      end
    end

    context 'with invalid language' do
      it 'raises ArgumentError' do
        expect do
          executor.execute_streaming('invalid', 'code') { |_block| nil }
        end.to raise_error(ArgumentError, /Unsupported language/)
      end
    end

    context 'without block' do
      it 'raises LocalJumpError' do
        expect do
          executor.execute_streaming('ruby', 'puts "hi"')
        end.to raise_error(LocalJumpError)
      end
    end

    context 'with process exceptions' do
      it 'handles StandardError during execution' do
        blocks = []

        # Mock Open3 to raise an error
        allow(Open3).to receive(:popen3).and_raise(StandardError.new('Process creation failed'))

        executor.execute_streaming('python', 'print("test")') do |block|
          blocks << block
        end

        error_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'error' }
        expect(error_blocks).not_to be_empty
        expect(error_blocks.first.dig(:content, :text)).to include('Process creation failed')
      end
    end

    context 'with process cleanup' do
      it 'handles SIGTERM failure gracefully' do
        # Create a mock process that's hard to kill
        allow(Process).to receive(:kill).with('TERM', anything).and_raise(StandardError.new('SIGTERM failed'))
        allow(Process).to receive(:kill).with('KILL', anything).and_return(true)

        blocks = []
        executor.execute_streaming('bash', 'sleep 1') do |block|
          blocks << block
        end

        # Should still complete execution despite cleanup issues
        result_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'result' }
        expect(result_blocks).not_to be_empty
      end

      it 'handles SIGKILL failure gracefully' do
        # Mock both SIGTERM and SIGKILL to fail
        allow(Process).to receive(:kill).and_raise(StandardError.new('Kill failed'))

        blocks = []
        executor.execute_streaming('python', 'print("test")') do |block|
          blocks << block
        end

        # Should still complete execution
        result_blocks = blocks.select { |b| b.dig(:content, :annotations, :role) == 'result' }
        expect(result_blocks).not_to be_empty
      end
    end
  end
end
