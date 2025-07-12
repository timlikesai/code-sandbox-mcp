#!/bin/bash
set -euo pipefail

: "${EXECUTION_TIMEOUT:=30}"
: "${WORKDIR:=/app}"

export EXECUTION_TIMEOUT

cd "$WORKDIR"

if [ $# -eq 0 ]; then
    exec ruby bin/code-sandbox-mcp
fi

exec "$@"