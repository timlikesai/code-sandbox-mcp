# Code Sandbox MCP Examples

This directory contains examples demonstrating various features and usage patterns of the Code Sandbox MCP server.

## JSON Examples

### mcp_protocol_flow.json
Complete MCP protocol flow showing the full lifecycle:
- Server initialization
- Tool discovery
- Code execution
- Response handling

### correct_tool_call.json
Basic example of a properly formatted MCP tool call for code execution.

### all_languages.json
Examples of code execution in all 7 supported languages with proper request format.

### javascript_example.json
Demonstrates JavaScript code execution with async/await patterns.

### error_handling.json
Shows how errors are handled and returned in the MCP response format.

## Python Scripts

### client_usage_example.py
Demonstrates how to interact with the MCP server programmatically:
```bash
python examples/client_usage_example.py
```

### progress_tracking.py
Example code showing various progress tracking patterns:
- Simple progress counters
- Visual progress bars
- Multi-stage operations
- Percentage calculations

### streaming_demo.py
Basic streaming output demonstration with real-time updates.

### advanced_streaming.py
Comprehensive streaming examples including:
- Multi-line progress updates
- Real-time data processing
- JSON streaming output
- ANSI color codes

### multi_language_demo.py
Generates example requests for multiple programming languages:
- Ruby
- Bash
- TypeScript

## Usage

### Testing with Docker

To test any JSON example:
```bash
cat examples/correct_tool_call.json | docker run --rm -i code-sandbox:latest
```

### Testing Python Examples

To execute a Python example through the MCP server:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"'"$(cat examples/progress_tracking.py | jq -Rs .)"'"}}}' | docker run --rm -i code-sandbox:latest
```

### Understanding the Response Format

All responses follow the MCP protocol with streaming content blocks:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "code content",
        "mimeType": "text/x-python"
      },
      {
        "type": "text",
        "text": "output line",
        "annotations": {
          "role": "stdout",
          "streamed": true
        }
      },
      {
        "type": "text",
        "text": "execution metadata",
        "mimeType": "application/json",
        "annotations": {
          "role": "metadata",
          "final": true
        }
      }
    ],
    "isError": false
  }
}
```

## Key Concepts

1. **Streaming Output**: Output is captured line-by-line and included in the response
2. **Language Support**: Examples cover all 7 supported languages
3. **Error Handling**: Errors are captured and returned with proper exit codes
4. **MCP Compliance**: All examples follow the Model Context Protocol specification