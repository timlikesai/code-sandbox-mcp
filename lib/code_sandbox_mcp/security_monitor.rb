# frozen_string_literal: true

module CodeSandboxMcp
  class SecurityMonitor
    DANGEROUS_PATTERNS = [
      # Network operations
      /urllib\.request|requests\.|fetch\(|http\.|https\./,
      /curl\s|wget\s/,
      %r{socket\.|net/http|Net::HTTP},

      # System operations
      /subprocess\.|system\(|exec\(|`[^`]*`/,
      /open3|popen/i,

      # Package managers
      /pip\s+install|npm\s+install|gem\s+install/,
      /easy_install|yarn\s+add/,

      # File operations that could be dangerous
      %r{/proc/|/sys/|/dev/},
      %r{\.\./|\.\.\\|\.\.[/\\]},

      # Potential reverse shells
      %r{/dev/tcp|/dev/udp},
      /nc\s|netcat|telnet/,

      # Environment access
      /ENV\[|process\.env|os\.environ/
    ].freeze

    RESOURCE_LIMITS = {
      max_network_connections: 5,
      max_memory_mb: 256,
      max_execution_time: 30,
      max_file_descriptors: 100
    }.freeze

    class SecurityViolation < StandardError
      attr_reader :violation_type, :details

      def initialize(violation_type, details = nil)
        @violation_type = violation_type
        @details = details
        super("Security violation: #{violation_type} - #{details}")
      end
    end

    class << self
      def scan_code(code, _language)
        violations = []

        DANGEROUS_PATTERNS.each_with_index do |pattern, index|
          next unless code.match?(pattern)

          match = code.match(pattern)
          violations << {
            pattern_id: index,
            pattern: pattern.source,
            match: match.to_s,
            line: find_line_number(code, match.offset(0).first)
          }
        end

        violations
      end

      def check_resource_usage
        violations = []

        # Check network connections
        begin
          netstat_output = `netstat -an 2>/dev/null | grep ESTABLISHED | wc -l`.strip.to_i
          if netstat_output > RESOURCE_LIMITS[:max_network_connections]
            violations << SecurityViolation.new(
              :excessive_network_connections,
              "#{netstat_output} connections (max: #{RESOURCE_LIMITS[:max_network_connections]})"
            )
          end
        rescue StandardError
          # netstat might not be available - skip this check
        end

        # Check memory usage
        begin
          pid = Process.pid
          memory_kb = `ps -o rss= -p #{pid}`.strip.to_i
          memory_mb = memory_kb / 1024

          if memory_mb > RESOURCE_LIMITS[:max_memory_mb]
            violations << SecurityViolation.new(
              :excessive_memory_usage,
              "#{memory_mb}MB used (max: #{RESOURCE_LIMITS[:max_memory_mb]}MB)"
            )
          end
        rescue StandardError
          # ps might not be available - skip this check
        end

        violations
      end

      def validate_network_enabled_execution(code, language)
        violations = scan_code(code, language)

        if violations.any?
          {
            allowed: false,
            violations: violations,
            recommendation: 'Consider using --network none for security'
          }
        else
          {
            allowed: true,
            violations: [],
            recommendation: 'Code appears safe for network execution'
          }
        end
      end

      private

      def find_line_number(code, char_offset)
        code[0, char_offset].count("\n") + 1
      end
    end
  end
end
