#!/usr/bin/env python3
"""
Streaming Output Demo
This demonstrates how streaming output works with long-running processes
"""

import time
import sys

def main():
    print("Starting long-running process...")
    sys.stdout.flush()
    
    # Simulate a process with progressive output
    for i in range(10):
        print(f"Processing step {i + 1}/10...")
        sys.stdout.flush()  # Force output to be sent immediately
        time.sleep(0.5)  # Simulate work
    
    print("\nGenerating results...")
    sys.stdout.flush()
    time.sleep(1)
    
    # Show some results
    results = ["✓ Data processed", "✓ Analysis complete", "✓ Report generated"]
    for result in results:
        print(result)
        sys.stdout.flush()
        time.sleep(0.3)
    
    print("\nProcess completed successfully!")

if __name__ == "__main__":
    main()