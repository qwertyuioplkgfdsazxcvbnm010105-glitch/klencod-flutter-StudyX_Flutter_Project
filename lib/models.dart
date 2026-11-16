const weekOrder = [6, 7, 1, 2, 3, 4, 5];
const dayNames = {6: 'السبت', 7: 'الأحد', 1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس', 5: 'الجمعة'};
const dayShort = {6: 'س', 7: 'ح', 1: 'ن', 2: 'ث', 3: 'ر', 4: 'خ', 5: 'ج'};
const monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const eventTypes = ['المدرسة', 'الدروس الخصوصية', 'المواصلات', 'المذاكرة', 'المراجعة', 'حل الواجبات', 'الاختبارات', 'الراحة', 'تناول الطعام', 'الترفيه', 'النوم', 'الاستيقاظ', 'موعد شخصي'];
const alarmTypes = ['منبه الاستيقاظ', 'منبه النوم', 'منبه المدرسة', 'منبه الدروس', 'منبه المواصلات', 'منبه بداية المذاكرة', 'منبه نهاية المذاكرة', 'منبه الراحة', 'منبه المراجعة', 'منبه الواجبات', 'منبه الاختبارات', 'منبه شخصي'];
const lessonStatus = ['لم يبدأ', 'قيد المذاكرة', 'تمت المذاكرة', 'يحتاج إلى مراجعة', 'يحتاج إلى حل أسئلة'];
const priorities = ['عاجلة جدًا', 'مهمة', 'متوسطة', 'منخفضة'];
const taskStatus = ['جديدة', 'قيد التنفيذ', 'مكتملة', 'مؤجلة'];
const palette = [0xFF10B981, 0xFF3B82F6, 0xFFF59E0B, 0xFFEF4444, 0xFF8B5CF6, 0xFFEC4899, 0xFF14B8A6, 0xFFF97316, 0xFF84CC16, 0xFF06B6D4];
const reviewIntervals = [1, 3, 7, 14, 30, 60];

class Lesson {
  int id;
  String title;
  int status;
  int reviews;
  int nextReview;
  Lesson({required this.id, required this.title, this.status = 0, this.reviews = 0, this.nextReview = 0});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'status': status, 'reviews': reviews, 'nextReview': nextReview};
  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(id: j['id'], title: j['title'], status: j['status'] ?? 0, reviews: j['reviews'] ?? 0, nextReview: j['nextReview'] ?? 0);
}

class Subject {
  int id;
  String name;
  String teacher;
  int color;
  String notes;
  List<Lesson> lessons;
  Subject({required this.id, required this.name, this.teacher = '', this.color = 0xFF10B981, this.notes = '', List<Lesson>? lessons}) : lessons = lessons ?? [];
  int get doneCount => lessons.where((l) => l.status == 2).length;
  double get progress => lessons.isEmpty ? 0 : doneCount / lessons.length;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'teacher': teacher, 'color': color, 'notes': notes, 'lessons': lessons.map((e) => e.toJson()).toList()};
  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
      id: j['id'],
      name: j['name'],
      teacher: j['teacher'] ?? '',
      color: j['color'] ?? 0xFF10B981,
      notes: j['notes'] ?? '',
      lessons: ((j['lessons'] ?? []) as List).map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map))).toList());
}

class Event {
  int id;
  String title;
  int type;
  int subjectId;
  int day; // Dart weekday 1=Mon .. 7=Sun
  int start; // minutes of day
  int end;
  String place;
  String notes;
  int remind; // minutes before
  Event({required this.id, required this.title, this.type = 3, this.subjectId = 0, required this.day, required this.start, required this.end, this.place = '', this.notes = '', this.remind = 10});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type, 'subjectId': subjectId, 'day': day, 'start': start, 'end': end, 'place': place, 'notes': notes, 'remind': remind};
  factory Event.fromJson(Map<String, dynamic> j) => Event(id: j['id'], title: j['title'], type: j['type'] ?? 3, subjectId: j['subjectId'] ?? 0, day: j['day'], start: j['start'], end: j['end'], place: j['place'] ?? '', notes: j['notes'] ?? '', remind: j['remind'] ?? 10);
}

class Task {
  int id;
  String title;
  int subjectId;
  String desc;
  int created;
  int due; // ms, 0 none
  int estMin;
  int priority; // 0..3
  int status; // 0 new,1 doing,2 done,3 postponed
  int actualMin;
  bool homework;
  int completedAt;
  Task({required this.id, required this.title, this.subjectId = 0, this.desc = '', required this.created, this.due = 0, this.estMin = 30, this.priority = 2, this.status = 0, this.actualMin = 0, this.homework = false, this.completedAt = 0});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'subjectId': subjectId, 'desc': desc, 'created': created, 'due': due, 'estMin': estMin, 'priority': priority, 'status': status, 'actualMin': actualMin, 'homework': homework, 'completedAt': completedAt};
  factory Task.fromJson(Map<String, dynamic> j) => Task(id: j['id'], title: j['title'], subjectId: j['subjectId'] ?? 0, desc: j['desc'] ?? '', created: j['created'] ?? 0, due: j['due'] ?? 0, estMin: j['estMin'] ?? 30, priority: j['priority'] ?? 2, status: j['status'] ?? 0, actualMin: j['actualMin'] ?? 0, homework: j['homework'] ?? false, completedAt: j['completedAt'] ?? 0);
  bool get overdue => status != 2 && due > 0 && due < DateTime.now().millisecondsSinceEpoch;
}

class Alarm {
  int id;
  String name;
  int type;
  int hour;
  int minute;
  List<int> days; // empty = once, all 7 = daily
  int dateMs; // specific date (midnight) or 0
  bool enabled;
  String message;
  int snooze; // minutes, 0 = off
  bool vibrate;
  int sound; // 0 alarm, 1 soft
  bool skipHol;
  int taskId;
  int fireMs; // for once alarms
  Alarm({required this.id, this.name = '', this.type = 11, required this.hour, required this.minute, List<int>? days, this.dateMs = 0, this.enabled = true, this.message = '', this.snooze = 10, this.vibrate = true, this.sound = 0, this.skipHol = false, this.taskId = 0, this.fireMs = 0}) : days = days ?? [];
  String get title => name.isEmpty ? alarmTypes[type] : name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'hour': hour, 'minute': minute, 'days': days, 'dateMs': dateMs, 'enabled': enabled, 'message': message, 'snooze': snooze, 'vibrate': vibrate, 'sound': sound, 'skipHol': skipHol, 'taskId': taskId, 'fireMs': fireMs};
  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(id: j['id'], name: j['name'] ?? '', type: j['type'] ?? 11, hour: j['hour'], minute: j['minute'], days: ((j['days'] ?? []) as List).map((e) => (e as num).toInt()).toList(), dateMs: j['dateMs'] ?? 0, enabled: j['enabled'] ?? true, message: j['message'] ?? '', snooze: j['snooze'] ?? 10, vibrate: j['vibrate'] ?? true, sound: j['sound'] ?? 0, skipHol: j['skipHol'] ?? false, taskId: j['taskId'] ?? 0, fireMs: j['fireMs'] ?? 0);

  void arm() {
    final n = DateTime.now();
    var f = DateTime(n.year, n.month, n.day, hour, minute);
    if (!f.isAfter(n)) f = DateTime(n.year, n.month, n.day + 1, hour, minute);
    fireMs = f.millisecondsSinceEpoch;
  }

  DateTime? nextFire(List<int> holidays) {
    final now = DateTime.now();
    if (dateMs > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(dateMs);
      final f = DateTime(d.year, d.month, d.day, hour, minute);
      return f.isAfter(now) ? f : null;
    }
    if (days.isEmpty) {
      if (fireMs <= 0) return null;
      final f = DateTime.fromMillisecondsSinceEpoch(fireMs);
      return f.isAfter(now) ? f : null;
    }
    for (var i = 0; i < 9; i++) {
      final d = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (!d.isAfter(now)) continue;
      if (!days.contains(d.weekday)) continue;
      if (skipHol && holidays.contains(d.weekday)) continue;
      return d;
    }
    return null;
  }
}

class Session {
  int start;
  int seconds;
  String kind; // study, questions, review, reading, personal, rest
  int subjectId;
  String label;
  Session({required this.start, required this.seconds, this.kind = 'study', this.subjectId = 0, this.label = ''});
  Map<String, dynamic> toJson() => {'start': start, 'seconds': seconds, 'kind': kind, 'subjectId': subjectId, 'label': label};
  factory Session.fromJson(Map<String, dynamic> j) => Session(start: j['start'], seconds: j['seconds'], kind: j['kind'] ?? 'study', subjectId: j['subjectId'] ?? 0, label: j['label'] ?? '');
}

class Exam {
  int id;
  String title;
  int subjectId;
  int date;
  int total;
  double score; // -1 = not entered
  String chapters;
  String mistakes;
  String notes;
  Exam({required this.id, required this.title, this.subjectId = 0, required this.date, this.total = 100, this.score = -1, this.chapters = '', this.mistakes = '', this.notes = ''});
  double get pct => (score < 0 || total <= 0) ? -1 : score * 100 / total;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'subjectId': subjectId, 'date': date, 'total': total, 'score': score, 'chapters': chapters, 'mistakes': mistakes, 'notes': notes};
  factory Exam.fromJson(Map<String, dynamic> j) => Exam(id: j['id'], title: j['title'], subjectId: j['subjectId'] ?? 0, date: j['date'], total: j['total'] ?? 100, score: (j['score'] ?? -1).toDouble(), chapters: j['chapters'] ?? '', mistakes: j['mistakes'] ?? '', notes: j['notes'] ?? '');
}

class Settings {
  Map<String, dynamic> m = {};
  int i(String k, int d) => (m[k] as num?)?.toInt() ?? d;
  bool b(String k, bool d) => m[k] as bool? ?? d;
  String s(String k, [String d = '']) => m[k] as String? ?? d;
  double f(String k, double d) => (m[k] as num?)?.toDouble() ?? d;
  List<int> l(String k, List<int> d) => (m[k] as List?)?.map((e) => (e as num).toInt()).toList() ?? d;
  void set(String k, dynamic v) => m[k] = v;
}

class TimerState {
  String mode = 'study'; // study, break, long
  String kind = 'study';
  String label = 'مذاكرة';
  bool running = false;
  int endAt = 0;
  int remaining = 3000;
  int total = 3000;
  int subjectId = 0;
  int taskId = 0;
  int cycle = 0;
  int startedAt = 0;
  Map<String, dynamic> toJson() => {'mode': mode, 'kind': kind, 'label': label, 'running': running, 'endAt': endAt, 'remaining': remaining, 'total': total, 'subjectId': subjectId, 'taskId': taskId, 'cycle': cycle, 'startedAt': startedAt};
  void load(Map<String, dynamic> j) {
    mode = j['mode'] ?? 'study';
    kind = j['kind'] ?? 'study';
    label = j['label'] ?? 'مذاكرة';
    running = j['running'] ?? false;
    endAt = j['endAt'] ?? 0;
    remaining = j['remaining'] ?? 3000;
    total = j['total'] ?? 3000;
    subjectId = j['subjectId'] ?? 0;
    taskId = j['taskId'] ?? 0;
    cycle = j['cycle'] ?? 0;
    startedAt = j['startedAt'] ?? 0;
  }
}
