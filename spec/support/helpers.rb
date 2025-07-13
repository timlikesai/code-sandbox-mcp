# frozen_string_literal: true

module CodeSandboxMcp
  module SpecHelpers
    def create_test_request(method:, params: {}, id: 1)
      {
        'jsonrpc' => '2.0',
        'id' => id,
        'method' => method,
        'params' => params
      }
    end

    def create_execute_request(language:, code:, id: 1)
      create_test_request(
        method: 'tools/call',
        params: {
          'name' => 'execute_code',
          'arguments' => {
            'language' => language,
            'code' => code
          }
        },
        id: id
      )
    end

    def parse_json_response(output)
      output.rewind
      output.string.lines.map { |line| JSON.parse(line.strip) }.last
    end

    def extract_content_by_role(content, role)
      content.select do |c|
        # Handle both string and symbol keys
        annotations = c['annotations'] || c[:annotations]
        next false unless annotations

        (annotations['role'] || annotations[:role]) == role
      end
    end

    def extract_stdout(content)
      extract_content_by_role(content, 'stdout').map { |c| c['text'] || c[:text] }.join("\n")
    end

    def extract_stderr(content)
      extract_content_by_role(content, 'stderr').map { |c| c['text'] || c[:text] }.join("\n")
    end

    METADATA_ROLES = %w[metadata result].freeze

    def extract_metadata(content)
      # Look for both 'metadata' and 'result' roles (different parts use different names)
      meta = content.find { |c| METADATA_ROLES.include?(c.dig('annotations', 'role')) }
      JSON.parse(meta['text']) if meta
    end
  end
end
