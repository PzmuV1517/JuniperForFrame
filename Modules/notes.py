from frame_connection import send_to_frame

def start_note_taking(frame=None):
    print("Note-taking started. Speak now.")
    note = input("Recording note: ")
    message = f"Note saved: {note}"
    if frame:
        frame.send(message)
    print(message)

