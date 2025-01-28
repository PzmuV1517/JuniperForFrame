from Modules.frame_connection import send_to_frame

def scan_qr_code(frame=None):
    message = "Scanning QR Code... Result: example.com"
    if frame:
        frame.send(message)
    print(message)
