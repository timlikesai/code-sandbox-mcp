# frozen_string_literal: true

require 'open3'
require 'tempfile'
require 'fileutils'
require 'securerandom'
require 'timeout'

module CodeSandboxMcp
  class Executor
    ExecutionResult = Struct.new(:output, :error, :exit_code, :execution_time, keyword_init: true)

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
      start_time = Time.now

      cmd = command + [file_path]
      env = ENV.to_h.merge('HOME' => working_dir)

      execution_time = nil
      begin
        Timeout.timeout(EXECUTION_TIMEOUT) do
          Open3.popen3(env, *cmd, chdir: working_dir) do |_stdin, stdout, stderr, wait_thr|
            output = stdout.read
            error = stderr.read
            exit_code = wait_thr.value.exitstatus
          end
        end

        execution_time = calculate_execution_time(start_time)
        build_success_result(output, error, exit_code || 0, execution_time)
      rescue Timeout::Error
        execution_time ||= calculate_execution_time(start_time)
        build_timeout_result(output, execution_time)
      end
    end

    def calculate_execution_time(start_time)
      Time.now - start_time
    end

    def build_success_result(output, error, exit_code, execution_time)
      ExecutionResult.new(
        output: output.strip,
        error: error.strip,
        exit_code: exit_code,
        execution_time: execution_time
      )
    end

    def build_timeout_result(output, execution_time)
      ExecutionResult.new(
        output: output.strip,
        error: 'Execution timeout exceeded',
        exit_code: -1,
        execution_time: execution_time
      )
    end
  end
end
