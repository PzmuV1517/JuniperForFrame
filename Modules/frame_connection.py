from plyer import bluetooth
from kivy.utils import platform
from kivy.clock import Clock

class FrameConnection:
    def __init__(self):
        self.frame_device = None
        self.is_connected = False
        self.frame_name = "Frame"  # The name your Frame broadcasts
        self.connection_retries = 0
        self.max_retries = 3

    def scan_for_frame(self):
        """Scan for Frame device in nearby Bluetooth devices"""
        try:
            if not bluetooth.is_enabled():
                bluetooth.start()
            
            print("Scanning for Frame device...")
            devices = bluetooth.get_discovered_devices()
            
            for device in devices:
                if self.frame_name in device.get('name', ''):
                    self.frame_device = device
                    print(f"Found Frame device: {device['name']}")
                    return True
            
            print("Frame device not found")
            return False
            
        except Exception as e:
            print(f"Error scanning for Frame: {e}")
            return False

    def connect(self):
        """Connect to the Frame device"""
        if not self.frame_device:
            if not self.scan_for_frame():
                return False

        try:
            if not self.is_connected:
                bluetooth.connect(self.frame_device['address'])
                self.is_connected = True
                print("Connected to Frame")
                return True
                
        except Exception as e:
            print(f"Error connecting to Frame: {e}")
            self.connection_retries += 1
            if self.connection_retries < self.max_retries:
                print(f"Retrying connection... ({self.connection_retries}/{self.max_retries})")
                Clock.schedule_once(lambda dt: self.connect(), 2)
            return False

    def disconnect(self):
        """Disconnect from the Frame device"""
        try:
            if self.is_connected:
                bluetooth.disconnect(self.frame_device['address'])
                self.is_connected = False
                print("Disconnected from Frame")
                
        except Exception as e:
            print(f"Error disconnecting from Frame: {e}")

    def send_text(self, message):
        """Send text message to Frame"""
        try:
            if not self.is_connected:
                if not self.connect():
                    return False
            
            bluetooth.send(self.frame_device['address'], message)
            return True
            
        except Exception as e:
            print(f"Error sending message to Frame: {e}")
            self.is_connected = False
            return False

# Create a single instance of the Frame connection
frame_connection = FrameConnection()

def connect_to_frame():
    """Get the Frame connection instance"""
    return frame_connection if frame_connection.connect() else None

def send_to_frame(message):
    """Send a message to the frame"""
    if frame_connection.send_text(message):
        print(f"Message sent to Frame: {message}")
    else:
        print("Failed to send message to Frame")
