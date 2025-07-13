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
Basic output demonstration with progress updates.

### advanced_streaming.py
Comprehensive output examples including:
- Multi-line progress updates
- Data processing output
- JSON output formatting
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

## Response Format Documentation

### Successful Execution Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "print('Hello, World!')",
        "mimeType": "text/x-python"
      },
      {
        "type": "text",
        "text": "Hello, World!",
        "annotations": {
          "role": "stdout"
        }
      },
      {
        "type": "text",
        "text": "Exit code: 0\nExecution time: 0.05s",
        "annotations": {
          "final": true
        }
      }
    ],
    "isError": false
  }
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Execution failed: undefined method...",
        "annotations": {
          "role": "error"
        }
      },
      {
        "type": "text",
        "text": "{\"exitCode\": -1, \"executionTime\": \"12ms\", ...}",
        "mimeType": "application/json",
        "annotations": {
          "role": "metadata"
        }
      }
    ],
    "isError": true
  }
}
```

### Content Structure

- **Code**: Original source with appropriate MIME type
- **stdout**: Standard output with `role: stdout` annotation
- **stderr**: Error output with `role: stderr` annotation
- **final**: Execution metadata with exit code and timing

### Multi-line Output Example

For programs with multiple output lines:

```json
{
  "content": [
    {
      "type": "text",
      "text": "for i in range(3): print(f'Step {i}')",
      "mimeType": "text/x-python"
    },
    {
      "type": "text",
      "text": "Step 0\nStep 1\nStep 2",
      "annotations": {"role": "stdout"}
    },
    {
      "type": "text",
      "text": "{\"exitCode\": 0, \"outputLines\": 3, ...}",
      "mimeType": "application/json",
      "annotations": {"role": "metadata", "final": true}
    }
  ],
  "isError": false
}
```

## Session Management Examples

### Stateful Execution

```json
// First request - define a function
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "execute_code",
    "arguments": {
      "language": "python",
      "code": "def greet(name):\n    return f'Hello, {name}!'"
    }
  }
}

// Second request - use the function (automatically available)
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "execute_code",
    "arguments": {
      "language": "python",
      "code": "print(greet('World'))"
    }
  }
}
```

### Reset Session

```json
// Reset Python session only
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "reset_session",
    "arguments": {
      "language": "python"
    }
  }
}

// Reset all language sessions
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "reset_session",
    "arguments": {
      "language": "all"
    }
  }
}
```

## Key Concepts

1. **12 Language Support**: Python, JavaScript, TypeScript, Ruby, Bash, Zsh, Fish, Java, Clojure, Kotlin, Groovy, Scala
2. **Output Capture**: Complete output capture with proper formatting
3. **Session Management**: Stateful execution maintains context across requests
4. **Error Handling**: Comprehensive error capture with proper exit codes
5. **MCP Compliance**: Full Model Context Protocol specification support
6. **JVM Platform**: Java ecosystem languages run on OpenJDK 21