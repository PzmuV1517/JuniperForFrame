[app]
title = JuniperFrame
package.name = juniperframe
package.domain = org.juniper

source.dir = .
source.include_exts = py,png,jpg,kv,atlas

version = 0.1

requirements = python3,kivy,plyer,pyjnius,android,requests,pillow

orientation = portrait

android.arch = arm64-v8a

# Required permissions
android.permissions = INTERNET,RECORD_AUDIO,WRITE_EXTERNAL_STORAGE,READ_EXTERNAL_STORAGE,CAMERA,ACCESS_FINE_LOCATION,ACCESS_COARSE_LOCATION,SCHEDULE_EXACT_ALARM,WAKE_LOCK,MODIFY_AUDIO_SETTINGS,READ_CALENDAR,WRITE_CALENDAR,ACCESS_NETWORK_STATE,MEDIA_CONTENT_CONTROL,ACCESS_NOTIFICATION_POLICY,BLUETOOTH,BLUETOOTH_ADMIN,BLUETOOTH_CONNECT,BLUETOOTH_SCAN

# Android services
android.services = org.kivy.android.PythonService:Modules/media_listener.py

# Add to android.gradle_dependencies
android.gradle_dependencies = "androidx.core:core:1.6.0"

# Optional: Debugging
android.logcat_filters = *:S python:D

[buildozer]
log_level = 2
warn_on_root = 1