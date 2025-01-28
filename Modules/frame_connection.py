import time
from Modules.frame_connection import send_to_frame

class MockFrame:
    """Simulate a Brilliant Labs Frame for testing purposes."""

    def send(self, message):
        print(f"Message to Frame: {message}")


def connect_to_frame():
    """Simulates connecting to the Brilliant Labs Frame."""
    print("Attempting to connect to the Brilliant Labs Frame...")
    time.sleep(2)  # Simulate connection delay
    frame = MockFrame()
    print("Connected to the Brilliant Labs Frame.")
    return frame
