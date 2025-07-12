# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'tempfile'
require 'json'

module CodeSandboxMcp
  # StreamingExecutor provides real-time streaming code execution with live output.
  # It executes code in temporary files while streaming stdout and stderr in real-time
  # through a block-based interface, supporting timeouts and error handling.
  class StreamingExecutor
    def execute_streaming(language, code, &)
      raise ArgumentError, "Unsupported language: #{language}" unless LANGUAGES.key?(language)

      config = LANGUAGES[language]

      Tempfile.create(['code', config[:extension]]) do |file|
        file.write(code)
        file.flush
        command = config[:command] + [file.path]

        send_initial_chunks(code, language, &)
        exit_code, output_buffer, error_buffer = execute_with_streaming(command, &)
        send_completion_chunks(exit_code, output_buffer, error_buffer, &)
      end
    end

    # Alias for compatibility
    alias execute execute_streaming

    private

    def send_initial_chunks(code, language)
      yield({
        type: 'content',
        content: {
          type: 'text',
          text: code,
          mimeType: CodeSandboxMcp.mime_type_for(language)
        }
      })

      yield({
        type: 'progress',
        data: {
          operation: 'executing',
          language: language,
          timestamp: Time.now.iso8601
        }
      })
    end

    def execute_with_streaming(command, &)
      exit_code = nil
      output_buffer = []
      error_buffer = []

      begin
        Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          stdout_reader, stderr_reader = setup_stream_readers(stdout, stderr, output_buffer, error_buffer, &)
          exit_code = wait_for_process_with_timeout(wait_thr, &)
          cleanup_threads(stdout_reader, stderr_reader)
        end
      rescue StandardError => e
        send_error_chunk(e, &)
        exit_code = -1
      end

      [exit_code, output_buffer, error_buffer]
    end

    def setup_stream_readers(stdout, stderr, output_buffer, error_buffer, &)
      stdout_reader = Thread.new do
        stream_output(stdout, output_buffer, 'stdout', &)
      rescue StandardError => e
        error_message = e.message
        logger.error "Stdout reader error: #{error_message}" if defined?(logger)
      end

      stderr_reader = Thread.new do
        stream_output(stderr, error_buffer, 'stderr', &)
      rescue StandardError
        logger.error "Stderr reader error: #{error_message}" if defined?(logger)
      end

      [stdout_reader, stderr_reader]
    end

    def stream_output(stream, buffer, role)
      stream.each_line do |line|
        buffer << line
        yield({
          type: 'content',
          content: {
            type: 'text',
            text: line.chomp,
            annotations: {
              role: role,
              streamed: true
            }
          }
        })
      end
    end

    def wait_for_process_with_timeout(wait_thr, &)
      Timeout.timeout(EXECUTION_TIMEOUT) do
        wait_thr.value.exitstatus
      end
    rescue Timeout::Error
      terminate_process(wait_thr.pid)
      send_timeout_chunk(&)
      -1
    end

    def terminate_process(pid)
      begin
        Process.kill('TERM', pid)
      rescue StandardError
        nil
      end
      sleep 0.1
      begin
        Process.kill('KILL', pid)
      rescue StandardError
        nil
      end
    end

    def cleanup_threads(stdout_reader, stderr_reader)
      stdout_reader.join(0.5)
      stderr_reader.join(0.5)
    end

    def send_timeout_chunk
      yield({
        type: 'content',
        content: {
          type: 'text',
          text: 'Execution timeout exceeded',
          annotations: {
            role: 'stderr',
            timeout: true
          }
        }
      })
    end

    def send_error_chunk(error)
      yield({
        type: 'content',
        content: {
          type: 'text',
          text: "Execution error: #{error.message}",
          annotations: {
            role: 'error',
            exception: error.class.name
          }
        }
      })
    end

    def send_completion_chunks(exit_code, output_buffer, error_buffer)
      current_timestamp = Time.now.iso8601

      yield({
        type: 'content',
        content: {
          type: 'text',
          text: JSON.pretty_generate({
                                       exit_code: exit_code,
                                       outputLines: output_buffer.size,
                                       errorLines: error_buffer.size,
                                       timestamp: current_timestamp
                                     }),
          mimeType: 'application/json',
          annotations: {
            role: 'result',
            final: true
          }
        }
      })

      yield({
        type: 'complete',
        data: {
          exitCode: exit_code,
          timestamp: current_timestamp
        }
      })
    end
  end
end
