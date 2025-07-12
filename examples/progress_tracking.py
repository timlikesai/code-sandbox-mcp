#!/usr/bin/env python3
"""
Progress Tracking Demo
Shows different ways to track and display progress in long-running operations
"""

import time
import random
import sys

def simple_progress():
    """Simple percentage-based progress tracking"""
    print("Simple Progress Tracking:")
    total_tasks = 10
    for i in range(1, total_tasks + 1):
        processing_time = random.uniform(0.1, 0.3)
        time.sleep(processing_time)
        percentage_complete = (i / total_tasks) * 100
        print(f"Task {i}: Processing for {processing_time:.2f} seconds, {percentage_complete:.2f}% complete")
    print()

def visual_progress_bar():
    """Visual progress bar with animation"""
    print("Visual Progress Bar:")
    total = 50
    for i in range(total + 1):
        percent = (i / total) * 100
        filled = int((i / total) * 30)
        bar = '█' * filled + '░' * (30 - filled)
        print(f'\rProgress: [{bar}] {percent:.1f}%', end='')
        sys.stdout.flush()
        time.sleep(0.05)
    print("\n")

def multi_stage_progress():
    """Progress tracking for multi-stage operations"""
    print("Multi-Stage Operation:")
    stages = [
        ("Initializing", 0.5),
        ("Loading data", 1.0),
        ("Processing", 2.0),
        ("Analyzing results", 1.5),
        ("Generating report", 0.8),
        ("Cleanup", 0.2)
    ]
    
    total_stages = len(stages)
    for idx, (stage, duration) in enumerate(stages):
        print(f"\nStage {idx + 1}/{total_stages}: {stage}")
        
        # Simulate work with sub-progress
        steps = int(duration * 10)
        for step in range(steps):
            sub_progress = ((step + 1) / steps) * 100
            print(f'\r  └─ {sub_progress:.0f}%', end='')
            sys.stdout.flush()
            time.sleep(duration / steps)
        
        print(f'\r  └─ ✓ Complete')
    
    print("\nAll stages completed!")

def main():
    print("=== Progress Tracking Examples ===\n")
    
    # Run different progress tracking examples
    simple_progress()
    visual_progress_bar()
    multi_stage_progress()
    
    print("\n=== Demo Complete ===")

if __name__ == "__main__":
    main()