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
Examples of code execution in all 12 supported languages with proper request format.

### javascript_example.json
Demonstrates JavaScript code execution with async/await patterns.

### error_handling.json
Shows how errors are handled and returned in the MCP response format.

### JVM Language Examples
- **java_hello_world.json**: Basic Java code execution example
- **clojure_hello_world.json**: Clojure REPL-style execution
- **kotlin_hello_world.json**: Kotlin script execution
- **groovy_hello_world.json**: Groovy dynamic programming example
- **scala_hello_world.json**: Scala functional programming example

### Session Management Examples
- **automatic_session_example.json**: Demonstrates automatic state persistence across executions
- **both_tools_demo.json**: Shows using both execute_code and validate_code tools

### Validation Examples
- **validate_valid_code.json**: Syntax validation for correct code
- **validate_invalid_code.json**: Syntax validation error handling
- **javascript_valid_syntax.json**: JavaScript-specific validation
- **javascript_invalid_syntax.json**: JavaScript syntax error example

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
cat examples/correct_tool_call.json | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest
```

### Testing Language Examples

To execute any language example through the MCP server:
```bash
# Python example
cat examples/correct_tool_call.json | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest

# Java example
cat examples/java_hello_world.json | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest

# Test all languages
cat examples/all_languages.json | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest
```

### Testing Python Scripts

To execute a Python script file through the MCP server:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"'"$(cat examples/progress_tracking.py | jq -Rs .)"'"}}}' | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest
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
2. **Language Support**: Examples cover all 12 supported languages (Python, JavaScript, TypeScript, Ruby, Bash, Zsh, Fish, Java, Clojure, Kotlin, Groovy, Scala)
3. **Error Handling**: Errors are captured and returned with proper exit codes
4. **MCP Compliance**: All examples follow the Model Context Protocol specification
5. **Session Management**: Code execution maintains state across requests for each language
6. **JVM Languages**: Java, Clojure, Kotlin, Groovy, and Scala all run on OpenJDK 21