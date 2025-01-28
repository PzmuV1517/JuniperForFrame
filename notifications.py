from frame_connection import send_to_frame

def display_notifications(limit, frame=None):
    """Display the latest notifications."""
    notifications = ["Email from Boss", "Meeting Reminder"]
    for notification in notifications[:limit]:
        if frame:
            frame.send(notification)
        print(f"Notification: {notification}")


def show_notification(notification, frame=None):
    message = f"New Notification: {notification}"
    if frame:
        frame.send(message)
    print(message)
