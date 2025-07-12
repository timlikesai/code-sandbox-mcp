#!/usr/bin/env python3
"""
Advanced Streaming Demo
Shows various streaming patterns and real-time output capabilities
"""

import time
import sys
import random
import json

def progress_bar(current, total, bar_length=50):
    """Generate a text-based progress bar"""
    percent = current / total
    filled = int(bar_length * percent)
    bar = '█' * filled + '░' * (bar_length - filled)
    return f"[{bar}] {percent*100:.1f}%"

def main():
    print("=== Advanced Streaming Demo ===\n")
    
    # 1. Simple streaming with flush
    print("1. Real-time counter:")
    for i in range(5):
        print(f"\rCounting: {i+1}/5", end='')
        sys.stdout.flush()
        time.sleep(0.5)
    print("\n")
    
    # 2. Progress bar simulation
    print("2. Download simulation with progress bar:")
    total_size = 100
    for i in range(total_size + 1):
        progress = progress_bar(i, total_size)
        print(f"\rDownloading: {progress} ({i}/{total_size} MB)", end='')
        sys.stdout.flush()
        time.sleep(0.02)
    print("\n")
    
    # 3. Multi-line updating output
    print("3. Multi-task progress tracking:")
    tasks = ["Database sync", "File processing", "API calls", "Report generation"]
    task_progress = [0] * len(tasks)
    
    while not all(p >= 100 for p in task_progress):
        # Clear previous output
        print("\033[{}A".format(len(tasks)), end='')
        
        # Update and display each task
        for i, task in enumerate(tasks):
            if task_progress[i] < 100:
                task_progress[i] += random.randint(1, 10)
                task_progress[i] = min(task_progress[i], 100)
            
            status = "✓ Complete" if task_progress[i] >= 100 else "⚡ Running"
            print(f"{task:<20} {progress_bar(task_progress[i], 100, 30)} {status}")
            sys.stdout.flush()
        
        time.sleep(0.1)
    
    # 4. Streaming JSON output
    print("\n4. Streaming JSON events:")
    events = [
        {"event": "start", "timestamp": time.time()},
        {"event": "processing", "item": 1, "status": "success"},
        {"event": "processing", "item": 2, "status": "success"},
        {"event": "processing", "item": 3, "status": "warning", "message": "Retry needed"},
        {"event": "complete", "timestamp": time.time(), "total_items": 3}
    ]
    
    for event in events:
        print(f"Event: {json.dumps(event)}")
        sys.stdout.flush()
        time.sleep(0.3)
    
    print("\n=== Demo Complete ===")

if __name__ == "__main__":
    main()