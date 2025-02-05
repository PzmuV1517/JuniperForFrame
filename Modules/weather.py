from Modules.frame_connection import send_to_frame
from plyer import temperature
from datetime import datetime
import json
import os

class WeatherManager:
    def __init__(self):
        self.last_weather = None
        self.last_update = None
        self.update_interval = 600  # 10 minutes in seconds
        
        # Load cached weather
        self.load_cached_weather()
    
    def load_cached_weather(self):
        """Load weather data from cache file"""
        if os.path.exists('weather_cache.json'):
            try:
                with open('weather_cache.json', 'r') as f:
                    data = json.load(f)
                    self.last_weather = data['weather']
                    self.last_update = datetime.fromisoformat(data['timestamp'])
            except:
                pass
    
    def save_cached_weather(self):
        """Save weather data to cache file"""
        if self.last_weather:
            data = {
                'weather': self.last_weather,
                'timestamp': datetime.now().isoformat()
            }
            with open('weather_cache.json', 'w') as f:
                json.dump(data, f)
    
    def get_weather(self):
        """Get temperature data from the phone's temperature service"""
        now = datetime.now()
        
        try:
            # Use phone's temperature sensor directly
            temp = temperature.get_temperature()  # Verify correct method from plyer
            if temp:
                self.last_weather = {'temperature': temp}
                self.last_update = now
                self.save_cached_weather()
                return self.last_weather
        except Exception as e:
            print(f"Error getting temperature: {e}")
            return self.last_weather if self.last_weather else None

def format_weather(weather_data):
    """Format current temperature data for display"""
    if not weather_data:
        return "Temperature data unavailable"
    
    try:
        temp = round(weather_data['temperature'])
        
        return f"Temperature: {temp}°C"
    except Exception as e:
        print(f"Error formatting temperature: {e}")
        return "Temperature data format error"

def format_detailed_weather(weather_data):
    """Format detailed temperature data"""
    if not weather_data:
        return "Temperature data unavailable"
    
    try:
        temp = round(weather_data['temperature'])
        
        return f"Temperature: {temp}°C"
    except Exception as e:
        print(f"Error formatting detailed temperature: {e}")
        return "Temperature data format error"

# Create a global instance
weather_manager = WeatherManager()

def display_weather(frame=None):
    """Display basic temperature information"""
    weather_data = weather_manager.get_weather()
    message = format_weather(weather_data)
    
    if frame:
        frame.send_text(message)
    print(message)

def get_detailed_weather(frame=None):
    """Display detailed temperature information"""
    weather_data = weather_manager.get_weather()
    message = format_detailed_weather(weather_data)
    
    if frame:
        frame.send_text(message)
    print(message)
