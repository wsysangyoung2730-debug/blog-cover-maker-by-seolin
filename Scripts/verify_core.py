#!/usr/bin/env python3
"""Run native tests with a bounded wait and capture a stack sample on a stalled CI host."""
import os
import signal
import subprocess
import sys

environment = dict(os.environ, NSUnbufferedIO="YES")
process = subprocess.Popen(["swift", "test"], env=environment, start_new_session=True)
try:
    sys.exit(process.wait(timeout=180))
except subprocess.TimeoutExpired:
    print("공통 테스트가 3분 안에 끝나지 않아 XCTest 상태를 수집합니다.", flush=True)
    matches = subprocess.run(["pgrep", "-x", "xctest"], capture_output=True, text=True)
    for test_pid in matches.stdout.split():
        try:
            subprocess.run(["sample", test_pid, "2"], timeout=15)
        except subprocess.TimeoutExpired:
            pass
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
    sys.exit(124)
