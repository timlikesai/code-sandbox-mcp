# frozen_string_literal: true

module ToolHelpers
  def expect_successful_response(result, expected_stdout: nil)
    expect(result.to_h[:isError]).to be false
    return unless expected_stdout

    stdout_block = result.to_h[:content].find { |c| c.dig(:annotations, :role) == 'stdout' }
    expect(stdout_block[:text]).to eq(expected_stdout)
  end

  def expect_error_response(result, expected_message: nil)
    expect(result.to_h[:isError]).to be true
    return unless expected_message

    expect(result.to_h[:content].first[:text]).to include(expected_message)
  end

  def expect_valid_tool_metadata(tool_class, expected_name)
    expect_valid_tool_name(tool_class, expected_name)
    expect_valid_tool_description(tool_class)
    expect_valid_tool_schema(tool_class)
  end

  private

  def expect_valid_tool_name(tool_class, expected_name)
    expect(tool_class.name_value).to eq(expected_name)
  end

  def expect_valid_tool_description(tool_class)
    expect(tool_class.description_value).to be_a(String)
    expect(tool_class.description_value).not_to be_empty
  end

  def expect_valid_tool_schema(tool_class)
    schema_hash = tool_class.input_schema_value.to_h
    expect(schema_hash[:type]).to eq('object')
    expect(schema_hash[:properties]).to include(:language, :code)
    expect(schema_hash[:required]).to eq(%i[language code])
  end

  def skip_if_command_unavailable(command)
    skip "#{command} not available" unless system("which #{command} > /dev/null 2>&1")
  end
end

RSpec.configure do |config|
  config.include ToolHelpers
end
