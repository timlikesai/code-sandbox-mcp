# frozen_string_literal: true

require 'open3'
require 'tempfile'
require 'fileutils'
require 'securerandom'
require 'timeout'

module CodeSandboxMcp
  # Executor provides synchronous code execution with timeout and resource management.
  # It executes code in temporary files and captures stdout, stderr, and exit codes.
  class Executor
    # ExecutionResult encapsulates the results of code execution including
    # output, error messages, exit code, and execution metadata.
    ExecutionResult = Struct.new(:output, :error, :exit_code, keyword_init: true)

    def execute(language, code)
      lang_config = LANGUAGES[language]
      raise ArgumentError, "Unsupported language: #{language}" unless lang_config

      Dir.mktmpdir("code-sandbox-#{SecureRandom.hex(8)}") do |temp_dir|
        file_path = File.join(temp_dir, "main#{lang_config[:extension]}")
        File.write(file_path, code)

        execute_command(lang_config[:command], file_path, temp_dir)
      end
    end

    private

    def execute_command(command, file_path, working_dir)
      output = ''
      error = ''
      exit_code = nil

      cmd = command + [file_path]
      env = ENV.to_h.merge('HOME' => working_dir)

      begin
        Timeout.timeout(EXECUTION_TIMEOUT) do
          Open3.popen3(env, *cmd, chdir: working_dir) do |_stdin, stdout, stderr, wait_thr|
            output = stdout.read
            error = stderr.read
            exit_code = wait_thr.value.exitstatus
          end
        end

        build_success_result(output, error, exit_code || 0)
      rescue Timeout::Error
        build_timeout_result(output)
      end
    end

    def build_success_result(output, error, exit_code)
      ExecutionResult.new(
        output: output.strip,
        error: error.strip,
        exit_code: exit_code
      )
    end

    def build_timeout_result(output)
      ExecutionResult.new(
        output: output.strip,
        error: 'Execution timeout exceeded',
        exit_code: -1
      )
    end
  end
end
