#!/usr/bin/env python3
"""
Multi-Language Demo
Demonstrates executing code in different languages via MCP
"""

import json
import sys

# Example requests for different languages
examples = {
    "ruby": {
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/call",
        "params": {
            "name": "execute_code",
            "arguments": {
                "language": "ruby",
                "code": "# Ruby example\nputs 'Hello from Ruby!'\n\n# Show Ruby features\narray = [1, 2, 3, 4, 5]\nputs \"Array: #{array.inspect}\"\nputs \"Doubled: #{array.map { |x| x * 2 }.inspect}\"\nputs \"Sum: #{array.sum}\""
            }
        }
    },
    "bash": {
        "jsonrpc": "2.0",
        "id": 5,
        "method": "tools/call",
        "params": {
            "name": "execute_code",
            "arguments": {
                "language": "bash",
                "code": "#!/bin/bash\n# Bash scripting example\necho 'Hello from Bash!'\n\n# Show system info\necho -e '\\nSystem Information:'\necho \"Current directory: $(pwd)\"\necho \"Date: $(date)\"\necho \"Bash version: $BASH_VERSION\"\n\n# Simple loop\necho -e '\\nCounting to 5:'\nfor i in {1..5}; do\n    echo \"Count: $i\"\ndone"
            }
        }
    },
    "typescript": {
        "jsonrpc": "2.0",
        "id": 6,
        "method": "tools/call",
        "params": {
            "name": "execute_code",
            "arguments": {
                "language": "typescript",
                "code": "// TypeScript example with type annotations\ninterface User {\n    name: string;\n    age: number;\n    email: string;\n}\n\nfunction greetUser(user: User): string {\n    return `Hello ${user.name}, you are ${user.age} years old!`;\n}\n\nconst user: User = {\n    name: 'Alice',\n    age: 30,\n    email: 'alice@example.com'\n};\n\nconsole.log(greetUser(user));\nconsole.log('User details:', JSON.stringify(user, null, 2));"
            }
        }
    }
}

def main():
    """Print example requests for different languages"""
    print("Multi-Language MCP Request Examples")
    print("=" * 40)
    
    for lang, request in examples.items():
        print(f"\n{lang.upper()} Example Request:")
        print(json.dumps(request, indent=2))
        print("-" * 40)
    
    print("\nTo execute any of these examples, send the JSON request to the MCP server.")
    print("Each demonstrates language-specific features and capabilities.")

if __name__ == "__main__":
    main()