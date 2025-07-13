# Streaming Implementation Documentation

This document captures the current streaming implementation in code-sandbox-mcp for future contribution to the upstream Ruby MCP SDK.

## Overview

The streaming implementation allows real-time output from code execution to be sent to MCP clients as it's generated, rather than waiting for the entire execution to complete. This is crucial for:
- Long-running processes
- Interactive feedback
- Progress monitoring
- Better user experience

## Architecture

### 1. StreamingExecutor

The heart of the streaming implementation is `StreamingExecutor` (lib/code_sandbox_mcp/streaming_executor.rb).

**Key Components:**

```ruby
def execute_with_streaming(code, language, &block)
  # 1. Setup temporary directory and write code file
  # 2. Launch process with Open3.popen3
  # 3. Create reader threads for stdout/stderr
  # 4. Yield chunks as they're produced
  # 5. Handle timeout and cleanup
end
```

**Streaming Flow:**
1. Process launches in subprocess
2. Separate threads read stdout/stderr continuously
3. Each line is yielded immediately via block callback
4. Main thread monitors timeout and process completion
5. Final chunk includes exit status and metadata

### 2. Chunk Types

The system produces three types of chunks:

```ruby
# Progress chunk (initial)
{
  type: :progress,
  message: "Executing #{language} code..."
}

# Content chunk (streamed output)
{
  type: :content,
  content: "output line",
  stream: :stdout  # or :stderr
}

# Complete chunk (final)
{
  type: :complete,
  exit_code: 0,
  execution_time: 1.234
}
```

### 3. MCP Integration

The Server integrates streaming by converting chunks to MCP content blocks:

```ruby
# For each chunk from StreamingExecutor
case chunk[:type]
when :content
  # Convert to MCP content block with annotations
  content_block("text", chunk[:content], {
    role: chunk[:stream].to_s,
    streamed: true
  })
when :complete
  # Final metadata block
  content_block("text", metadata, {
    final: true
  })
end
```

### 4. Thread Management

**Reader Thread Pattern:**
```ruby
reader_thread = Thread.new do
  stream.each_line do |line|
    queue << { type: :content, content: line.chomp, stream: :stdout }
  end
rescue IOError
  # Handle closed stream
ensure
  queue << :eof
end
```

**Key Design Decisions:**
- Non-blocking I/O with thread-based readers
- Queue-based communication between threads
- Graceful timeout handling (SIGTERM then SIGKILL)
- Proper resource cleanup in ensure blocks

## Streaming Protocol Extensions

### Content Block Annotations

The implementation extends standard MCP content blocks with custom annotations:

```json
{
  "type": "text",
  "text": "Hello, world!",
  "annotations": {
    "role": "stdout",
    "streamed": true
  }
}
```

**Annotation Types:**
- `role`: Indicates source stream ("stdout" or "stderr")
- `streamed`: Boolean indicating progressive output
- `final`: Boolean indicating completion metadata

### Response Structure

A streaming response contains multiple content blocks:

```json
{
  "content": [
    {
      "type": "text",
      "text": "Executing python code...",
      "annotations": { "role": "progress" }
    },
    {
      "type": "text", 
      "text": "Hello from Python!",
      "annotations": { "role": "stdout", "streamed": true }
    },
    {
      "type": "text",
      "text": "Error message",
      "annotations": { "role": "stderr", "streamed": true }
    },
    {
      "type": "text",
      "text": "Execution complete in 0.15s",
      "annotations": { "final": true }
    }
  ]
}
```

## Benefits of Streaming

1. **Real-time Feedback**: Users see output as it's generated
2. **Progress Monitoring**: Long-running tasks show incremental progress
3. **Resource Efficiency**: No need to buffer entire output in memory
4. **Timeout Handling**: Can show partial output before timeout
5. **Interactive Debugging**: See where execution hangs or fails

## Implementation Challenges Solved

### 1. Synchronization
- Used thread-safe Queue for inter-thread communication
- Proper mutex usage for shared state
- Careful EOF handling across threads

### 2. Process Management
- Graceful shutdown with signal escalation
- Proper pipe closure to avoid deadlocks
- Resource cleanup in all code paths

### 3. MCP Protocol Compliance
- Maintained valid JSON-RPC structure
- Extended protocol with backward-compatible annotations
- Preserved request-response correlation

## Future SDK Integration Plan

### Proposed API for Ruby MCP SDK

```ruby
# 1. Streaming Response Builder
class MCP::StreamingResponse
  def initialize
    @chunks = []
  end
  
  def add_chunk(content, annotations = {})
    @chunks << MCP::Content::Text.new(content, annotations)
  end
  
  def finalize
    MCP::Tool::Response.new(@chunks)
  end
end

# 2. Streaming Tool Pattern
class StreamingTool < MCP::Tool
  def self.call(message:, server_context:)
    response = MCP::StreamingResponse.new
    
    # Tool can yield chunks progressively
    execute_with_progress do |chunk|
      response.add_chunk(chunk[:content], chunk[:annotations])
    end
    
    response.finalize
  end
end

# 3. Transport-level Streaming (Advanced)
class MCP::Server::Transports::StreamingStdioTransport
  def send_streaming_response(request_id, &block)
    # Send chunks as they're yielded
    block.call do |chunk|
      send_chunk(request_id, chunk)
    end
    send_final_response(request_id)
  end
end
```

### Integration Steps

1. **Phase 1**: Add StreamingResponse class to SDK
2. **Phase 2**: Extend Tool base class with streaming support
3. **Phase 3**: Add transport-level streaming (optional)
4. **Phase 4**: Document patterns and best practices

### Backward Compatibility

The streaming extensions are designed to be backward compatible:
- Clients that don't understand streaming see all content blocks
- Annotations are optional metadata
- Standard response structure is maintained

## Code Examples

### Current Implementation (Simplified)

```ruby
# StreamingExecutor usage
executor = StreamingExecutor.new
executor.execute_with_streaming(code, "python") do |chunk|
  case chunk[:type]
  when :content
    yield content_block("text", chunk[:content], {
      role: chunk[:stream].to_s,
      streamed: true
    })
  when :complete
    yield content_block("text", "Complete: #{chunk[:exit_code]}", {
      final: true
    })
  end
end
```

### Future SDK Implementation

```ruby
# How it could work with SDK
class ExecuteCodeTool < MCP::StreamingTool
  def self.call(message:, server_context:)
    code = message.params["code"]
    language = message.params["language"]
    
    stream_response do |response|
      StreamingExecutor.execute(code, language) do |chunk|
        response.add_chunk(chunk[:content], {
          role: chunk[:stream],
          streamed: true
        })
      end
    end
  end
end
```

## Testing Streaming

Key test scenarios for streaming:
1. Output arrives in correct order
2. Stdout/stderr are properly separated
3. Partial output on timeout
4. Large output handling
5. Binary output handling
6. Process cleanup verification

## Conclusion

The streaming implementation provides significant UX improvements for code execution tools. By documenting this approach, we can contribute it back to the Ruby MCP SDK when the project is ready to support streaming responses. The design is extensible and maintains backward compatibility while enabling real-time feedback for long-running operations.