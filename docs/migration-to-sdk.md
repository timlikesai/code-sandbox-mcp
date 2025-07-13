# Migration Guide: From Streaming to Ruby MCP SDK

This guide outlines the migration path from our custom streaming implementation to the official Ruby MCP SDK.

## Overview

We're migrating from a custom MCP server implementation with streaming support to the official Ruby MCP SDK. This involves:
- Removing custom JSON-RPC handling
- Converting to SDK's tool patterns
- Temporarily removing streaming (to be contributed back later)
- Maintaining all other functionality

## Key Changes

### 1. Server Architecture

**Before (Custom Implementation):**
```ruby
# bin/code-sandbox-mcp
server = CodeSandboxMCP::Server.new
server.run

# lib/code_sandbox_mcp/server.rb
class Server
  def run
    loop do
      line = $stdin.gets
      request = JSON.parse(line)
      response = handle_request(request)
      $stdout.puts response.to_json
    end
  end
end
```

**After (SDK Implementation):**
```ruby
# bin/code-sandbox-mcp
require 'mcp'

server = MCP::Server.new(
  name: "code-sandbox-mcp",
  version: CodeSandboxMCP::VERSION,
  tools: [CodeSandboxMCP::ExecuteCodeTool, CodeSandboxMCP::ValidateCodeTool]
)

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

### 2. Tool Implementation

**Before (Custom Tool Handling):**
```ruby
def handle_tools_call(request)
  case request["params"]["name"]
  when "execute_code"
    execute_code_tool(request["params"]["arguments"])
  when "validate_code"
    validate_code_tool(request["params"]["arguments"])
  end
end
```

**After (SDK Tool Classes):**
```ruby
module CodeSandboxMCP
  class ExecuteCodeTool < MCP::Tool
    def self.name
      "execute_code"
    end

    def self.description
      "Execute code in a secure Docker sandbox"
    end

    def self.input_schema
      {
        type: "object",
        properties: {
          language: {
            type: "string",
            enum: LANGUAGES.keys
          },
          code: {
            type: "string"
          }
        },
        required: ["language", "code"]
      }
    end

    def self.call(message:, server_context:)
      params = message.params
      result = Executor.new.execute(params["code"], params["language"])
      
      # Convert to batch response (no streaming)
      content = [
        MCP::Content::Text.new(params["code"], { mime_type: mime_type_for(params["language"]) }),
        MCP::Content::Text.new(result.output, { role: "stdout" }) if result.output.present?,
        MCP::Content::Text.new(result.error, { role: "stderr" }) if result.error.present?,
        MCP::Content::Text.new(completion_metadata(result), { final: true })
      ].compact

      MCP::Tool::Response.new(content)
    end
  end
end
```

### 3. Executor Changes

**Before (Streaming):**
```ruby
class StreamingExecutor
  def execute_with_streaming(code, language, &block)
    # Complex streaming implementation with threads
    yield { type: :progress, message: "Executing..." }
    
    stdout_thread = Thread.new do
      stdout.each_line do |line|
        yield { type: :content, content: line, stream: :stdout }
      end
    end
    
    # ... more streaming logic
  end
end
```

**After (Batch):**
```ruby
class Executor
  def execute(code, language)
    Dir.mktmpdir do |dir|
      file_path = write_code_file(dir, code, language)
      
      output, error, status = Open3.capture3(
        *command_for(language, file_path),
        timeout: EXECUTION_TIMEOUT
      )
      
      ExecutionResult.new(
        output: output,
        error: error,
        exit_code: status.exitstatus
      )
    end
  end
end
```

### 4. Response Format Changes

**Before (Streaming Response):**
```json
{
  "content": [
    { "type": "text", "text": "print('Hello')", "annotations": { "mime_type": "text/x-python" } },
    { "type": "text", "text": "Executing python code...", "annotations": { "role": "progress" } },
    { "type": "text", "text": "Hello", "annotations": { "role": "stdout", "streamed": true } },
    { "type": "text", "text": "Exit code: 0", "annotations": { "final": true } }
  ]
}
```

**After (Batch Response):**
```json
{
  "content": [
    { "type": "text", "text": "print('Hello')", "annotations": { "mime_type": "text/x-python" } },
    { "type": "text", "text": "Hello", "annotations": { "role": "stdout" } },
    { "type": "text", "text": "Exit code: 0\nExecution time: 0.15s", "annotations": { "final": true } }
  ]
}
```

## Migration Steps

### Step 1: Add SDK Dependency

```ruby
# Gemfile
gem 'mcp', '~> 0.1.0'  # Use latest version
```

### Step 2: Create Tool Classes

1. Create `lib/code_sandbox_mcp/tools/` directory
2. Implement `ExecuteCodeTool` and `ValidateCodeTool`
3. Convert tool schemas to SDK format

### Step 3: Simplify Executor

1. Remove `StreamingExecutor`
2. Update `Executor` to return complete results
3. Remove threading and queue logic

### Step 4: Update Entry Point

1. Replace custom server with SDK server
2. Configure stdio transport
3. Register tools

### Step 5: Update Tests

1. Update integration tests for new response format
2. Remove streaming-specific tests
3. Add SDK-specific test helpers

## Handling Removed Features

### Streaming Output
- **Impact**: No real-time output during execution
- **Mitigation**: Show clear "Executing..." message
- **Future**: Implement streaming in SDK (see streaming-implementation.md)

### Progress Updates
- **Impact**: No intermediate progress
- **Mitigation**: Return execution time in final output
- **Future**: Could poll for status if needed

## Benefits of Migration

1. **Reduced Maintenance**: No custom protocol handling
2. **Better Compatibility**: Official SDK ensures protocol compliance
3. **Cleaner Code**: Remove ~40% of codebase
4. **Future Features**: Automatic support for new MCP features
5. **Community Support**: Benefit from SDK improvements

## Testing the Migration

### Smoke Tests
```bash
# Test basic execution
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"print(\"Hello\")"}}}' | docker run --rm -i code-sandbox-mcp

# Test error handling
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"invalid syntax"}}}' | docker run --rm -i code-sandbox-mcp
```

### Integration Tests
- Update example JSON files to match new response format
- Ensure all languages still work
- Verify timeout handling
- Check memory and CPU limits

## Rollback Plan

If issues arise:
1. Git tag the last streaming version
2. Keep streaming implementation in separate branch
3. Can quickly revert by switching branches
4. Docker images tagged with version allow rollback

## Timeline

1. **Week 1**: Implement basic SDK integration
2. **Week 2**: Update tests and documentation
3. **Week 3**: Testing and bug fixes
4. **Future**: Contribute streaming back to SDK

## Conclusion

This migration trades temporary loss of streaming for significant code simplification and better long-term maintainability. The streaming feature can be contributed back to the SDK, benefiting the entire MCP ecosystem.