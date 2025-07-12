#!/usr/bin/env python3
"""
MCP Client Usage Example
Shows how to interact with the Code Sandbox MCP server
"""

import json
import subprocess
import sys

def send_request(request):
    """Send a request to the MCP server and get response"""
    # In a real implementation, you would connect to the server via stdin/stdout
    # This is a simplified example showing the request format
    print(f"Sending request: {json.dumps(request, indent=2)}")
    print("-" * 50)

def main():
    print("Code Sandbox MCP Client Usage Example")
    print("=" * 50)
    
    # 1. Initialize the connection
    print("\n1. Initialize Connection:")
    init_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {}
    }
    send_request(init_request)
    
    # 2. List available tools
    print("\n2. List Available Tools:")
    list_tools_request = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    }
    send_request(list_tools_request)
    
    # 3. Execute Python code
    print("\n3. Execute Python Code:")
    python_request = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "execute_code",
            "arguments": {
                "language": "python",
                "code": """# Calculate Fibonacci sequence
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

print("Fibonacci sequence:")
for i in range(10):
    print(f"F({i}) = {fibonacci(i)}")"""
            }
        }
    }
    send_request(python_request)
    
    # 4. Execute JavaScript code
    print("\n4. Execute JavaScript Code:")
    js_request = {
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/call",
        "params": {
            "name": "execute_code",
            "arguments": {
                "language": "javascript",
                "code": """// Generate random data and calculate statistics
const data = Array.from({length: 10}, () => Math.floor(Math.random() * 100));
console.log('Random data:', data);

const sum = data.reduce((a, b) => a + b, 0);
const avg = sum / data.length;
const max = Math.max(...data);
const min = Math.min(...data);

console.log(`\\nStatistics:`);
console.log(`Sum: ${sum}`);
console.log(`Average: ${avg.toFixed(2)}`);
console.log(`Max: ${max}`);
console.log(`Min: ${min}`);"""
            }
        }
    }
    send_request(js_request)
    
    print("\n" + "=" * 50)
    print("To actually run these requests:")
    print("1. Start the MCP server: bin/code-sandbox-mcp")
    print("2. Send JSON requests via stdin")
    print("3. Receive JSON responses via stdout")

if __name__ == "__main__":
    main()