"""Patches the generated Android project (permissions, notification receivers, desugaring)."""
import os, re

manifest = "android/app/src/main/AndroidManifest.xml"
s = open(manifest).read()

perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
"""
receivers = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
if "ScheduledNotificationReceiver" not in s:
    s = s.replace("<application", perms + "    <application", 1)
    s = s.replace("</application>", receivers + "    </application>", 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="Masjid Namaz"', s, count=1)
    open(manifest, "w").write(s)

for gradle in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if not os.path.exists(gradle):
        continue
    g = open(gradle).read()
    if "coreLibraryDesugaring" in g:
        break
    kts = gradle.endswith(".kts")
    flag = "isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"
    dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts
           else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
    g = g.replace("compileOptions {", "compileOptions {\n        " + flag, 1)
    g += "\ndependencies {\n    " + dep + "\n}\n"
    open(gradle, "w").write(g)
    break

print("Android project patched.")
