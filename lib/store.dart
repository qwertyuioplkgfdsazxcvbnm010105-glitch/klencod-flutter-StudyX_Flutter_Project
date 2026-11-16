import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'notif.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;
String two(int n) => n.toString().padLeft(2, '0');
String dkey(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(int ms, DateTime d) {
  if (ms <= 0) return false;
  final x = DateTime.fromMillisecondsSinceEpoch(ms);
  return x.year == d.year && x.month == d.month && x.day == d.day;
}

String fmtMin(int m) {
  final mm = m % 60;
  final h = (m ~/ 60) % 24;
  if (Store.I.s.b('use24', false)) return '${two(h)}:${two(mm)}';
  final ap = h < 12 ? 'ص' : 'م';
  var hh = h % 12;
  if (hh == 0) hh = 12;
  return '$hh:${two(mm)} $ap';
}

String dateStr(DateTime d) => '${dayNames[d.weekday]} ${d.day} ${monthNames[d.month - 1]} ${d.year}';
String durStr(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}س ${m}د';
  if (m > 0) return '${m}د';
  return '${s}ث';
}

class Store extends ChangeNotifier {
  static final Store I = Store._();
  Store._();
  late SharedPreferences sp;
  int nextId = 1;
  List<Subject> subjects = [];
  List<Event> events = [];
  List<Task> tasks = [];
  List<Alarm> alarms = [];
  List<Session> sessions = [];
  List<Exam> exams = [];
  Set<String> doneEvents = {};
  Settings s = Settings();
  TimerState t = TimerState();
  String? timerNotice;

  int newId() => nextId++;
  List<int> get holidays => s.l('holidays', [5]);

  Future<void> init() async {
    sp = await SharedPreferences.getInstance();
    final raw = sp.getString('data');
    if (raw != null) {
      try {
        _from(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        await sp.setString('data_corrupt_backup', raw);
      }
    }
  }

  List<T> _l<T>(dynamic x, T Function(Map<String, dynamic>) f) => ((x ?? []) as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

  Map<String, dynamic> _to() => {
        'v': 1,
        'nextId': nextId,
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'alarms': alarms.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'exams': exams.map((e) => e.toJson()).toList(),
        'done': doneEvents.toList(),
        'settings': s.m,
        'timer': t.toJson(),
      };

  void _from(Map<String, dynamic> j) {
    nextId = j['nextId'] ?? 1;
    subjects = _l(j['subjects'], Subject.fromJson);
    events = _l(j['events'], Event.fromJson);
    tasks = _l(j['tasks'], Task.fromJson);
    alarms = _l(j['alarms'], Alarm.fromJson);
    sessions = _l(j['sessions'], Session.fromJson);
    exams = _l(j['exams'], Exam.fromJson);
    doneEvents = ((j['done'] ?? []) as List).map((e) => e.toString()).toSet();
    s = Settings()..m = Map<String, dynamic>.from((j['settings'] ?? {}) as Map);
    t = TimerState()..load(Map<String, dynamic>.from((j['timer'] ?? {}) as Map));
  }

  String exportJson() => const JsonEncoder.withIndent(' ').convert(_to());

  Future<bool> importJson(String text) async {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['v'] == null) return false;
      _from(j);
      await commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetAll() async {
    nextId = 1;
    subjects = [];
    events = [];
    tasks = [];
    alarms = [];
    sessions = [];
    exams = [];
    doneEvents = {};
    s = Settings();
    t = TimerState();
    await commit();
  }

  Future<void> commit({bool resched = true}) async {
    await sp.setString('data', jsonEncode(_to()));
    notifyListeners();
    if (resched) Notif.rebuild();
  }

  Future<void> onResume() async {
    for (final a in alarms) {
      if (a.enabled && a.days.isEmpty && a.dateMs == 0 && a.fireMs > 0 && a.fireMs < nowMs()) a.enabled = false;
      if (a.enabled && a.dateMs > 0 && a.nextFire(holidays) == null) a.enabled = false;
    }
    await checkTimer();
    await commit();
  }

  // ---------- helpers ----------
  Subject? subj(int id) {
    for (final x in subjects) {
      if (x.id == id) return x;
    }
    return null;
  }

  String subjName(int id) => subj(id)?.name ?? '';
  int subjColor(int id) => subj(id)?.color ?? 0xFF10B981;

  List<Event> eventsOn(int wd) {
    final l = events.where((e) => e.day == wd).toList();
    l.sort((a, b) => a.start.compareTo(b.start));
    return l;
  }

  DateTime dateOfWeekday(int wd) {
    final n = DateTime.now();
    final ti = (n.weekday + 1) % 7;
    final wi = (wd + 1) % 7;
    return DateTime(n.year, n.month, n.day - ti + wi);
  }

  bool isDone(Event e, DateTime d) => doneEvents.contains('${e.id}|${dkey(d)}');
  Future<void> toggleDone(Event e, DateTime d) async {
    final k = '${e.id}|${dkey(d)}';
    if (!doneEvents.remove(k)) doneEvents.add(k);
    await commit(resched: false);
  }

  List<Event> conflicts(Event e) => events.where((o) => o.id != e.id && o.day == e.day && o.start < e.end && e.start < o.end).toList();

  DateTime nextOcc(Event e) {
    final n = DateTime.now();
    for (var i = 0; i < 8; i++) {
      final d = DateTime(n.year, n.month, n.day + i);
      if (d.weekday != e.day) continue;
      final at = DateTime(d.year, d.month, d.day, e.start ~/ 60, e.start % 60);
      if (at.isAfter(n)) return at;
    }
    return n;
  }

  List<Task> get overdueTasks => tasks.where((t) => t.overdue).toList();

  Future<void> completeTask(Task x, int actual) async {
    x.status = 2;
    x.completedAt = nowMs();
    x.actualMin = actual;
    await commit();
  }

  MapEntry<Alarm, DateTime>? nextAlarm() {
    if (s.b('alarmsPaused', false)) return null;
    MapEntry<Alarm, DateTime>? best;
    for (final a in alarms.where((a) => a.enabled)) {
      final f = a.nextFire(holidays);
      if (f == null) continue;
      if (best == null || f.isBefore(best.value)) best = MapEntry(a, f);
    }
    return best;
  }

  // ---------- stats ----------
  bool isStudyKind(String k) => k != 'rest' && k != 'personal';
  Iterable<Session> sessionsIn(DateTime from, DateTime to) => sessions.where((x) => x.start >= from.millisecondsSinceEpoch && x.start < to.millisecondsSinceEpoch);
  int studySecs(DateTime from, DateTime to) => sessionsIn(from, to).where((x) => isStudyKind(x.kind)).fold<int>(0, (a, x) => a + x.seconds);
  int kindSecs(String k, DateTime from, DateTime to) => sessionsIn(from, to).where((x) => x.kind == k).fold<int>(0, (a, x) => a + x.seconds);
  int get studyToday => studySecs(dayStart(DateTime.now()), dayStart(DateTime.now()).add(const Duration(days: 1)));

  double compliance(DateTime from, DateTime to) {
    var tot = 0, done = 0;
    for (var d = dayStart(from); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      for (final e in eventsOn(d.weekday)) {
        tot++;
        if (isDone(e, d)) done++;
      }
    }
    return tot == 0 ? 0 : done / tot;
  }

  // ---------- review ----------
  Future<void> setLessonStatus(Lesson l, int st) async {
    l.status = st;
    if (st == 2 && l.nextReview == 0) l.nextReview = nowMs() + const Duration(days: 1).inMilliseconds;
    if (st == 3 || st == 4) l.nextReview = nowMs();
    await commit(resched: false);
  }

  Future<void> reviewDone(Lesson l, bool good) async {
    l.reviews++;
    if (good) {
      final days = reviewIntervals[min(l.reviews, reviewIntervals.length - 1)];
      l.status = 2;
      l.nextReview = nowMs() + Duration(days: days).inMilliseconds;
    } else {
      l.status = 3;
      l.nextReview = nowMs() + const Duration(days: 1).inMilliseconds;
    }
    await commit(resched: false);
  }

  List<MapEntry<Subject, Lesson>> dueLessons() {
    final out = <MapEntry<Subject, Lesson>>[];
    for (final sb in subjects) {
      for (final l in sb.lessons) {
        if (l.status == 3 || l.status == 4 || (l.status == 2 && l.nextReview > 0 && l.nextReview <= nowMs())) out.add(MapEntry(sb, l));
      }
    }
    return out;
  }

  // ---------- timer ----------
  int durFor(String mode) => (mode == 'study' ? s.i('studyMin', 50) : mode == 'break' ? s.i('breakMin', 10) : s.i('longMin', 30)) * 60;
  int get remainingNow => t.running ? max(0, ((t.endAt - nowMs()) / 1000).ceil()) : t.remaining;

  Future<void> timerStart() async {
    if (t.running) return;
    if (t.remaining <= 0) t.remaining = t.total;
    t.running = true;
    t.endAt = nowMs() + t.remaining * 1000;
    if (t.startedAt == 0) t.startedAt = nowMs();
    await commit();
  }

  Future<void> timerPause() async {
    if (!t.running) return;
    t.remaining = remainingNow;
    t.running = false;
    await commit();
  }

  Future<void> timerReset() async {
    t.running = false;
    t.total = durFor(t.mode);
    t.remaining = t.total;
    t.startedAt = 0;
    await commit();
  }

  Future<void> timerSetMode(String m) async {
    t.mode = m;
    await timerReset();
  }

  Future<void> timerSetKind(String k, String label) async {
    t.kind = k;
    t.label = label;
    await commit(resched: false);
  }

  Future<void> timerSetMinutes(int m) async {
    if (t.running) return;
    final secs = max(1, m) * 60;
    t.total = secs;
    t.remaining = secs;
    await commit(resched: false);
  }

  void _addStudySession(int secs, int startMs) {
    if (secs < 30) return;
    sessions.add(Session(start: startMs, seconds: secs, kind: t.kind, subjectId: t.subjectId, label: t.label));
    if (t.taskId > 0) {
      for (final x in tasks) {
        if (x.id == t.taskId) x.actualMin += (secs / 60).round();
      }
    }
  }

  Future<void> timerFinishEarly() async {
    final rem = remainingNow;
    final elapsed = t.total - rem;
    if (t.mode == 'study') {
      _addStudySession(elapsed, nowMs() - elapsed * 1000);
      timerNotice = elapsed >= 30 ? 'تم إنهاء الجلسة وحفظ ${durStr(elapsed)}' : 'تم إنهاء الجلسة (أقل من 30 ثانية لم تُسجَّل)';
    } else if (elapsed >= 30) {
      sessions.add(Session(start: nowMs() - elapsed * 1000, seconds: elapsed, kind: 'rest', label: 'راحة'));
    }
    t.running = false;
    t.total = durFor(t.mode);
    t.remaining = t.total;
    t.startedAt = 0;
    await commit();
  }

  Future<void> timerSkipBreak() async {
    if (t.mode == 'study') return;
    t.running = false;
    t.mode = 'study';
    t.total = durFor('study');
    t.remaining = t.total;
    t.startedAt = 0;
    await commit();
  }

  Future<bool> checkTimer() async {
    if (!t.running || nowMs() < t.endAt) return false;
    final secs = t.total;
    String next;
    if (t.mode == 'study') {
      _addStudySession(secs, t.endAt - secs * 1000);
      t.cycle++;
      final every = max(1, s.i('cycles', 2));
      next = t.cycle % every == 0 ? 'long' : 'break';
      timerNotice = 'انتهت الجلسة ✔ وتم حفظ ${durStr(secs)} في السجل';
    } else {
      sessions.add(Session(start: t.endAt - secs * 1000, seconds: secs, kind: 'rest', label: 'راحة'));
      next = 'study';
      timerNotice = 'انتهت الراحة — جاهز لجلسة جديدة؟';
    }
    t.mode = next;
    t.total = durFor(next);
    t.remaining = t.total;
    t.running = false;
    t.startedAt = 0;
    if (s.b('autoBreak', true) && next != 'study') {
      t.running = true;
      t.endAt = nowMs() + t.remaining * 1000;
      t.startedAt = nowMs();
    }
    await commit();
    return true;
  }

  void clearNotice() {
    timerNotice = null;
    notifyListeners();
  }
}
