[app]
title = JuniperFrame
package.name = juniperframe
package.domain = org.juniper
source.dir = .
source.include_exts = py,png,jpg,kv,atlas
version = 0.1
requirements = python3,kivy,datetime,plyer
orientation = portrait
osx.python_version = 3
android.arch = armeabi-v7a
android.permissions = INTERNET,RECORD_AUDIO,WRITE_EXTERNAL_STORAGE,READ_EXTERNAL_STORAGE,CAMERA,ACCESS_FINE_LOCATION,ACCESS_COARSE_LOCATION,SCHEDULE_EXACT_ALARM,WAKE_LOCK,MODIFY_AUDIO_SETTINGS,READ_CALENDAR,WRITE_CALENDAR

[buildozer]
log_level = 2
warn_on_root = 1