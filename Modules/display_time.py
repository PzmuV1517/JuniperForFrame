from datetime import datetime
from Modules.frame_connection import send_to_frame

def display_time(frame=None):
    now = datetime.now().strftime("%H:%M:%S")
    message = f"Time: {now}"
    if frame:
        frame.send(message)
    print(message)
