#!/bin/bash

echo "Testing Code Sandbox MCP Examples"
echo "================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

test_example() {
    local name=$1
    local file=$2
    echo -n "Testing $name... "
    
    if cat "$file" | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest 2>/dev/null | grep -q '"isError":false'; then
        echo -e "${GREEN}✓ PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

echo -e "\nTesting JSON examples:"
test_example "Basic tool call" "examples/correct_tool_call.json"
test_example "JavaScript async" "examples/javascript_example.json"
test_example "Error handling" "examples/error_handling.json"

echo -e "\nTesting code execution:"

echo -n "Testing Python streaming output... "
RESULT=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_code","arguments":{"language":"python","code":"for i in range(3):\n    print(f\"Line {i+1}\")"}}}' | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest 2>/dev/null)
if echo "$RESULT" | grep -q "Line 1" && echo "$RESULT" | grep -q "Line 2" && echo "$RESULT" | grep -q "Line 3"; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi

echo -e "\nTesting language support:"
LANGUAGES=("python:print('Python works')" "ruby:puts 'Ruby works'" "javascript:console.log('JS works')" "bash:echo 'Bash works'" "zsh:echo 'Zsh works'" "fish:echo 'Fish works'")

for lang_code in "${LANGUAGES[@]}"; do
    IFS=':' read -r lang code <<< "$lang_code"
    echo -n "Testing $lang... "
    
    REQUEST="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_code\",\"arguments\":{\"language\":\"$lang\",\"code\":\"$code\"}}}"
    if echo "$REQUEST" | docker run --rm -i ghcr.io/timlikesai/code-sandbox-mcp:latest 2>/dev/null | grep -q "works"; then
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        echo -e "${RED}✗ FAILED${NC}"
    fi
done

echo -e "\nAll tests completed!"