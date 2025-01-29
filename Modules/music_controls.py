from Modules.frame_connection import send_to_frame
from kivy.utils import platform

def get_current_song():
    """Get currently playing song from platform-specific APIs"""
    try:
        if platform == 'android':
            # Android-specific code using pyjnius
            try:
                from jnius import autoclass
                MediaSessionManager = autoclass('android.media.session.MediaSessionManager')
                MediaMetadata = autoclass('android.media.MediaMetadata')
                Context = autoclass('android.content.Context')
                PythonActivity = autoclass('org.kivy.android.PythonActivity')
                
                activity = PythonActivity.mActivity
                session_manager = activity.getSystemService(Context.MEDIA_SESSION_SERVICE)
                sessions = session_manager.getActiveSessions(None)
                
                if sessions and sessions.size() > 0:
                    session = sessions.get(0)
                    metadata = session.getMetadata()
                    if metadata:
                        title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
                        artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
                        return f"{title} - {artist}"
            except Exception as e:
                print(f"Android music detection error: {e}")
                return None
        else:
            # Windows/Desktop mock implementation
            return "Mock Song - Mock Artist"
            
    except Exception as e:
        print(f"Error getting song info: {e}")
        return None

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
