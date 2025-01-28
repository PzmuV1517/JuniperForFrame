from Modules.frame_connection import send_to_frame

def display_weather(frame=None):
    message = "Weather: Sunny, 25°C"
    if frame:
        frame.send(message)
    print(message)


def get_detailed_weather(frame=None):
    message = "Detailed Weather: Sunny, 25°C, 10% Humidity, Wind 5 km/h"
    if frame:
        frame.send(message)
    print(message)
