import time
import sys
import select
import os

def detect_tap():
    """
    Detect keyboard input for tap simulation.
    'T' simulates a tap, timing between presses determines single/double tap.
    """
    # Check if input is available
    if os.name == 'nt':  # Windows
        import msvcrt
        if msvcrt.kbhit():
            key = msvcrt.getch().decode().lower()
            if key == 't':
                # Wait briefly for potential second tap
                start_time = time.time()
                while time.time() - start_time < 0.5:
                    if msvcrt.kbhit():
                        second_key = msvcrt.getch().decode().lower()
                        if second_key == 't':
                            return "double", None
                return "single", None
    else:  # Unix-like
        if select.select([sys.stdin], [], [], 0.1)[0]:
            key = sys.stdin.read(1).lower()
            if key == 't':
                # Wait briefly for potential second tap
                start_time = time.time()
                while time.time() - start_time < 0.5:
                    if select.select([sys.stdin], [], [], 0)[0]:
                        second_key = sys.stdin.read(1).lower()
                        if second_key == 't':
                            return "double", None
                return "single", None
    
    return None, None


def handle_voice_command():
    """Simulate voice command detection."""
    # Placeholder for voice recognition
    return input("Speak your command: ")
