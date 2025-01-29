from Modules.frame_connection import send_to_frame
import time
import os
import json
from datetime import datetime

reminders = [{"time": time.time() + 10, "message": "Meeting with John"}]  # Example reminder


def check_reminders(callback):
    """Periodically check reminders and trigger callback."""
    if os.path.exists('reminders.json'):
        with open('reminders.json', 'r') as f:
            reminders = json.load(f)
        
        current_time = datetime.now()
        for reminder in reminders:
            reminder_time = datetime.strptime(reminder['datetime'], '%B %d %Y at %H:%M')
            if current_time >= reminder_time:
                callback(reminder)
                reminders.remove(reminder)
                
        with open('reminders.json', 'w') as f:
            json.dump(reminders, f)


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
