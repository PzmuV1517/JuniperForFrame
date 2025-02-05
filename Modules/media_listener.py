from jnius import autoclass, PythonJavaClass, java_method
from kivy.utils import platform
from android.service import PythonService

if platform == 'android':
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    MediaSessionManager = autoclass('android.media.session.MediaSessionManager')
    NotificationListenerService = autoclass('android.service.notification.NotificationListenerService')
    
    class MediaNotificationListener(PythonService, NotificationListenerService):
        def __init__(self):
            super().__init__()
            self.current_song = None
            self.current_artist = None

        @java_method('(Landroid/service/notification/StatusBarNotification;)V')
        def onNotificationPosted(self, sbn):
            notification = sbn.getNotification()
            extras = notification.extras
            if extras:
                title = extras.getString('android.title')
                text = extras.getString('android.text')
                if title and text:
                    self.current_song = title
                    self.current_artist = text
                    print(f"Now Playing: {title} - {text}")

def get_current_song():
    """Get currently playing song"""
    if platform == 'android':
        service = MediaNotificationListener()
        return service.current_song, service.current_artist
    return None, None