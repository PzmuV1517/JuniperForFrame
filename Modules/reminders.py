from frame_connection import send_to_frame
import time

reminders = [{"time": time.time() + 10, "message": "Meeting with John"}]  # Example reminder


def check_reminders(callback):
    """Periodically check reminders and trigger callback."""
    global reminders
    current_time = time.time()
    triggered_reminders = [rem for rem in reminders if rem["time"] <= current_time]

    for reminder in triggered_reminders:
        callback(reminder)
        reminders.remove(reminder)  # Remove triggered reminder


def show_reminder(reminder=None, frame=None):
    message = f"Reminder: {reminder['message']}" if reminder else "No upcoming reminders."
    if frame:
        frame.send(message)
    print(message)


def add_reminder(frame=None):
    reminder_message = input("What is your reminder? ")
    message = f"Reminder added: {reminder_message}"
    if frame:
        frame.send(message)
    print(message)
