import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'notif.dart';
import 'store.dart';
import 'ui.dart';

// ====================== المؤقت ======================
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  Timer? _tk;
  static const kinds = [('study', 'مذاكرة'), ('questions', 'حل أسئلة'), ('review', 'مراجعة'), ('reading', 'قراءة'), ('personal', 'نشاط شخصي')];

  @override
  void initState() {
    super.initState();
    _tk = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tk?.cancel();
    super.dispose();
  }

  String _fmt(int s) => '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';

  @override
  Widget build(BuildContext c) {
    final st = Store.I;
    final t = st.t;
    final rem = st.remainingNow;
    final progress = t.total == 0 ? 0.0 : 1 - rem / t.total;
    final running = t.running;
    final fresh = !running && rem == t.total;
    final every = st.s.i('cycles', 2);
    final today = dayStart(DateTime.now());
    final todaySessions = st.sessionsIn(today, today.add(const Duration(days: 1))).toList().reversed.take(5).toList();
    final openTasks = st.tasks.where((x) => x.status != 2).toList();
    if (st.tasks.every((x) => x.id != t.taskId)) t.taskId = 0;
    if (st.subj(t.subjectId) == null) t.subjectId = 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (st.timerNotice != null)
        panel(c, Row(children: [const Icon(Icons.check_circle, color: emerald), const SizedBox(width: 8), Expanded(child: Text(st.timerNotice!)), IconButton(onPressed: st.clearNotice, icon: const Icon(Icons.close))]), color: emerald.withOpacity(0.15)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final m in const [('study', 'مذاكرة'), ('break', 'راحة قصيرة'), ('long', 'راحة طويلة')])
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(m.$2), selected: t.mode == m.$1, onSelected: running ? null : (_) => st.timerSetMode(m.$1))),
      ]),
      gap(16),
      Center(
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 260, height: 260, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), strokeWidth: 12, strokeCap: StrokeCap.round, backgroundColor: muted(c).withOpacity(0.15))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Directionality(textDirection: TextDirection.ltr, child: Text(_fmt(rem), style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold))),
              Text(t.mode == 'study' ? t.label : 'راحة', style: TextStyle(color: muted(c))),
            ]),
          ]),
        ),
      ),
      gap(8),
      Center(child: Text('جلسات مكتملة: ${t.cycle}  •  راحة طويلة كل $every جلسات', style: TextStyle(color: muted(c), fontSize: 12))),
      gap(12),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: running ? st.timerPause : st.timerStart, icon: Icon(running ? Icons.pause : Icons.play_arrow), label: Text(running ? 'إيقاف مؤقت' : (fresh ? 'ابدأ' : 'استكمال')))),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: st.timerReset, icon: const Icon(Icons.restart_alt), label: const Text('إعادة ضبط')),
      ]),
      if (!fresh || running)
        TextButton.icon(onPressed: () async {
          if (await confirm(c, 'إنهاء الجلسة الآن وحفظ الوقت المنقضي؟')) st.timerFinishEarly();
        }, icon: const Icon(Icons.stop_circle_outlined), label: const Text('إنهاء الجلسة')),
      if (t.mode != 'study') TextButton.icon(onPressed: st.timerSkipBreak, icon: const Icon(Icons.skip_next), label: const Text('تخطي الراحة')),
      if (!running) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(onPressed: () => st.timerSetMinutes((t.total ~/ 60) - 5), icon: const Icon(Icons.remove_circle_outline)),
        TextButton(onPressed: () async {
          final m = await askNumber(c, 'مدة مخصصة بالدقائق', t.total ~/ 60);
          if (m != null && m > 0) st.timerSetMinutes(m);
        }, child: Text('${t.total ~/ 60} دقيقة')),
        IconButton(onPressed: () => st.timerSetMinutes((t.total ~/ 60) + 5), icon: const Icon(Icons.add_circle_outline)),
      ]),
      if (t.mode == 'study') ...[
        sectionTitle(c, 'نوع النشاط'),
        Wrap(spacing: 8, children: [
          for (final k in kinds) ChoiceChip(label: Text(k.$2), selected: t.kind == k.$1, onSelected: running ? null : (_) => st.timerSetKind(k.$1, k.$2)),
        ]),
        gap(12),
        dropField<int>('المادة المرتبطة', t.subjectId, subjectItems(), (v) {
          t.subjectId = v ?? 0;
          st.commit(resched: false);
        }),
        gap(10),
        dropField<int>('المهمة المرتبطة', t.taskId, [const DropdownMenuItem(value: 0, child: Text('بدون مهمة')), for (final x in openTasks) DropdownMenuItem(value: x.id, child: Text(x.title, overflow: TextOverflow.ellipsis))], (v) {
          t.taskId = v ?? 0;
          st.commit(resched: false);
        }),
      ],
      sectionTitle(c, 'جلسات اليوم'),
      if (todaySessions.isEmpty) Text('لا توجد جلسات بعد', style: TextStyle(color: muted(c))),
      for (final x in todaySessions)
        panel(c, Row(children: [Icon(x.kind == 'rest' ? Icons.coffee : Icons.menu_book, color: emerald), const SizedBox(width: 8), Expanded(child: Text('${x.label}${x.subjectId > 0 ? ' • ${st.subjName(x.subjectId)}' : ''}')), Text(durStr(x.seconds))]), pad: const EdgeInsets.all(10)),
      gap(8),
      Text('المؤقت يعتمد على الوقت الحقيقي، ويستمر عند قفل الشاشة أو إغلاق التطبيق، ويصلك إشعار عند الانتهاء.', style: TextStyle(color: muted(c), fontSize: 12)),
    ]);
  }
}

// ====================== المنبهات ======================
class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key});
  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> with WidgetsBindingObserver {
  Map<String, bool> perm = {'notif': true, 'exact': true};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final p = await Notif.status();
    if (mounted) setState(() => perm = p);
  }

  String _repeat(Alarm a) {
    if (a.dateMs > 0) return dateStr(DateTime.fromMillisecondsSinceEpoch(a.dateMs));
    if (a.days.isEmpty) return 'مرة واحدة';
    if (a.days.length == 7) return 'يوميًا';
    return weekOrder.where(a.days.contains).map((d) => dayNames[d]).join('، ');
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final paused = st.s.b('alarmsPaused', false);
        final list = [...st.alarms]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        final na = st.nextAlarm();
        final ok = perm['notif']! && perm['exact']!;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AlarmEditor())), icon: const Icon(Icons.add_alarm), label: const Text('منبه')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
            if (!ok)
              panel(
                  c,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('⚠ المنبهات غير مضمونة حاليًا', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    gap(4),
                    Text([if (!perm['notif']!) 'صلاحية الإشعارات غير مفعّلة.', if (!perm['exact']!) 'صلاحية المنبهات الدقيقة غير مفعّلة.'].join(' '), style: const TextStyle(fontSize: 13)),
                    gap(6),
                    FilledButton(onPressed: () async {
                      await Notif.requestPerms();
                      _load();
                    }, child: const Text('تفعيل الصلاحيات')),
                  ]),
                  color: Colors.orange.withOpacity(0.15)),
            panel(
                c,
                Row(children: [
                  const Icon(Icons.alarm, color: emerald),
                  const SizedBox(width: 8),
                  Expanded(child: Text(paused ? 'جميع المنبهات معطّلة مؤقتًا' : na == null ? 'لا يوجد منبه قادم' : 'أقرب منبه: ${na.key.title}\n${dayNames[na.value.weekday]} ${fmtMin(na.value.hour * 60 + na.value.minute)} (بعد ${durStr(na.value.difference(DateTime.now()).inSeconds)})')),
                ])),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () async {
                await Notif.testAlarm();
                if (c.mounted) toast(c, 'سيرن منبه تجريبي بعد 10 ثوانٍ — اقفل الشاشة لتجربته');
              }, icon: const Icon(Icons.science), label: const Text('تجربة منبه (10 ث)'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () {
                st.s.set('alarmsPaused', !paused);
                st.commit();
              }, icon: Icon(paused ? Icons.play_arrow : Icons.pause), label: Text(paused ? 'تشغيل الكل' : 'تعطيل الكل'))),
            ]),
            gap(10),
            if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('لا توجد منبهات. اضغط "منبه" للإضافة.', style: TextStyle(color: muted(c))))),
            for (final a in list)
              panel(
                  c,
                  Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Directionality(textDirection: TextDirection.ltr, child: Text(fmtMin(a.hour * 60 + a.minute), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: a.enabled ? null : muted(c)))),
                      Text('${a.title} • ${_repeat(a)}', style: TextStyle(color: muted(c), fontSize: 13)),
                      if (a.message.isNotEmpty) Text(a.message, style: TextStyle(color: muted(c), fontSize: 12)),
                    ])),
                    Switch(value: a.enabled, onChanged: (v) {
                      a.enabled = v;
                      if (v && a.days.isEmpty && a.dateMs == 0) a.arm();
                      st.commit();
                    }),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          Navigator.push(c, MaterialPageRoute(builder: (_) => AlarmEditor(edit: a)));
                        } else if (v == 'copy') {
                          final n = Alarm.fromJson(a.toJson())..id = st.newId();
                          st.alarms.add(n);
                          await st.commit();
                        } else if (v == 'del') {
                          if (await confirm(c, 'حذف المنبه؟')) {
                            st.alarms.remove(a);
                            await st.commit();
                          }
                        }
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'copy', child: Text('نسخ')), PopupMenuItem(value: 'del', child: Text('حذف'))],
                    ),
                  ]),
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AlarmEditor(edit: a)))),
          ]),
        );
      });
}

class AlarmEditor extends StatefulWidget {
  final Alarm? edit;
  final int type;
  final int? hour;
  final int? minute;
  const AlarmEditor({super.key, this.edit, this.type = 11, this.hour, this.minute});
  @override
  State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  late TextEditingController name, msg;
  int type = 11, min = 7 * 60, repeat = 0, snooze = 10, sound = 0, taskId = 0;
  bool vibrate = true, skipHol = false;
  Set<int> days = {};
  DateTime? date;

  @override
  void initState() {
    super.initState();
    final a = widget.edit;
    name = TextEditingController(text: a?.name ?? '');
    msg = TextEditingController(text: a?.message ?? '');
    type = a?.type ?? widget.type;
    min = a != null ? a.hour * 60 + a.minute : (widget.hour != null ? widget.hour! * 60 + (widget.minute ?? 0) : 7 * 60);
    if (a != null) {
      snooze = a.snooze;
      sound = a.sound;
      vibrate = a.vibrate;
      skipHol = a.skipHol;
      taskId = a.taskId;
      days = a.days.toSet();
      if (a.dateMs > 0) {
        repeat = 3;
        date = DateTime.fromMillisecondsSinceEpoch(a.dateMs);
      } else if (a.days.isEmpty) {
        repeat = 0;
      } else if (a.days.length == 7) {
        repeat = 1;
      } else {
        repeat = 2;
      }
    }
    if (Store.I.tasks.every((x) => x.id != taskId)) taskId = 0;
  }

  Future<void> _save() async {
    final st = Store.I;
    if (repeat == 2 && days.isEmpty) {
      toast(context, 'اختر يومًا واحدًا على الأقل');
      return;
    }
    if (repeat == 3 && date == null) {
      toast(context, 'اختر التاريخ');
      return;
    }
    final a = widget.edit ?? Alarm(id: st.newId(), hour: 0, minute: 0);
    a.name = name.text.trim();
    a.message = msg.text.trim();
    a.type = type;
    a.hour = min ~/ 60;
    a.minute = min % 60;
    a.snooze = snooze;
    a.sound = sound;
    a.vibrate = vibrate;
    a.skipHol = skipHol;
    a.taskId = taskId;
    a.enabled = true;
    a.dateMs = repeat == 3 ? DateTime(date!.year, date!.month, date!.day).millisecondsSinceEpoch : 0;
    a.days = repeat == 1 ? [1, 2, 3, 4, 5, 6, 7] : repeat == 2 ? days.toList() : [];
    if (repeat == 0) a.arm();
    if (repeat == 3 && a.nextFire(st.holidays) == null) {
      toast(context, 'هذا التاريخ والوقت في الماضي');
      return;
    }
    if (widget.edit == null) st.alarms.add(a);
    await st.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) {
    final st = Store.I;
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'منبه جديد' : 'تعديل المنبه')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
            child: TextButton(
                onPressed: () async {
                  final m = await pickMin(c, min);
                  if (m != null) setState(() => min = m);
                },
                child: Directionality(textDirection: TextDirection.ltr, child: Text(fmtMin(min), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold))))),
        TextField(controller: name, decoration: deco('اسم المنبه', hint: alarmTypes[type])),
        gap(12),
        dropField<int>('نوع المنبه', type, [for (var i = 0; i < alarmTypes.length; i++) DropdownMenuItem(value: i, child: Text(alarmTypes[i]))], (v) => setState(() => type = v ?? 11)),
        gap(12),
        dropField<int>('التكرار', repeat, const [DropdownMenuItem(value: 0, child: Text('مرة واحدة')), DropdownMenuItem(value: 1, child: Text('يوميًا')), DropdownMenuItem(value: 2, child: Text('أيام محددة (أسبوعيًا)')), DropdownMenuItem(value: 3, child: Text('تاريخ محدد'))], (v) => setState(() => repeat = v ?? 0)),
        if (repeat == 2) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, children: [for (final d in weekOrder) FilterChip(label: Text(dayNames[d]!), selected: days.contains(d), onSelected: (v) => setState(() => v ? days.add(d) : days.remove(d)))])),
        if (repeat == 3)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                  onPressed: () async {
                    final d = await pickDate(c, date);
                    if (d != null) setState(() => date = d);
                  },
                  child: Text(date == null ? 'اختر التاريخ' : dateStr(date!)))),
        if (repeat == 1 || repeat == 2) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('إيقاف المنبه في أيام الإجازة'), subtitle: const Text('حسب أيام الإجازة في الإعدادات'), value: skipHol, onChanged: (v) => setState(() => skipHol = v)),
        gap(8),
        TextField(controller: msg, decoration: deco('رسالة تظهر عند التشغيل')),
        gap(12),
        dropField<int>('الغفوة', snooze, [for (final m in [0, 5, 10, 15, 20, 30]) DropdownMenuItem(value: m, child: Text(m == 0 ? 'بدون غفوة' : 'غفوة $m دقيقة'))], (v) => setState(() => snooze = v ?? 10)),
        gap(12),
        dropField<int>('الصوت', sound, const [DropdownMenuItem(value: 0, child: Text('صوت المنبه (واضح)')), DropdownMenuItem(value: 1, child: Text('صوت الإشعار (هادئ)'))], (v) => setState(() => sound = v ?? 0)),
        gap(12),
        dropField<int>('المهمة المرتبطة', taskId, [const DropdownMenuItem(value: 0, child: Text('بدون')), for (final x in st.tasks.where((x) => x.status != 2)) DropdownMenuItem(value: x.id, child: Text(x.title, overflow: TextOverflow.ellipsis))], (v) {
          setState(() => taskId = v ?? 0);
          final tk = st.tasks.where((x) => x.id == taskId);
          if (tk.isNotEmpty && msg.text.isEmpty) msg.text = tk.first.title;
        }),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('الاهتزاز'), value: vibrate, onChanged: (v) => setState(() => vibrate = v)),
        Text('مستوى الصوت يتبع إعدادات صوت المنبهات في هاتفك.', style: TextStyle(color: muted(c), fontSize: 12)),
        gap(16),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
      ]),
    );
  }
}
