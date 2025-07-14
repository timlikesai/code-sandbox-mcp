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
      lang_config = validate_language!(language)

      Dir.mktmpdir("code-sandbox-#{SecureRandom.hex(8)}") do |temp_dir|
        execute_in_directory(language, code, temp_dir, lang_config)
      end
    end

    def execute_with_dir(language, code, working_dir)
      lang_config = validate_language!(language)
      execute_in_directory(language, code, working_dir, lang_config)
    end

    private

    def execute_in_directory(_language, code, directory, lang_config)
      file_path = File.join(directory, "main#{lang_config[:extension]}")
      File.write(file_path, code)
      execute_command(lang_config[:command], file_path, directory)
    end

    def validate_language!(language)
      lang_config = LANGUAGES[language]
      raise ArgumentError, "Unsupported language: #{language}" unless lang_config

      lang_config
    end

    def execute_command(command, file_path, working_dir)
      start_time = Time.now
      cmd = command + [file_path]
      env = ENV.to_h.merge('HOME' => working_dir)

      debug_log("Command: #{cmd.join(' ')}")
      debug_log("Working dir: #{working_dir}")

      begin
        output, error, exit_code = run_command_with_timeout(env, cmd, working_dir)
        execution_time = Time.now - start_time

        debug_log("Exit code: #{exit_code}")
        debug_log("Output: #{output.length} chars") if output && !output.empty?
        debug_log("Error: #{error}") if error && !error.empty?
        debug_log("Execution time: #{format('%.2f', execution_time)}s")

        build_result(output: output, error: error, exit_code: exit_code || 0, execution_time: execution_time)
      rescue Timeout::Error
        execution_time = Time.now - start_time
        build_result(output: '', error: 'Execution timeout exceeded', exit_code: -1, execution_time: execution_time)
      end
    end

    def clean_output(output)
      output.to_s.strip
    end

    def build_result(output:, error:, exit_code:, execution_time:)
      ExecutionResult.new(
        output: clean_output(output),
        error: clean_output(error),
        exit_code: exit_code,
        execution_time: execution_time
      )
    end

    def debug_log(message)
      return unless ENV['RUNNER_DEBUG'] == '1' || ENV['VERBOSE'] == 'true'

      puts "[DEBUG] #{message}"
    end

    def run_command_with_timeout(env, cmd, working_dir)
      output = ''
      error = ''
      exit_code = nil

      Timeout.timeout(EXECUTION_TIMEOUT) do
        Open3.popen3(env, *cmd, chdir: working_dir) do |_stdin, stdout, stderr, wait_thr|
          output = stdout.read
          error = stderr.read
          exit_code = wait_thr.value.exitstatus
        end
      end

      [output, error, exit_code]
    end
  end
end
