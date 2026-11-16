import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'store.dart';

final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notifBackground(NotificationResponse r) async {
  try {
    await Notif.initPlugin();
    await Notif.onAction(r);
  } catch (_) {}
}

class Notif {
  static bool _ready = false;
  static bool _busy = false;
  static bool _again = false;

  static Future<void> init() async {
    try {
      await initPlugin();
      _ready = true;
    } catch (_) {}
    rebuild();
  }

  static Future<void> initPlugin() async {
    tzdata.initializeTimeZones();
    try {
      final n = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(n));
    } catch (_) {}
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: onAction,
      onDidReceiveBackgroundNotificationResponse: notifBackground,
    );
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.createNotificationChannel(AndroidNotificationChannel('alarm_loud', 'المنبهات (صوت المنبه)',
        description: 'منبهات StudyX بصوت المنبه',
        importance: Importance.max,
        playSound: true,
        sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm));
    await a?.createNotificationChannel(AndroidNotificationChannel('alarm_soft', 'المنبهات (صوت هادئ)',
        description: 'منبهات StudyX بصوت الإشعار',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm));
    await a?.createNotificationChannel(AndroidNotificationChannel('reminders', 'التذكيرات', description: 'تذكيرات المواعيد والمهام', importance: Importance.high));
    await a?.createNotificationChannel(AndroidNotificationChannel('timer', 'المؤقت', description: 'انتهاء جلسات المذاكرة والراحة', importance: Importance.max));
  }

  static Future<Map<String, bool>> status() async {
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final n = await a?.areNotificationsEnabled() ?? true;
    final e = await a?.canScheduleExactNotifications() ?? true;
    return {'notif': n, 'exact': e};
  }

  static Future<void> requestPerms() async {
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await a?.requestNotificationsPermission();
      await a?.requestExactAlarmsPermission();
      await a?.requestFullScreenIntentPermission();
    } catch (_) {}
    rebuild();
  }

  static NotificationDetails _alarmDetails(int sound, bool vib, int snooze) => NotificationDetails(
        android: AndroidNotificationDetails(
          sound == 0 ? 'alarm_loud' : 'alarm_soft',
          'المنبهات',
          channelDescription: 'منبهات StudyX',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: vib,
          visibility: NotificationVisibility.public,
          additionalFlags: Int32List.fromList(<int>[4]),
          actions: [
            if (snooze > 0) AndroidNotificationAction('snooze', 'غفوة $snooze د', cancelNotification: true),
            const AndroidNotificationAction('stop', 'إيقاف', cancelNotification: true),
          ],
        ),
      );

  static const NotificationDetails _reminderDetails = NotificationDetails(
      android: AndroidNotificationDetails('reminders', 'التذكيرات', channelDescription: 'تذكيرات المواعيد والمهام', importance: Importance.high, priority: Priority.high));
  static const NotificationDetails _timerDetails = NotificationDetails(
      android: AndroidNotificationDetails('timer', 'المؤقت', channelDescription: 'انتهاء جلسات المذاكرة والراحة', importance: Importance.max, priority: Priority.max, category: AndroidNotificationCategory.alarm));

  static String _payload(String name, String msg, int id, int sn, int sound, bool vib) => jsonEncode({'id': id, 'name': name, 'msg': msg, 'sn': sn, 'sound': sound, 'vib': vib});

  static Future<void> onAction(NotificationResponse r) async {
    try {
      if (r.actionId == 'snooze' && r.payload != null) {
        final m = jsonDecode(r.payload!) as Map<String, dynamic>;
        final sn = (m['sn'] as num).toInt();
        final when = tz.TZDateTime.now(tz.getLocation('UTC')).add(Duration(minutes: sn));
        final msg = (m['msg'] as String).isEmpty ? 'انتهت الغفوة' : m['msg'] as String;
        await _zs(3000000 + (m['id'] as num).toInt(), m['name'] as String, msg, when, _alarmDetails((m['sound'] as num).toInt(), m['vib'] as bool, sn), mode: AndroidScheduleMode.alarmClock, payload: r.payload);
      }
    } catch (_) {}
  }

  static Future<void> _zs(int id, String title, String body, tz.TZDateTime when, NotificationDetails d, {DateTimeComponents? match, String? payload, AndroidScheduleMode mode = AndroidScheduleMode.exactAllowWhileIdle}) async {
    try {
      await plugin.zonedSchedule(id, title, body, when, d, androidScheduleMode: mode, matchDateTimeComponents: match, payload: payload);
    } catch (_) {
      try {
        await plugin.zonedSchedule(id, title, body, when, d, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, matchDateTimeComponents: match, payload: payload);
      } catch (_) {}
    }
  }

  static tz.TZDateTime _nextAt(int h, int m, [int? weekday]) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    for (var i = 0; i < 9; i++) {
      if (d.isAfter(now) && (weekday == null || d.weekday == weekday)) return d;
      d = tz.TZDateTime(tz.local, d.year, d.month, d.day + 1, h, m);
    }
    return d;
  }

  static bool _dnd(int m) {
    final s = Store.I.s;
    if (!s.b('dndOn', false)) return false;
    final a = s.i('dndStart', 23 * 60), b = s.i('dndEnd', 6 * 60);
    return a > b ? (m >= a || m < b) : (m >= a && m < b);
  }

  static Future<void> testAlarm() async {
    if (!_ready) return;
    final when = tz.TZDateTime.now(tz.getLocation('UTC')).add(const Duration(seconds: 10));
    await _zs(3999999, 'تجربة منبه StudyX', 'إذا سمعت الصوت فالمنبهات تعمل ✔', when, _alarmDetails(0, true, 5), mode: AndroidScheduleMode.alarmClock, payload: _payload('تجربة منبه StudyX', 'إذا سمعت الصوت فالمنبهات تعمل ✔', 3999, 5, 0, true));
  }

  static Future<List<PendingNotificationRequest>> pending() async {
    try {
      return await plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }

  static Future<void> rebuild() async {
    if (!_ready) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _doRebuild();
      } while (_again);
    } catch (_) {} finally {
      _busy = false;
    }
  }

  static Future<void> _doRebuild() async {
    final st = Store.I;
    final pend = await plugin.pendingNotificationRequests();
    for (final p in pend) {
      if (p.id < 3000000) await plugin.cancel(p.id);
    }
    final s = st.s;

    // المنبهات
    if (!s.b('alarmsPaused', false)) {
      for (final a in st.alarms.where((a) => a.enabled)) {
        final body = a.message.isEmpty ? 'حان موعد المنبه' : a.message;
        final d = _alarmDetails(a.sound, a.vibrate, a.snooze);
        final pl = _payload(a.title, body, a.id, a.snooze, a.sound, a.vibrate);
        if (a.dateMs > 0 || a.days.isEmpty) {
          final at = a.nextFire(st.holidays);
          if (at != null) await _zs(a.id * 10, a.title, body, tz.TZDateTime.from(at, tz.local), d, mode: AndroidScheduleMode.alarmClock, payload: pl);
        } else if (a.days.length == 7 && !a.skipHol) {
          await _zs(a.id * 10, a.title, body, _nextAt(a.hour, a.minute), d, match: DateTimeComponents.time, mode: AndroidScheduleMode.alarmClock, payload: pl);
        } else {
          for (final wd in a.days) {
            if (a.skipHol && st.holidays.contains(wd)) continue;
            await _zs(a.id * 10 + wd, a.title, body, _nextAt(a.hour, a.minute, wd), d, match: DateTimeComponents.dayOfWeekAndTime, mode: AndroidScheduleMode.alarmClock, payload: pl);
          }
        }
      }
    }

    // تذكيرات المواعيد
    if (s.b('nEvents', true)) {
      for (final e in st.events) {
        if (s.b('muteHol', false) && st.holidays.contains(e.day)) continue;
        var m = e.start - e.remind;
        var wd = e.day;
        if (m < 0) {
          m += 1440;
          wd = wd == 1 ? 7 : wd - 1;
        }
        if (_dnd(m)) continue;
        final body = e.remind > 0 ? 'تبدأ بعد ${e.remind} دقيقة (${fmtMin(e.start)})' : 'حان الموعد الآن';
        await _zs(1000000 + e.id, e.title, body, _nextAt(m ~/ 60, m % 60, wd), _reminderDetails, match: DateTimeComponents.dayOfWeekAndTime);
      }
    }

    // تسليم المهام
    if (s.b('nTasks', true)) {
      for (final t in st.tasks) {
        if (t.status == 2 || t.due <= 0) continue;
        var at = DateTime.fromMillisecondsSinceEpoch(t.due).subtract(const Duration(hours: 1));
        if (!at.isAfter(DateTime.now())) at = DateTime.fromMillisecondsSinceEpoch(t.due);
        if (!at.isAfter(DateTime.now())) continue;
        if (_dnd(at.hour * 60 + at.minute)) continue;
        await _zs(2000000 + t.id, t.homework ? 'اقتراب تسليم واجب' : 'اقتراب موعد مهمة', t.title, tz.TZDateTime.from(at, tz.local), _reminderDetails);
      }
    }

    if (s.b('nSummary', true)) {
      await _zs(10, 'ملخص نهاية اليوم', 'افتح StudyX لتراجع إنجازك اليوم وتجهّز للغد', _nextAt(21, 0), _reminderDetails, match: DateTimeComponents.time);
    }
    if (s.b('nReview', true)) {
      final m = s.i('reviewMin', 20 * 60);
      await _zs(11, 'وقت المراجعة اليومية', 'خصّص ${s.i('minReview', 20)} دقيقة على الأقل لمراجعة دروسك', _nextAt(m ~/ 60, m % 60), _reminderDetails, match: DateTimeComponents.time);
    }
    if (s.b('sleepRem', false)) {
      final m = (s.i('sleep', 22 * 60) - 30 + 1440) % 1440;
      await _zs(12, 'اقترب موعد النوم', 'جهّز نفسك للنوم لتستيقظ بنشاط', _nextAt(m ~/ 60, m % 60), _reminderDetails, match: DateTimeComponents.time);
    }

    // المؤقت
    final t = st.t;
    if (t.running && t.endAt > nowMs()) {
      final study = t.mode == 'study';
      await _zs(9, study ? 'انتهت جلسة المذاكرة' : 'انتهت فترة الراحة', study ? 'أحسنت! حان وقت الراحة' : 'هيا نبدأ جلسة مذاكرة جديدة', tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, t.endAt), _timerDetails);
    }
  }
}
