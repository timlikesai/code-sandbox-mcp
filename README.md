# Code Sandbox MCP Server (Ruby)

A secure Docker-based MCP server for executing code in multiple languages, implemented in Ruby. Features Alpine Linux for minimal size and maximum security.

## Features

- **12 Supported Languages**: Python, JavaScript, TypeScript, Ruby, Bash, Zsh, Fish, Java, Clojure, Kotlin, Groovy, Scala
- **Secure Execution**: Runs in Docker with strict resource limits
- **Alpine Linux**: Optimized 978MB production image with JVM support
- **Multi-stage Build**: Separate optimized images for production and testing
- **Ruby 3.4 + JDK 21**: Latest stable Ruby with modern Java runtime
- **Output Capture**: Complete output capture with MCP protocol compliance
- **Full MCP Protocol**: Implements Model Context Protocol for tool calling
- **Comprehensive Testing**: RSpec test suite with 97.6% coverage
- **Automatic Session Management**: State persists between executions for each language
- **Session Reset Tool**: Clear language sessions when needed

## Installation

### Using Pre-built Images (Recommended)

```bash
# Pull the latest image from GitHub Container Registry
docker pull ghcr.io/timlikesai/code-sandbox-mcp:latest

# Run directly
docker run --rm --interactive ghcr.io/timlikesai/code-sandbox-mcp:latest
```

### Building from Source

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
      "args": [
        "run", "--rm", "--interactive",
        "--network", "none",
        "ghcr.io/timlikesai/code-sandbox-mcp:latest"
      ]
    }
  }
}
```

**Note**: The `--network none` flag is a Docker CLI option that disables all network access for security. The container itself supports networking - this flag prevents it.

**Claude Code CLI**: You can also add via command line:
```bash
claude mcp add code-sandbox -- docker run --rm --interactive --network none ghcr.io/timlikesai/code-sandbox-mcp:latest
```

**Security Note**: We recommend the `--network none` flag to disable network access for safety.

### Advanced Configuration (Optional)

For additional security hardening:

```json
{
  "mcpServers": {
    "code-sandbox": {
      "command": "docker",
      "args": [
        "run", "--rm", "--interactive",
        "--read-only",
        "--tmpfs", "/tmp",
        "--tmpfs", "/app/tmp",
        "--memory", "512m",
        "--cpus", "0.5",
        "--network", "none",
        "--security-opt", "no-new-privileges",
        "--cap-drop", "ALL",
        "ghcr.io/timlikesai/code-sandbox-mcp:latest"
      ]
    }
  }
}
```

### Enabling Network Access (When Needed)

**About Network Access**: The container supports networking, but we recommend using Docker's `--network none` flag to disable it for security.

**⚠️ Security Recommendation**: Use `--network none` to prevent code from accessing the internet, your local network, or making external API calls.

**To enable network access when needed, remove the `--network none` flag:**

```json
{
  "mcpServers": {
    "code-sandbox": {
      "command": "docker",
      "args": [
        "run", "--rm", "--interactive",
        "--network", "none",
        "ghcr.io/timlikesai/code-sandbox-mcp:latest"
      ]
    },
    "code-sandbox-network": {
      "command": "docker",
      "args": [
        "run", "--rm", "--interactive",
        "ghcr.io/timlikesai/code-sandbox-mcp:latest"
      ]
    }
  }
}
```

**Use cases that require network access**:
- API calls (`requests.get()`, `fetch()`, `curl`)
- Package installation (`pip install`, `npm install`)
- Data downloading or web scraping
- External service integration
- Installing libraries for data science, web frameworks, etc.

**Container-Level Package Security**:
- ✅ **Ephemeral Installs**: Packages install within the container's temporary filesystem
- ✅ **No Host Persistence**: Nothing survives container restart
- ✅ **Session Sharing**: Installed packages available across all languages in the same container session
- ✅ **Clean Slate**: Each new container starts fresh with no previous installations
- ✅ **Resource Bounded**: All installs subject to container memory/disk limits

**Docker Network Security**:
- `--network none`: Complete network isolation (recommended for untrusted code)
- No `--network` flag: Full network access (safe for development/experimentation)
- The container provides strong isolation boundaries regardless of network settings


## Usage

### Available Tools

1. **execute_code** - Execute code with automatic session management
2. **validate_code** - Validate syntax without execution  
3. **reset_session** - Reset sessions for specific languages or all languages

### Session Management

Code execution is stateful by default. Each language maintains its own isolated session with:
- Variables and their values
- Function/class definitions  
- Imported modules
- Execution history

Sessions expire after 1 hour of inactivity.

### Quick Test

```bash
# Test execution (with network disabled)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"print(\"Hello World!\")"}}}' | docker run --rm -i --network none ghcr.io/timlikesai/code-sandbox-mcp:latest

# Test with network access and package installation
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"import subprocess; subprocess.run([\"pip\", \"install\", \"requests\"]); import requests; print(requests.get(\"https://httpbin.org/ip\").json())"}}}' | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest

# Debug mode
docker run --rm -it --network none ghcr.io/timlikesai/code-sandbox-mcp:latest bash
```

## Security

Multiple layers of container security:
- **Container Isolation** with resource limits (512MB memory, 0.5 CPU)
- **Ephemeral Filesystem** - nothing persists after container stops
- **Package Installation Safety** - packages install in container temp space only
- **Network Isolation** (configurable via Docker's `--network none` flag)
- **Read-only Root Filesystem** with writable `/tmp` only  
- **No Privileges** (`--security-opt no-new-privileges`, `--cap-drop ALL`)
- **Non-root User** (executes as `sandbox` user)
- **Auto-cleanup** (`--rm` removes containers after execution)
- **Configurable Timeout** (default 30s via `EXECUTION_TIMEOUT`)

**Package Installation Security**: When network access is enabled, users can install packages (`pip install`, `npm install`, etc.) safely within the container. All installations are ephemeral and don't affect the host system or persist between container restarts.

## Examples

See [examples/README.md](examples/README.md) for comprehensive examples including:
- JSON examples for all 12 languages
- MCP protocol demonstrations
- Session management patterns
- Error handling
- Response format documentation

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

# Security checks
bundle exec bundler-audit check        # Check for dependency vulnerabilities

# Run all checks
bundle exec rake
```

### Docker Testing

```bash
# Run all tests in Docker
bundle exec rake docker:test

# Build images  
bundle exec rake docker:build

# Interactive shell
bundle exec rake docker:shell

# Individual test commands
docker compose run --rm code-sandbox-test bundle exec rspec
docker compose run --rm code-sandbox-test bundle exec rubocop
```

### Testing

```bash
# Test examples
./examples/test_examples.sh

# Interactive debugging
docker run --rm -it ghcr.io/timlikesai/code-sandbox-mcp:latest bash
```

## Architecture

**Multi-stage Docker Build**:
- **Production**: 978MB Alpine-based image with all 12 languages
- **Test**: 1.68GB with development dependencies
- **Builder**: Intermediate stage for gem compilation

**Key Components**:
- `server.rb` - MCP protocol (JSON-RPC)
- `streaming_executor.rb` - Code execution with output capture
- `executor.rb` - Core execution engine
- `languages.rb` - Language configurations

**Performance**:
- Cold start: ~1-2 seconds
- Execution: ~50-200ms per request
- Memory: <100MB typical, 512MB limit

## License

MIT