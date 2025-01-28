from Modules.frame_connection import send_to_frame

def process_assistant_command(command, frame=None):
    message = f"Processing command: {command}"
    if frame:
        frame.send(message)
    print(message)
