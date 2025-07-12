# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Architecture

This is a **Model Context Protocol (MCP) server** for secure code execution in Docker containers. The system streams output in real-time while maintaining MCP protocol compliance.

**Key Components:**
- `Server` - Handles MCP protocol over stdin/stdout (JSON-RPC)
- `StreamingExecutor` - Executes code with real-time output streaming
- `Languages` - Configuration for 9 supported languages

**Data Flow:**
```
MCP Client → JSON-RPC → Server → StreamingExecutor → Docker Process → Streamed Response
```

## Essential Commands

```bash
# Development
bundle exec rspec                    # Run all tests
bundle exec rspec spec/path/to/file  # Run specific test
bundle exec rubocop                   # Run linter
bundle exec rubocop --autocorrect-all # Auto-fix style issues
bundle exec rake                      # Run all checks (default task)

# Code Quality & Security
bundle exec reek                      # Run code smell detector
bundle exec bundler-audit check       # Check for security vulnerabilities
bundle exec bundler-audit check --update # Update vulnerability database and check

# GitHub Actions (automated)
# - All quality checks run on push/PR
# - Docker builds and integration tests
# - Weekly CodeQL security scanning
# - Automated releases on git tags

# Docker Operations
docker-compose build                  # Build the image
docker-compose run --rm code-sandbox bundle exec rspec  # Run tests in Docker

# Testing Examples
cat examples/correct_tool_call.json | docker run --rm -i code-sandbox:latest
./examples/test_examples.sh           # Test all examples

# Debugging
bundle exec rake console              # Open interactive console
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
- Coverage requirement: 90% minimum

## Supported Languages

Each language in `LANGUAGES` hash has:
- `extension` - File extension for the language
- `command` - Array of command and arguments

Current languages: `bash`, `javascript`, `lua`, `perl`, `php`, `python`, `ruby`, `sh`, `typescript`