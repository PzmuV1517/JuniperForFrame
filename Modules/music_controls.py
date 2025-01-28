from Modules.frame_connection import send_to_frame

current_song = None


def display_current_song(song, frame=None):
    message = f"Current Song: {song}"
    if frame:
        frame.send(message)
    print(message)


def handle_music_command(command, frame=None):
    global current_song
    if command == "next song":
        current_song = "Next Song Title"
    elif command == "previous song":
        current_song = "Previous Song Title"
    elif command == "pause":
        message = "Music Paused."
    elif command == "play":
        message = "Music Playing."

    if frame:
        frame.send(message)
    print(f"Executing command: {command}")
