# frozen_string_literal: true

require 'securerandom'
require 'fileutils'
require 'time'

require 'singleton'

module CodeSandboxMcp
  # Manages persistent execution sessions for stateful code execution
  class SessionManager # rubocop:disable Metrics/ClassLength
    include Singleton

    SESSION_TIMEOUT = 3600 # 1 hour in seconds
    MAX_SESSIONS = 100
    SESSION_DIR_PREFIX = 'mcp-session'

    attr_reader :sessions

    def initialize(base_dir: '/tmp')
      @base_dir = base_dir
      @sessions = {}
      @mutex = Mutex.new
    end

    # Create a new session with a unique ID
    def create_session(session_id: nil)
      perform_session_cleanup
      session_id ||= generate_session_id

      @mutex.synchronize do
        return session_id if sessions[session_id]

        initialize_new_session(session_id)
      end
    end

    private

    def perform_session_cleanup
      # Clean up expired sessions first
      expired_ids = @mutex.synchronize { cleanup_expired_sessions }
      expired_ids.each { |id| clear_session(id) }

      # Enforce session limit
      ids_to_remove = @mutex.synchronize { enforce_session_limit }
      ids_to_remove&.each { |id| clear_session(id) }
    end

    def initialize_new_session(session_id)
      session_dir = create_session_directory(session_id)

      sessions[session_id] = {
        id: session_id,
        directory: session_dir,
        created_at: Time.now,
        last_accessed: Time.now,
        execution_count: 0,
        environment: {}
      }

      session_id
    end

    public

    # Get an existing session or create a new one
    def get_or_create_session(session_id)
      @mutex.synchronize do
        if sessions[session_id]
          sessions[session_id][:last_accessed] = Time.now
          return sessions[session_id]
        end
      end

      # Create session outside the mutex to avoid deadlock
      create_session(session_id: session_id)

      @mutex.synchronize do
        sessions[session_id]
      end
    end

    # Get session info without creating
    def get_session(session_id)
      @mutex.synchronize do
        session = sessions[session_id]
        return nil unless session

        session[:last_accessed] = Time.now
        session
      end
    end

    # Execute code in a session context
    def execute_in_session(session_id, language, code, executor)
      session = get_or_create_session(session_id)

      @mutex.synchronize do
        session[:execution_count] += 1
      end

      # Create history file for the session
      history_file = File.join(session[:directory], ".session_history_#{language}")

      # For interpreted languages, prepend history
      prepared_code = prepare_code_with_history(language, code, history_file)

      # Execute in the session directory
      result = executor.execute_with_dir(language, prepared_code, session[:directory])

      # Save successful execution to history
      append_to_history(history_file, code, language) if result.exit_code.zero?

      result
    end

    # Clear a specific session
    def clear_session(session_id) # rubocop:disable Naming/PredicateMethod
      session = @mutex.synchronize { sessions.delete(session_id) }
      return false unless session

      FileUtils.rm_rf(session[:directory])
      true
    end

    # Clear all sessions
    def clear_all_sessions
      session_ids = @mutex.synchronize { sessions.keys }
      session_ids.each { |id| clear_session(id) }
      @mutex.synchronize { sessions.clear }
    end

    # List active sessions
    def list_sessions
      # Clean up expired sessions first (outside mutex)
      expired_ids = @mutex.synchronize { cleanup_expired_sessions }
      expired_ids.each { |id| clear_session(id) }

      @mutex.synchronize do
        sessions.map do |id, session|
          {
            id: id,
            created_at: session[:created_at].iso8601,
            last_accessed: session[:last_accessed].iso8601,
            execution_count: session[:execution_count],
            expired: session_expired?(session)
          }
        end
      end
    end

    private

    def generate_session_id
      SecureRandom.hex(8)
    end

    def create_session_directory(session_id)
      dir_name = "#{SESSION_DIR_PREFIX}-#{session_id}"
      session_dir = File.join(@base_dir, dir_name)
      FileUtils.mkdir_p(session_dir)

      # Create subdirectories for different purposes
      FileUtils.mkdir_p(File.join(session_dir, 'data'))
      FileUtils.mkdir_p(File.join(session_dir, 'output'))

      session_dir
    end

    def cleanup_expired_sessions
      sessions.select { |_, session| session_expired?(session) }.keys
      # Clear sessions outside of the mutex to avoid deadlock
    end

    def enforce_session_limit
      return if sessions.size < MAX_SESSIONS

      # Remove oldest sessions
      sorted_sessions = sessions.sort_by { |_, session| session[:last_accessed] }
      sessions_to_remove = sorted_sessions.take(sessions.size - MAX_SESSIONS + 1)

      # Return IDs to remove, clear them outside mutex
      sessions_to_remove.map(&:first)
    end

    def session_expired?(session)
      Time.now - session[:last_accessed] > SESSION_TIMEOUT
    end

    def prepare_code_with_history(language, code, history_file)
      return code unless File.exist?(history_file)

      history = File.read(history_file)
      return code if history.strip.empty?

      case language
      when 'python', 'javascript', 'typescript', 'ruby'
        # For these languages, prepend previous definitions
        "#{history}\n#{code}"
      else
        # For other languages, just execute the new code
        code
      end
    end

    def append_to_history(history_file, code, language)
      filtered_code = if state_modifying_assignment?(code, language)
                        code
                      else
                        filter_code_for_history(code, language)
                      end

      return if filtered_code.strip.empty?

      File.open(history_file, 'a') do |f|
        f.puts filtered_code
        f.puts
      end
    end

    def state_modifying_assignment?(code, language)
      language == 'python' && code.match?(%r{^\s*\w+\s*[+\-*/]?=})
    end

    def filter_code_for_history(code, language)
      case language
      when 'python'
        filter_python_code(code)
      when 'javascript', 'typescript'
        filter_javascript_code(code)
      when 'ruby'
        filter_ruby_code(code)
      else
        ''
      end
    end

    def filter_python_code(code)
      lines = code.lines
      filtered_lines = []
      in_multiline_def = false

      lines.each_with_index do |line, i|
        result = process_python_line(line, i, lines, in_multiline_def)
        filtered_lines << line if result[:keep]
        in_multiline_def = result[:in_multiline_def]
      end

      filtered_lines.join
    end

    def process_python_line(line, index, lines, in_multiline_def)
      if start_of_python_definition?(line, index, lines)
        { keep: true, in_multiline_def: true }
      elsif in_multiline_def
        process_multiline_python(line, in_multiline_def)
      else
        { keep: should_keep_python_line?(line), in_multiline_def: false }
      end
    end

    def start_of_python_definition?(line, index, lines)
      line.match?(/^\s*(def|class)\s+/) ||
        (index.positive? && lines[index - 1].strip.start_with?('@'))
    end

    def process_multiline_python(line, _in_multiline_def)
      stripped = line.strip
      if line.match?(/^\S/) && !stripped.empty?
        { keep: should_keep_python_line?(line), in_multiline_def: false }
      else
        { keep: true, in_multiline_def: true }
      end
    end

    def should_keep_python_line?(line)
      stripped = line.strip
      stripped.empty? ||
        stripped.start_with?('import ', 'from ', '@') ||
        line =~ /^\w+\s*=/ ||
        line =~ /^\s+\w+\s*=/
    end

    def filter_javascript_code(code)
      code.lines.select do |line|
        line.strip.empty? ||
          line.include?('import ') || line.include?('require(') ||
          line.match?(/^\s*(function|const|let|var|class)/) ||
          line.match?(/^\s*\w+\s*=/)
      end.join
    end

    def filter_ruby_code(code)
      lines = code.lines
      filtered_lines = []
      in_multiline_def = false

      lines.each do |line|
        stripped = line.strip

        if line.match?(/^\s*(def|class|module)\s+/)
          in_multiline_def = true
          filtered_lines << line
        elsif in_multiline_def
          filtered_lines << line
          in_multiline_def = false if stripped == 'end'
        elsif should_keep_ruby_line?(line)
          filtered_lines << line
        end
      end

      filtered_lines.join
    end

    def should_keep_ruby_line?(line)
      stripped = line.strip
      stripped.empty? ||
        line.start_with?('require ', 'require_relative ') ||
        line =~ /^\s*[A-Z]\w*\s*=/ ||
        line =~ /^\s*@\w+\s*=/
    end
  end
end
