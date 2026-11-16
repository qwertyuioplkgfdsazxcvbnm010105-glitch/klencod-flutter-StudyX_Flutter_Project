"""يعدّل ملفات Android المولّدة بواسطة flutter create لتشغيل المنبهات والإشعارات."""
import pathlib, re, sys

root = pathlib.Path('android')
man = root / 'app/src/main/AndroidManifest.xml'
t = man.read_text(encoding='utf-8')

perms = ['POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'USE_EXACT_ALARM',
         'USE_FULL_SCREEN_INTENT', 'RECEIVE_BOOT_COMPLETED', 'VIBRATE',
         'WAKE_LOCK']
add = ''.join(
    f'    <uses-permission android:name="android.permission.{p}"/>\n'
    for p in perms if f'android.permission.{p}"' not in t)
if '<application' in t:
    t = t.replace('<application', add + '    <application', 1)

receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
if 'ScheduledNotificationBootReceiver' not in t:
    t = t.replace('</application>', receivers + '    </application>', 1)

t = re.sub(r'android:label="[^"]*"', 'android:label="StudyX"', t, count=1)
if 'showWhenLocked' not in t:
    t = t.replace('<activity', '<activity android:showWhenLocked="true" android:turnScreenOn="true"', 1)
man.write_text(t, encoding='utf-8')

patched = False
for name in ('build.gradle.kts', 'build.gradle'):
    p = root / 'app' / name
    if not p.exists():
        continue
    g = p.read_text(encoding='utf-8')
    kts = name.endswith('.kts')
    if 'coreLibraryDesugaring' not in g:
        line = ('isCoreLibraryDesugaringEnabled = true' if kts
                else 'coreLibraryDesugaringEnabled true')
        g, n = re.subn(r'compileOptions\s*\{', lambda m: m.group(0) + '\n        ' + line, g, count=1)
        if n == 0:
            sys.exit('compileOptions not found in ' + name)
        dep = ('\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' if kts
               else "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n")
        g += dep
        p.write_text(g, encoding='utf-8')
    patched = True
if not patched:
    sys.exit('app build.gradle not found')
print('Android patched OK')
