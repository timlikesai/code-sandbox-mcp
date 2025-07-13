#!/bin/bash

echo "==============================================="
echo "Testing Code Sandbox MCP Examples"
echo "==============================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=${VERBOSE:-false}
DOCKER_IMAGE=${DOCKER_IMAGE:-"ghcr.io/timlikesai/code-sandbox-mcp:latest"}
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is required to run tests${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${BLUE}Running all tests in Docker container${NC}"
echo "Image: $DOCKER_IMAGE"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
if docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
    echo -e "${GREEN}Using local image${NC}"
else
    if [ -n "$CI" ]; then
        echo "Pulling image for CI..."
    else
        echo -e "${YELLOW}Image not found locally, pulling from registry...${NC}"
        echo "Tip: Build locally first with: docker compose build code-sandbox"
    fi
    docker pull "$DOCKER_IMAGE"
fi

echo ""
echo "Starting test execution..."
echo "================================="

ENV_VARS=""
if [ "$VERBOSE" = "true" ]; then
    ENV_VARS="-e VERBOSE=true"
fi

docker run --rm \
    -v "$PROJECT_ROOT/examples:/app/examples:ro" \
    $ENV_VARS \
    "$DOCKER_IMAGE" \
    /app/examples/test_examples_in_container.sh