# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/session_manager'
require 'code_sandbox_mcp/executor'

RSpec.describe CodeSandboxMcp::SessionManager do
  let(:session_manager) { described_class.instance }
  let(:executor) { CodeSandboxMcp::Executor.new }

  before do
    # Reset singleton instance for tests
    Singleton.__init__(described_class)
  end

  after do
    # Clean up test sessions
    session_manager.clear_all_sessions
  end

  describe '#create_session' do
    it 'creates a new session with unique ID' do
      session_id = session_manager.create_session

      expect(session_id).to match(/^[a-f0-9]{16}$/)
      expect(session_manager.sessions).to have_key(session_id)
    end

    it 'creates a session directory' do
      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)

      expect(Dir.exist?(session[:directory])).to be true
      expect(Dir.exist?(File.join(session[:directory], 'data'))).to be true
      expect(Dir.exist?(File.join(session[:directory], 'output'))).to be true
    end

    it 'reuses existing session if ID provided' do
      session_id = 'test-session-123'
      first_call = session_manager.create_session(session_id: session_id)
      second_call = session_manager.create_session(session_id: session_id)

      expect(first_call).to eq(session_id)
      expect(second_call).to eq(session_id)
      expect(session_manager.sessions.size).to eq(1)
    end
  end

  describe '#execute_in_session' do
    it 'executes code in a persistent session' do
      session_id = session_manager.create_session

      # First execution: define a function
      result1 = session_manager.execute_in_session(
        session_id, 'python', "def add(a, b):\n    return a + b", executor
      )
      expect(result1.exit_code).to eq(0)

      # Second execution: use the function
      result2 = session_manager.execute_in_session(
        session_id, 'python', 'print(add(2, 3))', executor
      )
      expect(result2.exit_code).to eq(0)
      expect(result2.output).to eq('5')
    end

    it 'maintains state across multiple executions' do
      session_id = session_manager.create_session

      # Define variable
      result1 = session_manager.execute_in_session(
        session_id, 'python', 'counter = 0', executor
      )
      expect(result1.exit_code).to eq(0)

      # Increment variable - separate the increment from the print
      result2 = session_manager.execute_in_session(
        session_id, 'python', 'counter += 1', executor
      )
      expect(result2.exit_code).to eq(0)

      result3 = session_manager.execute_in_session(
        session_id, 'python', 'print(counter)', executor
      )
      expect(result3.output).to eq('1')

      # Increment again
      result4 = session_manager.execute_in_session(
        session_id, 'python', 'counter += 1', executor
      )
      expect(result4.exit_code).to eq(0)

      result5 = session_manager.execute_in_session(
        session_id, 'python', 'print(counter)', executor
      )
      expect(result5.output).to eq('2')
    end

    it 'preserves imports across executions' do
      session_id = session_manager.create_session

      # Import module
      result1 = session_manager.execute_in_session(
        session_id, 'python', 'import json', executor
      )
      expect(result1.exit_code).to eq(0)

      # Use imported module
      result2 = session_manager.execute_in_session(
        session_id, 'python', 'print(json.dumps({"test": 123}))', executor
      )
      expect(result2.output).to eq('{"test": 123}')
    end

    it 'executes code with custom filename' do
      session_id = session_manager.create_session

      result = session_manager.execute_in_session(
        session_id, 'python', 'print("Custom filename test")', executor, filename: 'custom_script.py'
      )

      expect(result.exit_code).to eq(0)
      expect(result.output).to include('Custom filename test')
    end

    it 'saves code to file when save: true and filename provided' do
      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)

      result = session_manager.execute_in_session(
        session_id, 'python', 'print("Saved file test")', executor,
        filename: 'saved_script.py', save: true
      )

      expect(result.exit_code).to eq(0)
      expect(result).to respond_to(:saved_path)

      saved_file = File.join(session[:directory], 'data', 'saved_script.py')
      expect(File.exist?(saved_file)).to be true
      expect(File.read(saved_file)).to eq('print("Saved file test")')
    end

    it 'does not save code when filename not provided' do
      session_id = session_manager.create_session

      result = session_manager.execute_in_session(
        session_id, 'python', 'print("No save test")', executor, save: true
      )

      expect(result.exit_code).to eq(0)
      expect(result).not_to respond_to(:saved_path)
    end

    it 'isolates sessions from each other' do
      session1 = session_manager.create_session
      session2 = session_manager.create_session

      # Define variable in session 1
      session_manager.execute_in_session(
        session1, 'python', 'x = 100', executor
      )

      # Try to access in session 2
      result = session_manager.execute_in_session(
        session2, 'python', 'print(x)', executor
      )

      expect(result.exit_code).to eq(1)
      expect(result.error).to include('NameError')
    end

    it 'handles errors without corrupting session' do
      session_id = session_manager.create_session

      # Define variable
      session_manager.execute_in_session(
        session_id, 'python', 'valid_var = 42', executor
      )

      # Execute code with error
      error_result = session_manager.execute_in_session(
        session_id, 'python', 'print(undefined_var)', executor
      )
      expect(error_result.exit_code).to eq(1)

      # Session should still work
      result = session_manager.execute_in_session(
        session_id, 'python', 'print(valid_var)', executor
      )
      expect(result.output).to eq('42')
    end

    it 'works with Ruby sessions' do
      session_id = session_manager.create_session

      # Define method
      session_manager.execute_in_session(
        session_id, 'ruby', "def greet(name)\n  \"Hello, \#{name}!\"\nend", executor
      )

      # Use method
      result = session_manager.execute_in_session(
        session_id, 'ruby', 'puts greet("World")', executor
      )
      expect(result.output).to eq('Hello, World!')
    end

    it 'works with JavaScript sessions' do
      session_id = session_manager.create_session

      # Define function
      session_manager.execute_in_session(
        session_id, 'javascript', 'function multiply(a, b) { return a * b; }', executor
      )

      # Use function
      result = session_manager.execute_in_session(
        session_id, 'javascript', 'console.log(multiply(3, 4))', executor
      )
      expect(result.output).to eq('12')
    end

    it 'works with languages that do not support history (like Bash)' do
      session_id = session_manager.create_session

      # First execution
      result1 = session_manager.execute_in_session(
        session_id, 'bash', 'echo "first"', executor
      )
      expect(result1.exit_code).to eq(0)

      # Second execution (should not include history)
      result2 = session_manager.execute_in_session(
        session_id, 'bash', 'echo "second"', executor
      )
      expect(result2.exit_code).to eq(0)
      expect(result2.output).to eq('second')
    end

    it 'works with non-history languages - no history file exists' do
      session_id = session_manager.create_session

      result = session_manager.execute_in_session(
        session_id, 'java', 'public class Hello { public static void main(String[] args) { System.out.println("Hello Java"); } }', executor
      )
      expect(result.exit_code).to eq(0)
      expect(result.output).to include('Hello Java')
    end

    it 'works with non-history languages with existing history' do
      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)

      history_file = File.join(session[:directory], '.session_history_java')
      File.write(history_file, "public class Previous { }\n")

      result = session_manager.execute_in_session(
        session_id, 'java', 'public class Test { public static void main(String[] args) { System.out.println("Test"); } }', executor
      )
      expect(result.exit_code).to eq(0)
      expect(result.output).to include('Test')
    end

    it 'handles Python multiline definition ending with non-space line (line 275)' do
      session_id = session_manager.create_session

      # First execution to create history
      session_manager.execute_in_session(
        session_id, 'python', "import os\ndef old_func():\n    pass", executor
      )

      code_with_edge_case = <<~PYTHON
        @property
        def new_method(self):
            self.value = 1
            return self.value
        final_var = 42
      PYTHON

      result = session_manager.execute_in_session(
        session_id, 'python', code_with_edge_case, executor
      )

      expect(result.exit_code).to eq(0)
    end
  end

  describe '#get_session' do
    it 'returns session info if exists' do
      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)

      expect(session).to include(
        id: session_id,
        directory: match(/mcp-session-#{session_id}$/),
        execution_count: 0
      )
    end

    it 'returns nil for non-existent session' do
      expect(session_manager.get_session('non-existent')).to be_nil
    end

    it 'updates last_accessed time' do
      session_id = session_manager.create_session
      original_time = session_manager.sessions[session_id][:last_accessed]

      sleep 0.1
      session_manager.get_session(session_id)
      new_time = session_manager.sessions[session_id][:last_accessed]

      expect(new_time).to be > original_time
    end
  end

  describe '#clear_session' do
    it 'removes session and cleans up directory' do
      session_id = session_manager.create_session
      session_dir = session_manager.get_session(session_id)[:directory]

      expect(Dir.exist?(session_dir)).to be true

      result = session_manager.clear_session(session_id)

      expect(result).to be true
      expect(session_manager.get_session(session_id)).to be_nil
      expect(Dir.exist?(session_dir)).to be false
    end

    it 'returns false for non-existent session' do
      expect(session_manager.clear_session('non-existent')).to be false
    end
  end

  describe '#list_sessions' do
    it 'returns empty array when no sessions' do
      expect(session_manager.list_sessions).to eq([])
    end

    it 'returns session information' do
      session_id = session_manager.create_session
      session_manager.execute_in_session(session_id, 'python', 'x = 1', executor)

      sessions = session_manager.list_sessions

      expect(sessions.size).to eq(1)
      expect(sessions.first).to include(
        id: session_id,
        execution_count: 1,
        expired: false
      )
    end
  end

  describe 'session expiration' do
    it 'marks expired sessions' do
      session_id = session_manager.create_session

      # Manually set last_accessed to past
      session_manager.sessions[session_id][:last_accessed] = Time.now - 7200 # 2 hours ago

      # list_sessions might clean up the expired session, so check before calling it
      expect(session_manager.sessions[session_id]).not_to be_nil

      sessions = session_manager.list_sessions
      # After cleanup, the session should be gone
      expect(sessions).to be_empty
    end

    it 'cleans up expired sessions on list' do
      session_id = session_manager.create_session
      session_manager.sessions[session_id][:last_accessed] = Time.now - 7200

      session_manager.list_sessions

      expect(session_manager.get_session(session_id)).to be_nil
    end
  end

  describe 'session limits' do
    it 'enforces maximum session limit' do
      stub_const('CodeSandboxMcp::SessionManager::MAX_SESSIONS', 3)

      # Create max sessions
      session_ids = Array.new(3) { session_manager.create_session }

      # Create one more
      new_session_id = session_manager.create_session

      # Oldest session should be removed
      expect(session_manager.sessions.size).to eq(3)
      expect(session_manager.get_session(session_ids.first)).to be_nil
      expect(session_manager.get_session(new_session_id)).not_to be_nil
    end
  end
end
