#!/bin/bash

echo "==============================================="
echo "Testing Code Sandbox MCP Examples (In Container)"
echo "==============================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

TIMEOUT=${TIMEOUT:-60}
VERBOSE=${VERBOSE:-false}

log() {
    [ "$VERBOSE" = "true" ] && echo "$1"
}

test_json_example() {
    local name="$1"
    local file="$2"
    local expected_exit_code="${3:-0}"
    local timeout="${4:-$TIMEOUT}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "[$TOTAL_TESTS] Testing $name... "
    
    if [ ! -f "/app/examples/$file" ]; then
        echo -e "${RED}✗ FILE NOT FOUND${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    local output
    local exit_code
    if output=$(jq -c . "/app/examples/$file" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    log "Output: $output"
    log "Exit code: $exit_code"
    
    if echo "$output" | jq -e '.result' >/dev/null 2>&1; then
        if echo "$output" | jq -e '.result.content[].text' 2>/dev/null | grep -q "Exit code: $expected_exit_code"; then
            echo -e "${GREEN}✓ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        elif echo "$output" | jq -e '.result.content[].annotations.status' 2>/dev/null | grep -q "valid"; then
            echo -e "${GREEN}✓ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} (unexpected response)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            if [ "$VERBOSE" = "true" ]; then
                echo "Output: $output"
            fi
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (error or invalid response)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ "$VERBOSE" = "true" ]; then
            echo "Output: $output"
        fi
        return 1
    fi
}

test_doc_with_examples() {
    local name="$1"
    local file="$2"
    local timeout="${3:-60}"
    
    if [ ! -f "/app/examples/$file" ]; then
        echo -e "${RED}✗ FILE NOT FOUND${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    if jq -e '.steps' "/app/examples/$file" >/dev/null 2>&1; then
        test_steps_format "$name" "$file" "$timeout"
        return
    fi
    
    if jq -e '.examples' "/app/examples/$file" >/dev/null 2>&1; then
        test_examples_format "$name" "$file" "$timeout"
        return
    fi
    
    if jq -e '.requests' "/app/examples/$file" >/dev/null 2>&1; then
        test_requests_format "$name" "$file" "$timeout"
        return
    fi
    
    test_json_example "$name" "$file"
}

test_steps_format() {
    local name="$1"
    local file="$2"
    local timeout="$3"
    
    local step_count=$(jq '.steps | length' "/app/examples/$file")
    local passed=0
    
    for i in $(seq 0 $((step_count - 1))); do
        local step_desc=$(jq -r ".steps[$i].description" "/app/examples/$file")
        local request=$(jq -c ".steps[$i].request" "/app/examples/$file" 2>/dev/null)
        
        if [ "$request" != "null" ] && [ -n "$request" ]; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            echo -n "[$TOTAL_TESTS] Testing $name - $step_desc... "
            
            local output
            if output=$(echo "$request" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
                if echo "$output" | jq -e '.result' >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ PASSED${NC}"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    passed=$((passed + 1))
                    log "Output: $output"
                elif echo "$output" | jq -e '.error' >/dev/null 2>&1; then
                    echo -e "${RED}✗ FAILED${NC} (error response)"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                    log "Output: $output"
                else
                    echo -e "${RED}✗ FAILED${NC} (invalid response)"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                    log "Output: $output"
                fi
            else
                echo -e "${RED}✗ FAILED${NC} (timeout/error)"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        fi
    done
}

test_examples_format() {
    local name="$1"
    local file="$2"
    local timeout="$3"
    
    local example_count=$(jq '.examples | length' "/app/examples/$file")
    
    for i in $(seq 0 $((example_count - 1))); do
        local title=$(jq -r ".examples[$i].title" "/app/examples/$file")
        
        for request_type in validate_request execute_request; do
            local request=$(jq -c ".examples[$i].$request_type" "/app/examples/$file" 2>/dev/null)
            
            if [ "$request" != "null" ] && [ -n "$request" ]; then
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                echo -n "[$TOTAL_TESTS] Testing $name - $title ($request_type)... "
                
                local output
                if output=$(echo "$request" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
                    if echo "$output" | jq -e '.result' >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ PASSED${NC}"
                        PASSED_TESTS=$((PASSED_TESTS + 1))
                        log "Output: $output"
                    elif echo "$output" | jq -e '.error' >/dev/null 2>&1; then
                        if [[ "$request_type" == "validate_request" ]] && echo "$title" | grep -qi "invalid"; then
                            echo -e "${GREEN}✓ PASSED${NC} (expected error)"
                            PASSED_TESTS=$((PASSED_TESTS + 1))
                        else
                            echo -e "${RED}✗ FAILED${NC} (error response)"
                            FAILED_TESTS=$((FAILED_TESTS + 1))
                        fi
                        if [ "$VERBOSE" = "true" ]; then
                            echo "Output: $output"
                        fi
                    else
                        echo -e "${RED}✗ FAILED${NC} (invalid response)"
                        FAILED_TESTS=$((FAILED_TESTS + 1))
                        if [ "$VERBOSE" = "true" ]; then
                            echo "Output: $output"
                        fi
                    fi
                else
                    echo -e "${RED}✗ FAILED${NC} (timeout/error)"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                fi
            fi
        done
    done
}

test_requests_format() {
    local name="$1"
    local file="$2"
    local timeout="$3"
    
    local request_count=$(jq '.requests | length' "/app/examples/$file")
    
    for i in $(seq 0 $((request_count - 1))); do
        local comment=$(jq -r ".requests[$i].comment // \"Request $((i+1))\"" "/app/examples/$file")
        local request=$(jq -c ".requests[$i] | del(.comment)" "/app/examples/$file" 2>/dev/null)
        
        if [ "$request" != "null" ] && [ -n "$request" ]; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            echo -n "[$TOTAL_TESTS] Testing $name - $comment... "
            
            local output
            if output=$(echo "$request" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
                if echo "$output" | jq -e '.result' >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ PASSED${NC}"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    log "Output: $output"
                else
                    echo -e "${RED}✗ FAILED${NC} (error or invalid response)"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                    if [ "$VERBOSE" = "true" ]; then
                        echo "Output: $output"
                    fi
                fi
            else
                echo -e "${RED}✗ FAILED${NC} (timeout/error)"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        fi
    done
}

test_multi_step_json() {
    local name="$1"
    local file="$2"
    local timeout="${3:-120}"
    
    echo -n "Testing $name... "
    
    if [ ! -f "/app/examples/$file" ]; then
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        echo -e "${RED}✗ FILE NOT FOUND${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    local output
    local exit_code
    if output=$(jq -c . "/app/examples/$file" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    log "Output: $output"
    log "Exit code: $exit_code"
    
    local steps_count
    steps_count=$(jq length "/app/examples/$file")
    local passed=0
    local failed=0
    
    for i in $(seq 0 $((steps_count - 1))); do
        local desc=$(jq -r ".[$i].description // \"Step $((i+1))\"" "/app/examples/$file")
        local step=$(jq -c ".[$i]" "/app/examples/$file")
        
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        echo -n "[$TOTAL_TESTS] Testing $name - $desc... "
        
        local output
        if output=$(echo "$step" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
            if echo "$output" | jq -e '.result' >/dev/null 2>&1; then
                if echo "$output" | jq -e '.result.content[].annotations.status' 2>/dev/null | grep -q "valid"; then
                    echo -e "${GREEN}✓ PASSED${NC} (valid syntax)"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    passed=$((passed + 1))
                elif echo "$output" | jq -e 'select(.result.isError == true)' >/dev/null 2>&1; then
                    if echo "$desc" | grep -qi "invalid"; then
                        echo -e "${GREEN}✓ PASSED${NC} (detected syntax error)"
                        PASSED_TESTS=$((PASSED_TESTS + 1))
                        passed=$((passed + 1))
                    else
                        echo -e "${RED}✗ FAILED${NC} (unexpected syntax error)"
                        FAILED_TESTS=$((FAILED_TESTS + 1))
                        failed=$((failed + 1))
                    fi
                elif echo "$output" | jq -e '.result.content[].text' 2>/dev/null | grep -q "Exit code:"; then
                    echo -e "${GREEN}✓ PASSED${NC}"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    passed=$((passed + 1))
                else
                    echo -e "${GREEN}✓ PASSED${NC}"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    passed=$((passed + 1))
                fi
            elif echo "$output" | jq -e '.error' >/dev/null 2>&1; then
                if echo "$desc" | grep -qi "invalid"; then
                    echo -e "${GREEN}✓ PASSED${NC} (expected error)"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    passed=$((passed + 1))
                else
                    echo -e "${RED}✗ FAILED${NC} (unexpected error)"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                    failed=$((failed + 1))
                    if [ "$VERBOSE" = "true" ]; then
                        echo "Output: $output"
                    fi
                fi
            else
                echo -e "${RED}✗ FAILED${NC} (invalid response)"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                failed=$((failed + 1))
                if [ "$VERBOSE" = "true" ]; then
                    echo "Output: $output"
                fi
            fi
        else
            echo -e "${RED}✗ FAILED${NC} (timeout/error)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

test_language_runtime() {
    local lang="$1"
    local code="$2"
    local expected_output="$3"
    local timeout="${4:-30}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "[$TOTAL_TESTS] Testing $lang runtime... "
    
    local request="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_code\",\"arguments\":{\"language\":\"$lang\",\"code\":\"$code\"}}}"
    
    local output
    if output=$(echo "$request" | timeout "$timeout" /app/bin/code-sandbox-mcp 2>&1); then
        if echo "$output" | grep -q "$expected_output" && echo "$output" | grep -q "Exit code: 0"; then
            echo -e "${GREEN}✓ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        fi
    fi
    
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    log "Expected: $expected_output"
    log "Actual: $output"
    return 1
}

echo ""
echo -e "${BLUE}=== Environment Check ===${NC}"
echo "Working directory: $(pwd)"
echo "Available examples: $(find /app/examples -name "*.json" | wc -l)"
echo "MCP binary: $(ls -la /app/bin/code-sandbox-mcp)"

echo ""
echo -e "${BLUE}=== Basic Examples ===${NC}"
test_doc_with_examples "MCP Protocol Flow" "mcp_protocol_flow.json"
test_json_example "Correct Tool Call" "correct_tool_call.json"
test_doc_with_examples "Both Tools Demo" "both_tools_demo.json"

echo ""
echo -e "${BLUE}=== Language Runtime Tests ===${NC}"
test_language_runtime "python" "print('Python works!')" "Python works!"
test_language_runtime "javascript" "console.log('JavaScript works!')" "JavaScript works!"
test_language_runtime "typescript" "console.log('TypeScript works!')" "TypeScript works!"
test_language_runtime "ruby" "puts 'Ruby works!'" "Ruby works!"
test_language_runtime "bash" "echo 'Bash works!'" "Bash works!"
test_language_runtime "zsh" "echo 'Zsh works!'" "Zsh works!"
test_language_runtime "fish" "echo 'Fish works!'" "Fish works!"

echo ""
echo -e "${BLUE}=== JVM Language Tests ===${NC}"
test_json_example "Java Hello World" "java_hello_world.json"
test_json_example "Kotlin Hello World" "kotlin_hello_world.json"
test_json_example "Scala Hello World" "scala_hello_world.json"
test_json_example "Groovy Hello World" "groovy_hello_world.json"
test_json_example "Clojure Hello World" "clojure_hello_world.json"

echo ""
echo -e "${BLUE}=== Code Validation Tests ===${NC}"
test_json_example "Valid JavaScript Syntax" "javascript_valid_syntax.json"
test_json_example "Valid Code Validation" "validate_valid_code.json"
test_json_example "Invalid JavaScript Syntax" "javascript_invalid_syntax.json" 1
test_json_example "Invalid Code Validation" "validate_invalid_code.json" 1
test_multi_step_json "All Languages Validation" "all_languages_validation.json"

echo ""
echo -e "${BLUE}=== Error Handling Tests ===${NC}"
test_json_example "Error Handling" "error_handling.json" 1

echo ""
echo -e "${BLUE}=== Session Management Tests ===${NC}"
test_doc_with_examples "Automatic Session Example" "automatic_session_example.json"

echo ""
echo -e "${BLUE}=== Package Installation Tests ===${NC}"
test_json_example "Python Package Demo" "python_package_demo.json"
test_json_example "JavaScript Package Demo" "javascript_package_demo.json" 1 
test_json_example "Ruby Package Demo" "ruby_package_demo.json"
test_json_example "JVM Languages Package Demo" "jvm_languages_package_demo.json"
test_json_example "Package Installation Demo" "package_installation_demo.json"
test_json_example "Cross Language Packages" "cross_language_packages.json"
test_json_example "Comprehensive Package Test" "comprehensive_package_test.json"

echo ""
echo -e "${BLUE}=== Multi-File Application Tests ===${NC}"
test_multi_step_json "Multi-File Python App" "multi_file_python_app.json" 180
test_multi_step_json "Multi-File JavaScript App" "multi_file_javascript_app.json" 180
test_multi_step_json "Multi-File TypeScript App" "multi_file_typescript_app.json" 180
test_multi_step_json "Multi-File Ruby App" "multi_file_ruby_app.json" 180
test_multi_step_json "Multi-File Java App" "multi_file_java_app.json" 180
test_multi_step_json "Multi-File Bash App" "multi_file_bash_app.json" 180
test_multi_step_json "Multi-File Kotlin App" "multi_file_kotlin_app.json" 180
test_multi_step_json "Multi-File Scala App" "multi_file_scala_app.json" 180
test_multi_step_json "Multi-File Clojure App" "multi_file_clojure_app.json" 180
test_multi_step_json "Multi-File Groovy App" "multi_file_groovy_app.json" 180
test_multi_step_json "Multi-File Zsh App" "multi_file_zsh_app.json" 180
test_multi_step_json "Multi-File Fish App" "multi_file_fish_app.json" 180

echo ""
echo "==============================================="
echo -e "${BLUE}Test Results Summary${NC}"
echo "==============================================="
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ $FAILED_TESTS tests failed${NC}"
    echo ""
    echo "To debug failures, run with VERBOSE=true:"
    echo "VERBOSE=true $0"
    exit 1
fi