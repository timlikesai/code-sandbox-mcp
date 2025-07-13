# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Architecture

This is a **Model Context Protocol (MCP) server** for secure code execution in Docker containers. The system streams output in real-time while maintaining MCP protocol compliance. Uses Alpine Linux for optimized size (727MB production image) and security.

**Key Components:**
- `Server` - Handles MCP protocol over stdin/stdout (JSON-RPC)
- `StreamingExecutor` - Executes code with real-time output streaming
- `Languages` - Configuration for 7 supported languages

**Data Flow:**
```
MCP Client → JSON-RPC → Server → StreamingExecutor → Docker Process → Streamed Response
```

## Essential Commands

### Local Development
```bash
# Install dependencies
bundle install

# Run all tests locally
bundle exec rspec                    # Run all tests
bundle exec rspec spec/path/to/file  # Run specific test

# Run linters and code quality checks
bundle exec rubocop                   # Run linter
bundle exec rubocop --autocorrect-all # Auto-fix style issues
bundle exec bundler-audit check --update # Check for security vulnerabilities

# Run all checks at once
bundle exec rake                      # Runs tests + all quality checks
```

### Docker-Based Testing (Recommended)
```bash
# Build Docker images
docker compose build                  # Build both production and test images
docker compose build code-sandbox     # Build production image only
docker compose build code-sandbox-test # Build test image only

# Run tests in Docker (includes all dependencies)
docker compose run --rm code-sandbox-test bundle exec rspec
docker compose run --rm code-sandbox-test bundle exec rubocop
docker compose run --rm code-sandbox-test bundle exec bundler-audit check --update

# Run all tests and checks using Rake
bundle exec rake docker:test          # Runs full test suite in Docker

# Interactive shell in test container
bundle exec rake docker:shell         # Or: docker compose run --rm code-sandbox-test bash
```

### Testing the Production Image
```bash
# Quick smoke test
echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest

# Test code execution
cat examples/correct_tool_call.json | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest

# Run full example test suite
./examples/test_examples.sh           # Tests against locally built image
docker run --rm -v $PWD/examples:/app/examples:ro ghcr.io/timlikesai/code-sandbox-mcp:test-latest /app/examples/test_examples_in_container.sh

# Debug mode - interactive shell
docker run --rm -it ghcr.io/timlikesai/code-sandbox-mcp:latest bash
```

### CI/CD Commands
```bash
# GitHub Actions runs these automatically:
# - All tests and quality checks on every push/PR
# - Docker image builds with layer caching
# - Integration tests using built images
# - Weekly CodeQL security scanning
# - Automated releases on git tags
# - Dependabot auto-merge for patch/minor updates
```

## MCP Protocol Implementation

The server implements three MCP methods:
1. `initialize` - Returns protocol version and capabilities
2. `tools/list` - Returns the `execute_code` tool definition
3. `tools/call` - Executes code and returns streaming results

**Response Format:**
- Original code with MIME type
- Stdout/stderr lines with `streamed: true` annotation
- Final metadata block with exit code and timing

## Code Execution Flow

1. **StreamingExecutor** creates a temporary directory
2. Writes code to a file with appropriate extension
3. Uses `Open3.popen3` to execute with 30-second timeout
4. Streams output line-by-line using Ruby threads
5. Returns structured MCP response with all content blocks

## Security Constraints

When executed via Docker, the code runs with:
- Non-root user "sandbox"
- Read-only filesystem (except `/tmp`)
- No network access
- 512MB memory limit
- 50% CPU limit
- All Linux capabilities dropped

## Testing Approach

- Unit tests for each component
- Integration tests for full MCP flow
- Language-specific execution tests
- Error condition testing (timeouts, syntax errors, etc.)
- Coverage requirement: 90% minimum (currently at 99.06%)

### Test Execution Flow

1. **Setup**: Tests can run locally or in Docker container
2. **Coverage**: SimpleCov tracks coverage (writes to `/tmp/coverage` in Docker)
3. **RSpec**: Runs all specs with randomized order
4. **Quality Checks**: RuboCop and Bundler Audit run after tests
5. **Examples**: Integration tests verify real MCP protocol exchanges

### Key Test Files
- `spec/code_sandbox_mcp/server_spec.rb` - MCP protocol tests
- `spec/code_sandbox_mcp/streaming_executor_spec.rb` - Streaming execution tests
- `spec/code_sandbox_mcp/executor_spec.rb` - Basic execution tests
- `spec/integration/mcp_integration_spec.rb` - Full integration tests
- `examples/test_examples.sh` - Real-world example validation

## Supported Languages

Each language in `LANGUAGES` hash has:
- `extension` - File extension for the language
- `command` - Array of command and arguments
- `mime_type` - MIME type for the language

Current languages: `bash`, `fish`, `javascript`, `python`, `ruby`, `typescript`, `zsh`, `java`, `clojure`, `kotlin`, `groovy`, `scala`

### JVM Languages Notes
- **Java**: Uses Java 21's single-source-file execution feature
- **Clojure**: Runs directly without compilation
- **Kotlin**: Uses `.kts` extension for script mode
- **Groovy**: Executes as scripts without compilation
- **Scala**: Uses Scala 3 with `@main` annotation for scripts

## Important Design Decisions

### Docker Image Strategy
- **Alpine Base**: Uses `ruby:3.4.4-alpine` for minimal size and security
- **Multi-stage Build**: `base` → `builder` → `production` and `test` stages
- **Multi-Architecture**: Supports both `linux/amd64` and `linux/arm64` platforms
- **Production Image**: 1.5GB (was 727MB before JVM languages), contains runtime files + JDK + JVM language runtimes
- **Test Image**: 1.68GB (was 908MB), includes development dependencies and test files
- **Single Repository**: Both images use `ghcr.io/timlikesai/code-sandbox-mcp`
- **Tag Prefixes**: Test images use `test-` prefix (e.g., `test-latest`, `test-main`)
- **Layer Sharing**: Optimized caching between stages and builds

### GitHub Container Registry Integration
- **Image Tags**:
  - `latest` - Only pushed from main branch (multi-arch)
  - `main` - Latest main branch build (multi-arch)
  - `<branch-name>` - Feature branch builds (multi-arch)
  - `<sha>` - Commit-specific builds (multi-arch)
  - `test-<tag>` - Test image variants (multi-arch)
- **Multi-Architecture**: All images built for `linux/amd64` and `linux/arm64`
- **Caching Strategy**: Uses inline cache with `cache-from` pulling from registry
- **Auto-push**: CI pushes all builds, but `latest` only on main branch
- **Native Runners**: ARM64 builds use native `ubuntu-24.04-arm` runners (no QEMU needed)

### Security Decisions
- **No Network Access**: `--network none` prevents any external connections
- **Read-only Filesystem**: Only `/tmp` and `/app/tmp` are writable
- **Non-root User**: All code runs as `sandbox` user (UID 1000)
- **Resource Limits**: Hard limits on memory (512MB) and CPU (50%)
- **Capability Dropping**: All Linux capabilities removed with `--cap-drop ALL`

## Common Gotchas

1. **Test Coverage Directory**: In Docker, coverage must write to `/tmp/coverage` (not `/app/coverage`)
2. **Bundle Path**: Gems are installed to `vendor/bundle` in production mode
3. **Docker Compose v2**: Use `docker compose` (no hyphen) not `docker-compose`
4. **Example Tests**: Must mount examples directory as read-only: `-v $PWD/examples:/app/examples:ro`
5. **JSON Input**: MCP requires proper JSON-RPC format - use example files as templates

## Performance Considerations

- **Execution Timeout**: 30 seconds default (configurable via `EXECUTION_TIMEOUT`)
- **Streaming Buffer**: Output streams line-by-line to prevent memory issues
- **Thread Cleanup**: Stream readers have 0.5s join timeout to prevent hanging
- **Process Termination**: SIGTERM first, then SIGKILL after 0.1s if needed

## GitHub Actions Workflows

### CI Workflow (`ci.yml`)
- **Parallel Architecture Builds**: Separate AMD64 and ARM64 build jobs using native runners
- **Multi-Arch Manifest Creation**: Merges architecture-specific images after builds complete
- **Parallel Testing**: Test and smoke-test jobs run concurrently on both architectures
- **Native ARM64 Support**: Uses `ubuntu-24.04-arm` runners for ARM64 builds/tests (no QEMU)
- **Optimized Flow**: `prepare` → `build` (parallel) → `merge` → `test/smoke` (parallel) → `tag`

### Release Workflow (`release.yml`)
- Triggers on version tags (`v*`)
- Creates GitHub releases
- Pushes semantic version tags to registry

### Dependabot Auto-merge (`dependabot-auto-merge.yml`)
- Auto-approves and merges patch/minor updates
- Allows major updates for dev dependencies
- Comments on major production/Docker updates for manual review

## Known Limitations & Future Improvements

1. **Language Support**: Some languages (Go, Rust, C/C++) require compilation steps not yet implemented
2. **File System Access**: Currently no persistent storage between executions
3. **Binary Output**: No support for returning binary data (images, etc.)
4. **Interactive Input**: No stdin support for interactive programs
5. **Package Installation**: No mechanism to install additional packages at runtime

## Code Organization & Conventions

### File Structure
```
lib/code_sandbox_mcp/
├── server.rb           # MCP protocol handler (JSON-RPC)
├── streaming_executor.rb # Real-time output streaming
├── executor.rb         # Basic execution (used by streaming)
├── languages.rb        # Language configurations
└── version.rb          # Version constant

spec/
├── code_sandbox_mcp/   # Unit tests for each component
├── integration/        # Full MCP protocol integration tests
└── support/            # Test helpers and shared contexts
```

### Ruby Conventions
- **Frozen String Literals**: All files use `# frozen_string_literal: true`
- **Keyword Arguments**: Prefer keyword args for clarity
- **Error Handling**: Catch specific exceptions, not StandardError
- **Threading**: Use threads for streaming I/O with proper cleanup
- **Constants**: Language config and timeout in `languages.rb`

### Testing Conventions
- **RSpec**: BDD-style with `describe`/`context`/`it`
- **Coverage**: Maintain >99% coverage (currently 99.06%)
- **Randomization**: Tests run in random order (seed-based)
- **Isolation**: Each test cleans up after itself
- **Timeouts**: Test timeouts separately from normal execution

## Development Tips

- **Use Docker-based testing** for consistency with CI environment
- **Run `bundle exec rake`** before committing to catch all issues
- **Check examples** after any protocol changes using `./examples/test_examples.sh`
- **Update both images** when changing dependencies (production and test)
- **Tag releases** with `v` prefix for automatic GitHub releases
- **Watch logs** with `docker compose logs -f` during development
- **Debug MCP** by piping to `jq` for pretty JSON output

## Troubleshooting

### Common Issues

1. **"bundler: command not found: rspec"**
   - Wrong image or missing mount
   - Use `docker compose run` not bare `docker run`

2. **Permission denied @ dir_s_mkdir - /app/coverage**
   - Coverage directory issue in Docker
   - Set `COVERAGE_DIR=/tmp/coverage`

3. **Tests fail with "No examples found"**
   - Missing volume mount
   - Add `-v $PWD:/app` for test containers

4. **JSON Parse errors in examples**
   - Escaping issues with shell
   - Use example JSON files or heredocs

5. **Timeout errors in CI**
   - Default 30s timeout too short
   - Increase `EXECUTION_TIMEOUT` env var

### Debugging Techniques

```bash
# View MCP server logs
docker run --rm -it ghcr.io/timlikesai/code-sandbox-mcp:latest 2>&1 | tee debug.log

# Test with verbose output
DEBUG=1 docker compose run --rm code-sandbox-test bundle exec rspec

# Check container internals
docker compose run --rm code-sandbox-test bash
> which python3
> ls -la /tmp
> cat /proc/self/limits
```