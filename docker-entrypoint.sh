#!/bin/bash
set -euo pipefail

# Default environment variables for the MCP server
# These can be overridden by docker run -e VAR=value

# Execution timeout (seconds)
: "${EXECUTION_TIMEOUT:=30}"

# Working directory (should remain /app)
: "${WORKDIR:=/app}"

# Export the timeout for the Ruby application
export EXECUTION_TIMEOUT

# Change to working directory
cd "$WORKDIR"

# If no arguments provided, run the default MCP server
if [ $# -eq 0 ]; then
    exec ruby bin/code-sandbox-mcp
fi

# If arguments provided, execute them
exec "$@"