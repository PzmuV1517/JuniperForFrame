import time
import threading
from Modules.frame_connection import connect_to_frame, send_to_frame
from Modules.tap_detection import detect_tap, handle_voice_command
from Modules.display_time import display_time
from Modules.notifications import display_notifications, show_notification
from Modules.weather import display_weather, get_detailed_weather
from Modules.music_controls import display_current_song, handle_music_command
from Modules.reminders import check_reminders, show_reminder, add_reminder
from Modules.notes import start_note_taking
from Modules.qr_code_scanner import scan_qr_code
from Modules.assistant_commands import process_assistant_command
from datetime import datetime

IDLE_TIMEOUT = 6  # Time in seconds before going idle

# Global variables
screen_active = False
current_song = None


def idle_screen():
    """Blank the screen."""
    global screen_active
    print("Screen is now idle.")
    send_to_frame("clear_screen")
    screen_active = False


def activate_screen():
    """Activate the screen."""
    global screen_active
    screen_active = True
    send_to_frame("screen_active")
    print("Screen activated.")
    threading.Timer(IDLE_TIMEOUT, idle_screen).start()


def on_new_notification(notification):
    activate_screen()
    show_notification(notification)


def on_reminder_triggered(reminder):
    activate_screen()
    show_reminder(reminder)


def display_main_screen(frame):
    """Display all main screen information at once"""
    # Get current time and date
    now = datetime.now()
    time_str = now.strftime("%H:%M:%S")
    date_str = now.strftime("%Y-%m-%d")
    
    # Build the combined display message
    display_message = f"Time: {time_str}\nDate: {date_str}"
    
    # Add weather
    weather_info = "Sunny, 25°C"  # From weather.py
    display_message += f"\nWeather: {weather_info}"
    
    # Add current song if playing
    if current_song:
        display_message += f"\nNow Playing: {current_song}"
        
    # Send combined message to frame
    if frame:
        frame.send(display_message)
    print(display_message)


def main():
    frame = connect_to_frame()  # Connect to the Brilliant Labs Frame

    if not frame:
        print("Could not connect to the Brilliant Labs Frame.")
        return

    print("Brilliant Frame System Starting...")
    threading.Timer(1, check_reminders, args=(on_reminder_triggered,)).start()  # Periodically check reminders

    while True:
        tap_type, voice_command = detect_tap()
        time.sleep(0.1)  # Add small delay to prevent high CPU usage

        if tap_type == "single":
            activate_screen()
            display_main_screen(frame)

        elif tap_type == "double":
            command = handle_voice_command()
            process_assistant_command(command)

        elif voice_command:
            activate_screen()
            if "new note" in voice_command:
                start_note_taking(frame)
            elif "next song" in voice_command or "previous song" in voice_command or "pause" in voice_command:
                handle_music_command(voice_command, frame)
            elif "weather" in voice_command:
                get_detailed_weather(frame)
            elif "show reminders" in voice_command:
                show_reminder(frame)
            elif "new reminder" in voice_command:
                add_reminder(frame)


if __name__ == "__main__":
    main()
