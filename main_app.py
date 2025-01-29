from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.popup import Popup
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.utils import platform
from datetime import datetime
import json
import os

from Modules.weather import display_weather
from Modules.assistant_commands import process_assistant_command
from Modules.display_time import display_time
from Modules.notifications import display_notifications
from Modules.music_controls import display_current_song, handle_music_command
from Modules.reminders import check_reminders
from Modules.notes import start_note_taking
from Modules.qr_code_scanner import scan_qr_code
from kivy.uix.scrollview import ScrollView
from datetime import datetime, timedelta
from kivy.uix.gridlayout import GridLayout
from kivy.uix.button import Button
from kivy.uix.spinner import Spinner
from calendar import monthrange
import speech_recognition as sr
from kivy.graphics import Color, Rectangle
from threading import Timer
import time

class MainScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # Frame display simulation
        # Create a dark background box
        frame_bg = BoxLayout(
            orientation='vertical',
            size_hint=(1, 0.7),
            padding=10
        )
        frame_bg.canvas.before.add(Color(0, 0, 0, 0.2))
        frame_bg.canvas.before.add(Rectangle(pos=frame_bg.pos, size=frame_bg.size))
        
        # Add Label for display
        self.frame_display = Label(
            text='Frame Display Simulation\n(Tap to start)',
            size_hint=(1, 1),
            halign='center',
            valign='middle',
            color=(0, 1, 0, 1),  # Green text like many AR displays
            font_size='20sp',
            text_size=(None, None),  # Allow text to wrap
            markup=True
        )
        self.frame_display.bind(size=self._update_text_size)
        
        # Add label to background
        frame_bg.add_widget(self.frame_display)
        frame_bg.bind(size=self._update_background)
        frame_bg.bind(pos=self._update_background)
        
        self.layout.add_widget(frame_bg)
        
        # Buttons layout
        buttons_layout = BoxLayout(
            orientation='horizontal',
            size_hint=(1, 0.15),
            spacing=10
        )
        
        # Main function buttons
        tap_button = Button(text='Tap')
        tap_button.bind(on_press=self.handle_tap)
        buttons_layout.add_widget(tap_button)
        
        # Comment out or remove the voice command button
        '''
        voice_button = Button(text='Voice Command')
        voice_button.bind(on_press=self.handle_voice)
        buttons_layout.add_widget(voice_button)
        '''
        
        self.layout.add_widget(buttons_layout)
        
        # Navigation buttons
        nav_layout = BoxLayout(
            orientation='horizontal',
            size_hint=(1, 0.15),
            spacing=10
        )
        
        notes_button = Button(text='Notes')
        notes_button.bind(on_press=self.goto_notes)
        nav_layout.add_widget(notes_button)
        
        reminders_button = Button(text='Reminders')
        reminders_button.bind(on_press=self.goto_reminders)
        nav_layout.add_widget(reminders_button)
        
        qr_button = Button(text='QR History')
        qr_button.bind(on_press=self.goto_qr)
        nav_layout.add_widget(qr_button)
        
        self.layout.add_widget(nav_layout)
        self.add_widget(self.layout)
        
        # Initialize other components
        self.current_song = None
        self.is_playing = False
        self.recognizer = sr.Recognizer()
        self.idle_timer = None
        self.IDLE_TIMEOUT = 6  # seconds
    
    def _update_text_size(self, instance, value):
        instance.text_size = (instance.width, None)
    
    def _update_background(self, instance, value):
        """Update the background rectangle when the layout changes"""
        instance.canvas.before.clear()
        with instance.canvas.before:
            Color(0, 0, 0, 0.2)  # Semi-transparent black
            Rectangle(pos=instance.pos, size=instance.size)
    
    def update_frame_display(self, text):
        """Update the simulated frame display"""
        self.frame_display.text = text

    def start_idle_timer(self):
        """Start or restart the idle timer"""
        if self.idle_timer:
            self.idle_timer.cancel()
        self.idle_timer = Timer(self.IDLE_TIMEOUT, self.clear_screen)
        self.idle_timer.start()

    def clear_screen(self):
        """Clear the frame display"""
        self.update_frame_display("")
        self.idle_timer = None

    def handle_tap(self, instance):
        # Cancel any existing timer
        if self.idle_timer:
            self.idle_timer.cancel()
        
        # Get basic info
        now = datetime.now()
        time_str = now.strftime("%H:%M:%S")
        date_str = now.strftime("%Y-%m-%d")
        display_text = f"Time: {time_str}\nDate: {date_str}\nWeather: Sunny, 25°C"
        
        # Add current song if playing
        from Modules.music_controls import get_current_song
        current_song = get_current_song()
        if current_song:
            display_text += f"\nNow Playing: {current_song}"
        
        self.update_frame_display(display_text)
        
        # Start new idle timer
        self.start_idle_timer()

    def handle_voice(self, instance):
        """Voice commands temporarily disabled"""
        self.update_frame_display("Voice commands are currently disabled")
        self.start_idle_timer()
        
        # Original code commented out for future use
        '''
        if self.idle_timer:
            self.idle_timer.cancel()
                
        try:
            self.update_frame_display("Listening...\nSpeak your command")
            
            with sr.Microphone() as source:
                self.recognizer.adjust_for_ambient_noise(source)
                audio = self.recognizer.listen(source, timeout=5)
                
                self.update_frame_display("Processing your command...")
                command = self.recognizer.recognize_google(audio).lower()
                
                self.update_frame_display(f"Command detected:\n{command}")
                time.sleep(1)
                
                self.process_voice_command(command)
                
        except sr.WaitTimeoutError:
            self.update_frame_display("No speech detected")
        except sr.UnknownValueError:
            self.update_frame_display("Could not understand audio")
        except sr.RequestError as e:
            self.update_frame_display(f"Could not process audio: {str(e)}")
        finally:
            self.start_idle_timer()
        '''

    def process_voice_command(self, command):
        """Voice command processing temporarily disabled"""
        pass
        
        # Original code commented out for future use
        '''
        if "create note" in command:
            self.update_frame_display("Command: Create Note\nListening for note content...")
            try:
                source = sr.Microphone()
                with source as mic:
                    self.recognizer.adjust_for_ambient_noise(mic)
                    self.update_frame_display("Speak your note now...")
                    
                    try:
                        audio = self.recognizer.listen(mic, timeout=10)
                        note_text = self.recognizer.recognize_google(audio)
                        self.update_frame_display(f"Note saved:\n{note_text}")
                        self.notes_screen.notes.append(note_text)
                        self.notes_screen.save_notes()
                        self.start_idle_timer()
                    except sr.UnknownValueError:
                        self.update_frame_display("Could not understand audio")
                    except sr.RequestError:
                        self.update_frame_display("Could not process audio")
                    
            except Exception as e:
                self.update_frame_display("Error saving note")
                    
        elif "create reminder" in command:
            # ... rest of the code ...
        '''

    def handle_music_command(self, command):
        if "next song" in command:
            self.current_song = "Next Song"
        elif "previous song" in command:
            self.current_song = "Previous Song"
        elif "pause" in command:
            self.is_playing = False
        elif "play" in command:
            self.is_playing = True
        
        status = "Playing" if self.is_playing else "Paused"
        self.info_label.text = f"Music: {status}\nCurrent Song: {self.current_song}"
    
    def ask_reminder_details(self):
        content = BoxLayout(orientation='vertical', padding=10, spacing=10)
        self.reminder_title = TextInput(
            multiline=False,
            hint_text='What is your new reminder?'
        )
        self.reminder_datetime = TextInput(
            multiline=False,
            hint_text='When? (e.g., January 30th 2025 at 20:30)'
        )
        submit_button = Button(text='Add Reminder')
        submit_button.bind(on_press=self.save_reminder)
        
        content.add_widget(Label(text='New Reminder'))
        content.add_widget(self.reminder_title)
        content.add_widget(self.reminder_datetime)
        content.add_widget(submit_button)
        
        self.reminder_popup = Popup(
            title='New Reminder',
            content=content,
            size_hint=(0.8, 0.6)
        )
        self.reminder_popup.open()
    
    def save_reminder(self, instance):
        title = self.reminder_title.text
        datetime_str = self.reminder_datetime.text
        App.get_running_app().reminders_screen.add_reminder(title, datetime_str)
        self.reminder_popup.dismiss()
        self.info_label.text = f"Reminder added:\n{title}\n{datetime_str}"
    
    def show_next_reminder(self):
        next_reminder = App.get_running_app().reminders_screen.get_next_reminder()
        if next_reminder:
            self.info_label.text = f"Next reminder:\n{next_reminder['title']}\n{next_reminder['datetime']}"
        else:
            self.info_label.text = "No upcoming reminders"
    
    def goto_notes(self, instance):
        self.manager.current = 'notes'
    
    def goto_reminders(self, instance):
        self.manager.current = 'reminders'
    
    def goto_qr(self, instance):
        self.manager.current = 'qr'

class NotesScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # Notes list
        self.notes_label = Label(text='Your Notes:', size_hint=(1, 0.1))
        
        # Scrollable notes list
        self.notes_layout = BoxLayout(
            orientation='vertical',
            size_hint=(1, 0.6),
            spacing=5
        )
        
        # New note button
        new_note_button = Button(
            text='New Note',
            size_hint=(1, 0.15)
        )
        new_note_button.bind(on_press=self.start_new_note)
        
        # Back button
        back_button = Button(
            text='Back to Main',
            size_hint=(1, 0.15)
        )
        back_button.bind(on_press=self.go_back)
        
        # Add widgets
        self.layout.add_widget(self.notes_label)
        self.layout.add_widget(self.notes_layout)
        self.layout.add_widget(new_note_button)
        self.layout.add_widget(back_button)
        self.add_widget(self.layout)
        
        # Load saved notes
        self.notes = self.load_notes()
        self.update_notes_display()
    
    def load_notes(self):
        if os.path.exists('notes.json'):
            with open('notes.json', 'r') as f:
                return json.load(f)
        return []
    
    def save_notes(self):
        with open('notes.json', 'w') as f:
            json.dump(self.notes, f)
    
    def update_notes_display(self):
        self.notes_layout.clear_widgets()
        for i, note in enumerate(self.notes):
            # Create button for each note
            preview = note[:50] + "..." if len(note) > 50 else note
            note_button = Button(
                text=preview,
                size_hint=(1, None),
                height='44dp'
            )
            note_button.bind(on_press=lambda x, i=i: self.view_note(i))
            self.notes_layout.add_widget(note_button)
    
    def view_note(self, index):
        screen_name = f'note_{index}'
        note_screen = NoteDetailScreen(
            self.notes[index],
            index,
            self,
            name=screen_name
        )
        
        # Add screen if it doesn't exist
        if not self.manager.has_screen(screen_name):
            self.manager.add_widget(note_screen)
        
        self.manager.current = screen_name
    
    def start_new_note(self, *args):
        content = BoxLayout(orientation='vertical', padding=10, spacing=10)
        self.note_input = TextInput(
            multiline=True,
            size_hint=(1, 0.8)
        )
        save_button = Button(
            text='Save Note',
            size_hint=(1, 0.2)
        )
        save_button.bind(on_press=self.save_note)
        
        content.add_widget(self.note_input)
        content.add_widget(save_button)
        
        self.note_popup = Popup(
            title='New Note',
            content=content,
            size_hint=(0.9, 0.9)
        )
        self.note_popup.open()
    
    def save_note(self, instance):
        note_text = self.note_input.text
        if note_text:
            self.notes.append(note_text)
            self.save_notes()
            self.update_notes_display()
        self.note_popup.dismiss()
    
    def go_back(self, instance):
        self.manager.current = 'main'
    
    def delete_note(self, index):
        if 0 <= index < len(self.notes):
            del self.notes[index]
            self.save_notes()
            self.update_notes_display()
            
            # Remove the screen
            screen_name = f'note_{index}'
            if self.manager.has_screen(screen_name):
                self.manager.remove_widget(self.manager.get_screen(screen_name))

class NoteDetailScreen(Screen):
    def __init__(self, note_text, note_index, notes_screen, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        self.notes_screen = notes_screen
        self.note_index = note_index
        
        # Note content
        self.note_content = TextInput(
            text=note_text,
            multiline=True,
            size_hint=(1, 0.7),
            readonly=True
        )
        self.layout.add_widget(self.note_content)
        
        # Buttons layout
        buttons_layout = BoxLayout(
            orientation='horizontal',
            size_hint=(1, 0.3),
            spacing=10
        )
        
        # Delete button
        delete_button = Button(
            text='Delete Note',
            size_hint=(1, 0.5)
        )
        delete_button.bind(on_press=self.delete_note)
        
        # Back button
        back_button = Button(
            text='Back to Notes',
            size_hint=(1, 0.5)
        )
        back_button.bind(on_press=self.go_back)
        
        buttons_layout.add_widget(delete_button)
        buttons_layout.add_widget(back_button)
        self.layout.add_widget(buttons_layout)
        self.add_widget(self.layout)
    
    def delete_note(self, instance):
        # Delete the note first
        self.notes_screen.delete_note(self.note_index)
        # Then get the screen manager from the app and navigate back
        App.get_running_app().sm.current = 'notes'
    
    def go_back(self, instance):
        # Use the app's screen manager to navigate
        App.get_running_app().sm.current = 'notes'

class RemindersScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # Reminders list
        self.reminders_label = Label(text='Your Reminders:', size_hint=(1, 0.1))
        
        # Scrollable reminders list
        self.reminders_layout = BoxLayout(
            orientation='vertical',
            size_hint=(1, 0.6),
            spacing=5
        )
        
        # New reminder button
        new_reminder_button = Button(
            text='New Reminder',
            size_hint=(1, 0.15)
        )
        new_reminder_button.bind(on_press=self.add_reminder_popup)
        
        # Back button
        back_button = Button(
            text='Back to Main',
            size_hint=(1, 0.15)
        )
        back_button.bind(on_press=self.go_back)
        
        # Add widgets
        self.layout.add_widget(self.reminders_label)
        self.layout.add_widget(self.reminders_layout)
        self.layout.add_widget(new_reminder_button)
        self.layout.add_widget(back_button)
        self.add_widget(self.layout)
        
        # Load saved reminders
        self.reminders = self.load_reminders()
        self.update_reminders_display()
    
    def load_reminders(self):
        if os.path.exists('reminders.json'):
            with open('reminders.json', 'r') as f:
                return json.load(f)
        return []
    
    def save_reminders(self):
        with open('reminders.json', 'w') as f:
            json.dump(self.reminders, f)
    
    def update_reminders_display(self):
        self.reminders_layout.clear_widgets()
        for i, reminder in enumerate(self.reminders):
            reminder_button = Button(
                text=f"{reminder['title']} - {reminder['datetime']}",
                size_hint=(1, None),
                height='44dp'
            )
            reminder_button.bind(on_press=lambda x, i=i: self.view_reminder(i))
            self.reminders_layout.add_widget(reminder_button)
    
    def view_reminder(self, index):
        screen_name = f'reminder_{index}'
        reminder_screen = ReminderDetailScreen(
            self.reminders[index],
            index,
            self,
            name=screen_name
        )
        
        if not self.manager.has_screen(screen_name):
            self.manager.add_widget(reminder_screen)
        
        self.manager.current = screen_name
    
    def add_reminder_popup(self, instance):
        content = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # Title input
        self.reminder_title = TextInput(
            multiline=False,
            hint_text='What is your reminder?',
            size_hint=(1, 0.2)
        )
        
        # Date and time selection layout
        datetime_layout = GridLayout(
            cols=1, 
            spacing=10,
            size_hint=(1, 0.6)
        )
        
        # Month selector
        current_month = datetime.now().month
        months = ['January', 'February', 'March', 'April', 'May', 'June', 
                 'July', 'August', 'September', 'October', 'November', 'December']
        self.month_spinner = Spinner(
            text=months[current_month-1],
            values=months,
            size_hint=(1, None),
            height='44dp'
        )
        
        # Year selector
        current_year = datetime.now().year
        years = [str(year) for year in range(current_year, current_year + 5)]
        self.year_spinner = Spinner(
            text=str(current_year),
            values=years,
            size_hint=(1, None),
            height='44dp'
        )
        
        # Day selector (will be updated based on month/year)
        self.day_spinner = Spinner(
            text='1',
            values=[str(i) for i in range(1, 32)],
            size_hint=(1, None),
            height='44dp'
        )
        
        # Hour selector
        hours = [f"{i:02d}" for i in range(24)]
        self.hour_spinner = Spinner(
            text=hours[0],
            values=hours,
            size_hint=(1, None),
            height='44dp'
        )
        
        # Minute selector
        minutes = [f"{i:02d}" for i in range(0, 60, 5)]
        self.minute_spinner = Spinner(
            text=minutes[0],
            values=minutes,
            size_hint=(1, None),
            height='44dp'
        )
        
        # Add change handlers
        self.month_spinner.bind(text=self.update_days)
        self.year_spinner.bind(text=self.update_days)
        
        # Add selectors to layout
        datetime_layout.add_widget(Label(text='Month:'))
        datetime_layout.add_widget(self.month_spinner)
        datetime_layout.add_widget(Label(text='Year:'))
        datetime_layout.add_widget(self.year_spinner)
        datetime_layout.add_widget(Label(text='Day:'))
        datetime_layout.add_widget(self.day_spinner)
        datetime_layout.add_widget(Label(text='Hour:'))
        datetime_layout.add_widget(self.hour_spinner)
        datetime_layout.add_widget(Label(text='Minute:'))
        datetime_layout.add_widget(self.minute_spinner)
        
        # Save button
        save_button = Button(
            text='Save Reminder',
            size_hint=(1, 0.2)
        )
        save_button.bind(on_press=self.save_reminder)
        
        # Add all to main content
        content.add_widget(self.reminder_title)
        content.add_widget(datetime_layout)
        content.add_widget(save_button)
        
        self.reminder_popup = Popup(
            title='New Reminder',
            content=content,
            size_hint=(0.9, 0.9)
        )
        self.reminder_popup.open()
    
    def update_days(self, instance, value):
        """Update the available days based on selected month and year"""
        try:
            month_idx = ['January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'].index(self.month_spinner.text) + 1
            year = int(self.year_spinner.text)
            _, num_days = monthrange(year, month_idx)
            
            self.day_spinner.values = [str(i) for i in range(1, num_days + 1)]
            if int(self.day_spinner.text) > num_days:
                self.day_spinner.text = str(num_days)
        except ValueError:
            pass
    
    def save_reminder(self, instance):
        if self.reminder_title.text:
            month = self.month_spinner.text
            day = self.day_spinner.text
            year = self.year_spinner.text
            hour = self.hour_spinner.text
            minute = self.minute_spinner.text
            
            datetime_str = f"{month} {day} {year} at {hour}:{minute}"
            
            self.reminders.append({
                'title': self.reminder_title.text,
                'datetime': datetime_str
            })
            self.save_reminders()
            self.update_reminders_display()
            self.reminder_popup.dismiss()
    
    def get_next_reminder(self):
        return self.reminders[0] if self.reminders else None
    
    def go_back(self, instance):
        self.manager.current = 'main'
    
    def delete_reminder(self, index):
        if 0 <= index < len(self.reminders):
            del self.reminders[index]
            self.save_reminders()
            self.update_reminders_display()
            
            # Remove the screen
            screen_name = f'reminder_{index}'
            if self.manager.has_screen(screen_name):
                self.manager.remove_widget(self.manager.get_screen(screen_name))

class ReminderDetailScreen(Screen):
    def __init__(self, reminder, reminder_index, reminders_screen, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        self.reminders_screen = reminders_screen
        self.reminder_index = reminder_index
        
        # Reminder content
        content_layout = BoxLayout(orientation='vertical', size_hint=(1, 0.7))
        self.title_label = Label(
            text=f"Title: {reminder['title']}",
            size_hint=(1, 0.5)
        )
        self.datetime_label = Label(
            text=f"When: {reminder['datetime']}",
            size_hint=(1, 0.5)
        )
        content_layout.add_widget(self.title_label)
        content_layout.add_widget(self.datetime_label)
        self.layout.add_widget(content_layout)
        
        # Buttons layout
        buttons_layout = BoxLayout(
            orientation='horizontal',
            size_hint=(1, 0.3),
            spacing=10
        )
        
        # Delete button
        delete_button = Button(
            text='Delete Reminder',
            size_hint=(1, 0.5)
        )
        delete_button.bind(on_press=self.delete_reminder)
        
        # Back button
        back_button = Button(
            text='Back to Reminders',
            size_hint=(1, 0.5)
        )
        back_button.bind(on_press=self.go_back)
        
        buttons_layout.add_widget(delete_button)
        buttons_layout.add_widget(back_button)
        self.layout.add_widget(buttons_layout)
        self.add_widget(self.layout)
    
    def delete_reminder(self, instance):
        self.reminders_screen.delete_reminder(self.reminder_index)
        App.get_running_app().sm.current = 'reminders'
    
    def go_back(self, instance):
        App.get_running_app().sm.current = 'reminders'

class QRScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # QR history list
        self.qr_label = Label(text='QR Code History:', size_hint=(1, 0.1))
        self.qr_list = Label(text='No QR codes scanned', size_hint=(1, 0.6))
        
        # Scan button
        scan_button = Button(
            text='Scan QR Code',
            size_hint=(1, 0.15)
        )
        scan_button.bind(on_press=self.scan_qr)
        
        # Back button
        back_button = Button(
            text='Back to Main',
            size_hint=(1, 0.15)
        )
        back_button.bind(on_press=self.go_back)
        
        # Add widgets
        self.layout.add_widget(self.qr_label)
        self.layout.add_widget(self.qr_list)
        self.layout.add_widget(scan_button)
        self.layout.add_widget(back_button)
        self.add_widget(self.layout)
        
        # Load QR history
        self.qr_history = self.load_qr_history()
        self.update_qr_display()
    
    def load_qr_history(self):
        if os.path.exists('qr_history.json'):
            with open('qr_history.json', 'r') as f:
                return json.load(f)
        return []
    
    def save_qr_history(self):
        with open('qr_history.json', 'w') as f:
            json.dump(self.qr_history, f)
    
    def update_qr_display(self):
        self.qr_list.text = '\n'.join(self.qr_history) or 'No QR codes scanned'
    
    def scan_qr(self, instance):
        # Simulate QR scan
        scanned_code = "example.com"
        self.qr_history.append(scanned_code)
        self.save_qr_history()
        self.update_qr_display()
    
    def go_back(self, instance):
        self.manager.current = 'main'

class FrameApp(App):
    def build(self):
        # Create screen manager
        self.sm = ScreenManager()
        
        # Create main screens
        self.main_screen = MainScreen(name='main')
        self.notes_screen = NotesScreen(name='notes')
        self.reminders_screen = RemindersScreen(name='reminders')
        self.qr_screen = QRScreen(name='qr')
        
        # Add screens to manager
        self.sm.add_widget(self.main_screen)
        self.sm.add_widget(self.notes_screen)
        self.sm.add_widget(self.reminders_screen)
        self.sm.add_widget(self.qr_screen)
        
        return self.sm

if __name__ == '__main__':
    FrameApp().run()