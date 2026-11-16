import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'ui.dart';
import 'schedule_tasks.dart';
import 'timer_alarms.dart';
import 'more.dart';

final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Timer? _tk;
  @override
  void initState() {
    super.initState();
    _tk = Timer.periodic(const Duration(seconds: 1), (_) => Store.I.checkTimer());
  }

  @override
  void dispose() {
    _tk?.cancel();
    super.dispose();
  }

  static const titles = ['StudyX', 'جدول الأسبوع', 'المهام والواجبات', 'المؤقت', 'المنبهات'];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: tabIndex,
        builder: (c, i, _) {
          final pages = <Widget>[const HomePage(), const SchedulePage(), const TasksPage(), const TimerPage(), const AlarmsPage()];
          return Scaffold(
            appBar: AppBar(title: Text(titles[i])),
            drawer: const AppDrawer(),
            body: pages[i],
            bottomNavigationBar: NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => tabIndex.value = v,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
                NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: 'الجدول'),
                NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'المهام'),
                NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: 'المؤقت'),
                NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm), label: 'المنبهات'),
              ],
            ),
          );
        },
      );
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  void _go(BuildContext c, Widget w) {
    Navigator.pop(c);
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext c) {
    final items = <(IconData, String, Widget)>[
      (Icons.menu_book, 'المواد الدراسية', const SubjectsPage()),
      (Icons.replay, 'المراجعة', const ReviewPage()),
      (Icons.quiz, 'الاختبارات', const ExamsPage()),
      (Icons.insights, 'الإحصائيات والتقارير', const StatsPage()),
      (Icons.calendar_month, 'التقويم الشهري', const CalendarPage()),
      (Icons.bedtime, 'النوم والراحة', const SleepPage()),
      (Icons.notifications, 'مركز الإشعارات', const NotifCenterPage()),
      (Icons.backup, 'النسخ الاحتياطي', const BackupPage()),
      (Icons.settings, 'الإعدادات', const SettingsPage()),
    ];
    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          const ListTile(leading: Icon(Icons.auto_stories, color: emerald, size: 34), title: Text('StudyX', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), subtitle: Text('نظّم وقتك، تابع إنجازك')),
          const Divider(),
          for (final it in items) ListTile(leading: Icon(it.$1), title: Text(it.$2), onTap: () => _go(c, it.$3)),
        ]),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: Store.I,
        builder: (c, _) {
          final st = Store.I;
          final now = DateTime.now();
          final nm = now.hour * 60 + now.minute;
          final evs = st.eventsOn(now.weekday);
          Event? cur, next;
          for (final e in evs) {
            if (e.start <= nm && nm < e.end) cur = e;
            if (e.start > nm && next == null) next = e;
          }
          final tToday = st.tasks.where((t) => sameDay(t.due, now) || sameDay(t.completedAt, now)).toList();
          final doneEv = evs.where((e) => st.isDone(e, now)).length;
          final doneT = tToday.where((t) => t.status == 2).length;
          final total = evs.length + tToday.length;
          final done = doneEv + doneT;
          final pct = total == 0 ? 0.0 : done / total;
          final g = now.hour < 12 ? 'صباح الخير' : now.hour < 18 ? 'مساء الخير' : 'مساء النور';
          final name = st.s.s('name');
          final na = st.nextAlarm();
          Event? lesson;
          DateTime? lessonAt;
          for (final e in st.events.where((e) => e.type == 0 || e.type == 1)) {
            final at = st.nextOcc(e);
            if (lessonAt == null || at.isBefore(lessonAt)) {
              lesson = e;
              lessonAt = at;
            }
          }
          final od = st.overdueTasks.length;
          return ListView(padding: const EdgeInsets.all(16), children: [
            panel(
                c,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.auto_stories, color: emerald),
                    const SizedBox(width: 8),
                    Text(name.isEmpty ? g : '$g يا $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  gap(8),
                  const ClockText(),
                  Text(dateStr(now), style: TextStyle(color: muted(c))),
                ])),
            panel(
                c,
                Column(children: [
                  Row(children: [
                    const Text('إنجاز اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: emerald)),
                  ]),
                  gap(8),
                  LinearProgressIndicator(value: pct, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                  gap(12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    Stat('$done', 'مكتملة'),
                    Stat('${total - done}', 'متبقية'),
                    Stat(durStr(st.studyToday), 'مذاكرة اليوم'),
                  ]),
                ])),
            if (od > 0)
              panel(c, Row(children: [const Icon(Icons.warning_amber, color: Colors.redAccent), const SizedBox(width: 8), Expanded(child: Text('لديك $od مهمة متأخرة')), const Icon(Icons.chevron_left)], ), onTap: () => tabIndex.value = 2),
            panel(
                c,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row(c, Icons.play_circle, 'المهمة الحالية', cur == null ? 'لا توجد مهمة الآن' : '${cur.title} (حتى ${fmtMin(cur.end)})'),
                  gap(8),
                  _row(c, Icons.skip_next, 'المهمة القادمة', next == null ? 'لا توجد مهام أخرى اليوم' : '${next.title} — ${fmtMin(next.start)} (بعد ${durStr((next.start - nm) * 60)})'),
                  gap(8),
                  _row(c, Icons.alarm, 'أقرب منبه', na == null ? 'لا توجد منبهات مفعّلة' : '${na.key.title} — ${dayNames[na.value.weekday]} ${fmtMin(na.value.hour * 60 + na.value.minute)}'),
                  gap(8),
                  _row(c, Icons.school, 'أقرب درس', lesson == null ? 'لم تُضف دروسًا' : '${lesson.title} — ${dayNames[lessonAt!.weekday]} ${fmtMin(lesson.start)}'),
                ])),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: () async {
                    await st.timerStart();
                    tabIndex.value = 3;
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('بدء المذاكرة')),
              FilledButton.tonalIcon(onPressed: () => tabIndex.value = 1, icon: const Icon(Icons.calendar_view_week), label: const Text('فتح الجدول')),
              FilledButton.tonalIcon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TaskEditor())), icon: const Icon(Icons.add_task), label: const Text('إضافة مهمة')),
              FilledButton.tonalIcon(onPressed: () => tabIndex.value = 3, icon: const Icon(Icons.timer), label: const Text('تشغيل المؤقت')),
              FilledButton.tonalIcon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AlarmEditor())), icon: const Icon(Icons.add_alarm), label: const Text('إضافة منبه')),
            ]),
            sectionTitle(c, 'جدول اليوم — ${dayNames[now.weekday]}'),
            if (evs.isEmpty) panel(c, Text('لا توجد مواعيد لهذا اليوم. أضفها من تبويب الجدول.', style: TextStyle(color: muted(c)))),
            for (final e in evs)
              panel(
                  c,
                  Row(children: [
                    Container(width: 5, height: 34, decoration: BoxDecoration(color: Color(e.subjectId > 0 ? st.subjColor(e.subjectId) : typeColor(e.type).value), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)), Text('${fmtMin(e.start)} - ${fmtMin(e.end)}', style: TextStyle(color: muted(c), fontSize: 12))])),
                    Checkbox(value: st.isDone(e, now), onChanged: (_) => st.toggleDone(e, now)),
                  ]),
                  pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ]);
        },
      );

  Widget _row(BuildContext c, IconData i, String l, String v) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(i, size: 20, color: emerald),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(fontSize: 12, color: muted(c))), Text(v)])),
      ]);
}
