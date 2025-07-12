# Code Sandbox MCP Server (Ruby)

A secure Docker-based MCP server for executing code in multiple languages, implemented in Ruby.

## Features

- **7 Supported Languages**: Python, JavaScript, TypeScript, Ruby, Bash, Zsh, Fish
- **Secure Execution**: Runs in Docker with strict resource limits
- **Ruby 3.4**: Uses latest stable Ruby version
- **Full MCP Protocol**: Implements Model Context Protocol for tool calling
- **Comprehensive Testing**: RSpec test suite with high coverage

## Installation

```bash
# Build the Docker image
docker compose build

# Run tests (optional)
docker compose run --rm code-sandbox bundle exec rspec
```

## Configuration

Add this configuration to:
- **Claude Desktop**: Settings file
- **Claude Code**: `.mcp.json` file in your project root, or user-wide settings

```json
{
  "mcpServers": {
    "code-sandbox": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "code-sandbox:latest"]
    }
  }
}
```

**Claude Code CLI**: You can also add via command line:
```bash
claude-code mcp add code-sandbox docker run --rm -i code-sandbox:latest
```

### Advanced Configuration (Optional)

For additional security hardening:

```json
{
  "mcpServers": {
    "code-sandbox": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "--read-only",
        "--tmpfs", "/tmp",
        "--tmpfs", "/app/tmp", 
        "--memory", "512m",
        "--cpus", "0.5",
        "--network", "none",
        "--security-opt", "no-new-privileges",
        "--cap-drop", "ALL",
        "code-sandbox:latest"
      ]
    }
  }
}
```

### Testing the Setup

Test the Docker container directly:

```bash
# Quick test
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"print(\"Hello World!\")"}}}' | docker run --rm -i code-sandbox:latest

# Debug mode
docker run --rm -it code-sandbox:latest bash
```

## Usage

The server exposes one tool: `execute_code`

Output is automatically collected and streamed internally, providing real-time execution while maintaining MCP protocol compatibility.

### Example Request:
```json
{
  "tool": "execute_code",
  "arguments": {
    "language": "python",
    "code": "print('Hello, World!')"
  }
}
```

### Response Format (MCP Standard):
```json
{
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
      "text": "{\"exitCode\": 0, \"executionTime\": \"45ms\", \"language\": \"python\", \"timestamp\": \"2024-01-12T10:30:45Z\"}",
      "mimeType": "application/json",
      "annotations": {
        "role": "metadata"
      }
    }
  ],
  "isError": false
}
```

### Content Structure:
- **Code**: Original source code with appropriate MIME type
- **stdout**: Standard output with `role: stdout` annotation
- **stderr**: Error output with `role: stderr` annotation (if any)
- **metadata**: JSON-formatted execution details

### Error Response:
```json
{
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
```

### Long-Running Process Example:
```json
{
  "tool": "execute_code",
  "arguments": {
    "language": "python",
    "code": "for i in range(5):\n    print(f'Step {i}')\n    import time; time.sleep(1)"
  }
}
```

The server internally streams output as it's produced, then returns all content in the response:
```json
{
  "content": [
    {
      "type": "text",
      "text": "for i in range(5):\n    print(f'Step {i}')\n    import time; time.sleep(1)",
      "mimeType": "text/x-python"
    },
    {
      "type": "text",
      "text": "Step 0",
      "annotations": {"role": "stdout", "streamed": true}
    },
    {
      "type": "text",
      "text": "Step 1",
      "annotations": {"role": "stdout", "streamed": true}
    },
    {
      "type": "text",
      "text": "Step 2",
      "annotations": {"role": "stdout", "streamed": true}
    },
    {
      "type": "text",
      "text": "Step 3",
      "annotations": {"role": "stdout", "streamed": true}
    },
    {
      "type": "text",
      "text": "Step 4",
      "annotations": {"role": "stdout", "streamed": true}
    },
    {
      "type": "text",
      "text": "{\"exitCode\": 0, \"outputLines\": 5, ...}",
      "mimeType": "application/json",
      "annotations": {"role": "metadata", "final": true}
    }
  ],
  "isError": false
}
```

## Security

The Docker container provides multiple layers of security:

- **Container Isolation**: Each execution runs in its own container
- **Resource Limits**: 512MB memory, 0.5 CPU limits
- **Network Disabled**: `--network none` - no internet access
- **Read-only Filesystem**: `--read-only` with writable `/tmp` and `/app/tmp` only
- **No Privileges**: `--security-opt no-new-privileges` and `--cap-drop ALL`
- **Non-root User**: Executes as unprivileged `sandbox` user inside container
- **Auto-cleanup**: `--rm` removes containers after execution
- **Configurable Timeout**: Code execution timeout (default 30s, configurable via `EXECUTION_TIMEOUT`)

### Security Options Explained

```bash
--read-only                      # Root filesystem cannot be modified
--tmpfs /tmp                     # In-memory temporary directory
--tmpfs /app/tmp                 # In-memory app temporary directory  
--memory 512m                    # Limit memory usage
--cpus 0.5                       # Limit CPU usage to 50%
--network none                   # No network access
--security-opt no-new-privileges # Prevent privilege escalation
--cap-drop ALL                   # Remove all Linux capabilities
--rm                             # Auto-remove container after use
-e EXECUTION_TIMEOUT=30          # Code execution timeout (seconds)
```

### Environment Variables

The container supports these environment variables:

- `EXECUTION_TIMEOUT` - Code execution timeout in seconds (default: 30)
- `WORKDIR` - Working directory inside container (default: /app)

## Examples

The `examples/` directory contains comprehensive examples demonstrating:
- Complete MCP protocol flow
- Code execution in all supported languages
- Streaming output patterns
- Error handling
- Client usage patterns

See [examples/README.md](examples/README.md) for detailed documentation.

## Development

### Local Development

```bash
# Install dependencies locally
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
bundle exec rubocop --autocorrect-all  # Auto-fix style issues

# Code quality checks
bundle exec reek                       # Detect code smells

# Security checks
bundle exec bundler-audit check        # Check for dependency vulnerabilities

# Run all checks
bundle exec rake
```

### Docker-based Testing (Recommended)

Test in the actual deployment environment with all supported languages:

```bash
# Run all tests in Docker container
bundle exec rake docker:test

# Build Docker images
bundle exec rake docker:build          # Build production image
bundle exec rake docker:build_test     # Build test image
bundle exec rake docker:build_all      # Build both images

# Interactive shell in test environment
bundle exec rake docker:shell

# Or run individual commands:
docker compose run --rm code-sandbox-test bundle exec rspec
docker compose run --rm code-sandbox-test bundle exec rubocop
docker compose run --rm code-sandbox-test bundle exec reek
docker compose run --rm code-sandbox-test bundle exec bundler-audit check
```

### Other Development Tasks

```bash
# Test examples
./examples/test_examples.sh

# Test Docker container
docker run --rm -it code-sandbox:latest bash
```

### Code Quality Tools

This project uses several tools to maintain code quality and security:

- **RuboCop**: Ruby style guide enforcement with custom configuration
  - Includes `rubocop-performance` for performance optimizations
- **Reek**: Detects code smells in Ruby code
  - Configuration in `.reek.yml` excludes certain complex methods
- **Bundler Audit**: Checks dependencies for known security vulnerabilities
  - Run with `--update` flag to update vulnerability database

### GitHub Actions

Continuous integration runs automatically on all pushes and pull requests:

- **CI Pipeline**: Tests on Ruby 3.4, RuboCop, Reek, Security audit
- **Docker Build**: Builds and tests Docker image with caching
- **Integration Tests**: Runs example scripts against built Docker image
- **CodeQL Analysis**: Weekly security code scanning
- **Dependency Review**: Automatically reviews dependency changes in PRs
- **Release Automation**: Builds and publishes Docker images on tagged releases

## Architecture

- `lib/code_sandbox_mcp/server.rb` - MCP protocol implementation
- `lib/code_sandbox_mcp/executor.rb` - Code execution engine
- `lib/code_sandbox_mcp/languages.rb` - Language configurations
- `bin/code-sandbox-mcp` - Executable entry point
- `examples/` - Usage examples and test cases

## License

MIT