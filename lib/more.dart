import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'notif.dart';
import 'store.dart';
import 'timer_alarms.dart';
import 'home_shell.dart' show tabIndex;
import 'ui.dart';

// ====================== المواد ======================
Future<void> subjectDialog(BuildContext c, [Subject? sub]) async {
  final name = TextEditingController(text: sub?.name ?? '');
  final teacher = TextEditingController(text: sub?.teacher ?? '');
  var color = sub?.color ?? palette[Store.I.subjects.length % palette.length];
  final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
                title: Text(sub == null ? 'مادة جديدة' : 'تعديل المادة'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: name, decoration: deco('اسم المادة')),
                  gap(10),
                  TextField(controller: teacher, decoration: deco('اسم المدرس (اختياري)')),
                  gap(10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in palette)
                      GestureDetector(onTap: () => set(() => color = p), child: CircleAvatar(radius: 15, backgroundColor: Color(p), child: color == p ? const Icon(Icons.check, size: 16, color: Colors.white) : null)),
                  ]),
                ])),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
              )));
  if (ok != true || name.text.trim().isEmpty) return;
  final st = Store.I;
  if (sub == null) {
    st.subjects.add(Subject(id: st.newId(), name: name.text.trim(), teacher: teacher.text.trim(), color: color));
  } else {
    sub.name = name.text.trim();
    sub.teacher = teacher.text.trim();
    sub.color = color;
  }
  await st.commit(resched: false);
}

class SubjectsPage extends StatelessWidget {
  const SubjectsPage({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        return Scaffold(
          appBar: AppBar(title: const Text('المواد الدراسية')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => subjectDialog(c), icon: const Icon(Icons.add), label: const Text('مادة')),
          body: st.subjects.isEmpty
              ? Center(child: Text('لم تضف مواد بعد', style: TextStyle(color: muted(c))))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final s in st.subjects)
                    panel(
                        c,
                        Row(children: [
                          CircleAvatar(backgroundColor: Color(s.color), radius: 8),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (s.teacher.isNotEmpty) Text(s.teacher, style: TextStyle(color: muted(c), fontSize: 12)),
                            gap(6),
                            LinearProgressIndicator(value: s.progress, color: Color(s.color), minHeight: 6, borderRadius: BorderRadius.circular(6)),
                            Text('${s.doneCount} من ${s.lessons.length} دروس', style: TextStyle(color: muted(c), fontSize: 12)),
                          ])),
                        ]),
                        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SubjectDetail(id: s.id)))),
                ]),
        );
      });
}

class SubjectDetail extends StatelessWidget {
  final int id;
  const SubjectDetail({super.key, required this.id});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final s = st.subj(id);
        if (s == null) return const Scaffold(body: Center(child: Text('تم حذف المادة')));
        final secs = st.sessions.where((x) => x.subjectId == id && st.isStudyKind(x.kind)).fold<int>(0, (a, x) => a + x.seconds);
        final tasks = st.tasks.where((t) => t.subjectId == id).toList();
        final exams = st.exams.where((e) => e.subjectId == id).toList();
        return Scaffold(
          appBar: AppBar(title: Text(s.name), actions: [
            IconButton(onPressed: () => subjectDialog(c, s), icon: const Icon(Icons.edit)),
            IconButton(
                onPressed: () async {
                  if (await confirm(c, 'حذف المادة وكل دروسها؟')) {
                    st.subjects.remove(s);
                    await st.commit(resched: false);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
                icon: const Icon(Icons.delete_outline)),
          ]),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                final t = await askText(c, 'اسم الدرس');
                if (t != null && t.isNotEmpty) {
                  s.lessons.add(Lesson(id: st.newId(), title: t));
                  await st.commit(resched: false);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('درس')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
            panel(c, Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Stat('${s.doneCount}', 'مكتملة'), Stat('${s.lessons.length - s.doneCount}', 'متبقية'), Stat('${(s.progress * 100).round()}%', 'التقدم'), Stat(durStr(secs), 'وقت المذاكرة')])),
            if (tasks.isNotEmpty || exams.isNotEmpty) Text('${tasks.where((t) => t.status != 2).length} مهام مفتوحة • ${exams.length} اختبارات', style: TextStyle(color: muted(c))),
            sectionTitle(c, 'الدروس'),
            if (s.lessons.isEmpty) Text('أضف دروس المادة بزر "درس".', style: TextStyle(color: muted(c))),
            for (final l in s.lessons)
              panel(
                  c,
                  Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${lessonStatus[l.status]} • راجعته ${l.reviews} مرة', style: TextStyle(color: muted(c), fontSize: 12)),
                      if (l.nextReview > 0) Text('المراجعة القادمة: ${dateStr(DateTime.fromMillisecondsSinceEpoch(l.nextReview))}', style: TextStyle(color: muted(c), fontSize: 12)),
                    ])),
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) async {
                        if (v == 9) {
                          s.lessons.remove(l);
                          await st.commit(resched: false);
                        } else if (v == 8) {
                          final t = await askText(c, 'اسم الدرس', initial: l.title);
                          if (t != null && t.isNotEmpty) {
                            l.title = t;
                            await st.commit(resched: false);
                          }
                        } else {
                          await st.setLessonStatus(l, v);
                        }
                      },
                      itemBuilder: (_) => [for (var i = 0; i < 5; i++) PopupMenuItem(value: i, child: Text(lessonStatus[i])), const PopupMenuItem(value: 8, child: Text('تعديل الاسم')), const PopupMenuItem(value: 9, child: Text('حذف'))],
                    ),
                  ]),
                  pad: const EdgeInsets.fromLTRB(14, 8, 4, 8)),
          ]),
        );
      });
}

// ====================== المراجعة ======================
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final due = st.dueLessons();
        final today = dayStart(DateTime.now());
        final revSecs = st.kindSecs('review', today, today.add(const Duration(days: 1)));
        final target = st.s.i('minReview', 20);
        final weekFrom = today.subtract(Duration(days: (today.weekday + 1) % 7));
        return Scaffold(
          appBar: AppBar(title: const Text('المراجعة')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            panel(
                c,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مراجعة اليوم: ${revSecs ~/ 60} من $target دقيقة', style: const TextStyle(fontWeight: FontWeight.bold)),
                  gap(8),
                  LinearProgressIndicator(value: (revSecs / 60 / target).clamp(0.0, 1.0), minHeight: 8, borderRadius: BorderRadius.circular(8)),
                  gap(8),
                  FilledButton.icon(
                      onPressed: () async {
                        if (st.t.running) {
                          toast(c, 'المؤقت يعمل الآن — أنهِ الجلسة الحالية أولًا');
                          return;
                        }
                        st.t.mode = 'study';
                        st.t.kind = 'review';
                        st.t.label = 'مراجعة';
                        await st.timerSetMinutes(target);
                        tabIndex.value = 3;
                        if (c.mounted) Navigator.pop(c);
                      },
                      icon: const Icon(Icons.timer),
                      label: Text('ابدأ مراجعة $target دقيقة')),
                ])),
            sectionTitle(c, 'دروس تحتاج مراجعة الآن (${due.length})'),
            if (due.isEmpty) Text('لا توجد دروس مستحقة للمراجعة 🎉\nأي درس تضعه "تمت المذاكرة" يُجدول للمراجعة تلقائيًا.', style: TextStyle(color: muted(c))),
            for (final e in due)
              panel(
                  c,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${e.key.name} • ${lessonStatus[e.value.status]} • راجعته ${e.value.reviews} مرة', style: TextStyle(color: muted(c), fontSize: 12)),
                    gap(6),
                    Row(children: [
                      FilledButton.tonal(onPressed: () => st.reviewDone(e.value, true), child: const Text('راجعته (متقن)')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => st.reviewDone(e.value, false), child: const Text('يحتاج إعادة')),
                    ]),
                  ])),
            sectionTitle(c, 'المراجعة الأسبوعية — نسبة إنجاز المواد'),
            if (st.subjects.isEmpty) Text('أضف مواد أولًا', style: TextStyle(color: muted(c))),
            for (final s in st.subjects)
              panel(
                  c,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(s.name)), Text('${(s.progress * 100).round()}%')]),
                    gap(4),
                    LinearProgressIndicator(value: s.progress, color: Color(s.color), minHeight: 6, borderRadius: BorderRadius.circular(6)),
                    Text('وقت المذاكرة هذا الأسبوع: ${durStr(st.sessionsIn(weekFrom, today.add(const Duration(days: 1))).where((x) => x.subjectId == s.id && st.isStudyKind(x.kind)).fold<int>(0, (a, x) => a + x.seconds))}', style: TextStyle(color: muted(c), fontSize: 12)),
                  ])),
          ]),
        );
      });
}

// ====================== الاختبارات ======================
class ExamsPage extends StatelessWidget {
  const ExamsPage({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final list = [...st.exams]..sort((a, b) => b.date.compareTo(a.date));
        final scored = st.exams.where((e) => e.pct >= 0).toList();
        final avg = scored.isEmpty ? 0.0 : scored.fold<double>(0, (a, e) => a + e.pct) / scored.length;
        return Scaffold(
          appBar: AppBar(title: const Text('الاختبارات')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ExamEditor())), icon: const Icon(Icons.add), label: const Text('اختبار')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
            panel(c, Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Stat('${st.exams.length}', 'اختبارات'), Stat('${scored.length}', 'تم تصحيحها'), Stat(scored.isEmpty ? '—' : '${avg.round()}%', 'المتوسط')])),
            if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('لا توجد اختبارات', style: TextStyle(color: muted(c))))),
            for (final e in list)
              panel(
                  c,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Text(e.pct < 0 ? 'لم تُدخل الدرجة' : '${e.score.toStringAsFixed(e.score % 1 == 0 ? 0 : 1)}/${e.total}  (${e.pct.round()}%)', style: TextStyle(color: e.pct < 0 ? muted(c) : (e.pct >= 50 ? emerald : Colors.redAccent))),
                    ]),
                    Text('${dateStr(DateTime.fromMillisecondsSinceEpoch(e.date))}${e.subjectId > 0 ? ' • ${st.subjName(e.subjectId)}' : ''}', style: TextStyle(color: muted(c), fontSize: 12)),
                    if (e.pct >= 0) ...[gap(6), LinearProgressIndicator(value: (e.pct / 100).clamp(0.0, 1.0), minHeight: 6, borderRadius: BorderRadius.circular(6))],
                    if (e.mistakes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('الأخطاء: ${e.mistakes}', style: const TextStyle(fontSize: 13))),
                    Row(children: [
                      if (e.mistakes.isNotEmpty)
                        TextButton(
                            onPressed: () async {
                              final tm = DateTime.now().add(const Duration(days: 1));
                              st.tasks.add(Task(id: st.newId(), title: 'مراجعة أخطاء: ${e.title}', subjectId: e.subjectId, created: nowMs(), due: DateTime(tm.year, tm.month, tm.day, 17).millisecondsSinceEpoch, priority: 1, estMin: 30));
                              await st.commit();
                              if (c.mounted) toast(c, 'تمت إضافة مهمة مراجعة الأخطاء لغدٍ 5 م');
                            },
                            child: const Text('جدولة مراجعة الأخطاء')),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ExamEditor(edit: e))), icon: const Icon(Icons.edit)),
                      IconButton(
                          onPressed: () async {
                            if (await confirm(c, 'حذف الاختبار؟')) {
                              st.exams.remove(e);
                              await st.commit(resched: false);
                            }
                          },
                          icon: const Icon(Icons.delete_outline)),
                    ]),
                  ])),
          ]),
        );
      });
}

class ExamEditor extends StatefulWidget {
  final Exam? edit;
  const ExamEditor({super.key, this.edit});
  @override
  State<ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends State<ExamEditor> {
  late TextEditingController title, total, score, chapters, mistakes, notes;
  int subjectId = 0;
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    title = TextEditingController(text: e?.title ?? '');
    total = TextEditingController(text: '${e?.total ?? 100}');
    score = TextEditingController(text: e == null || e.score < 0 ? '' : '${e.score}');
    chapters = TextEditingController(text: e?.chapters ?? '');
    mistakes = TextEditingController(text: e?.mistakes ?? '');
    notes = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      subjectId = e.subjectId;
      date = DateTime.fromMillisecondsSinceEpoch(e.date);
    }
    if (Store.I.subj(subjectId) == null) subjectId = 0;
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      toast(context, 'اكتب اسم الاختبار');
      return;
    }
    final st = Store.I;
    final e = widget.edit ?? Exam(id: st.newId(), title: '', date: 0);
    e.title = title.text.trim();
    e.subjectId = subjectId;
    e.date = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    e.total = int.tryParse(total.text.trim()) ?? 100;
    e.score = double.tryParse(score.text.trim()) ?? -1;
    e.chapters = chapters.text.trim();
    e.mistakes = mistakes.text.trim();
    e.notes = notes.text.trim();
    if (widget.edit == null) st.exams.add(e);
    await st.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(widget.edit == null ? 'اختبار جديد' : 'تعديل الاختبار')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: title, decoration: deco('اسم الاختبار')),
          gap(12),
          dropField<int>('المادة', subjectId, subjectItems(), (v) => setState(() => subjectId = v ?? 0)),
          gap(12),
          OutlinedButton(
              onPressed: () async {
                final d = await pickDate(c, date);
                if (d != null) setState(() => date = d);
              },
              child: Text('التاريخ: ${dateStr(date)}')),
          gap(12),
          Row(children: [
            Expanded(child: TextField(controller: total, keyboardType: TextInputType.number, decoration: deco('الدرجة النهائية'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: score, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('درجتي'))),
          ]),
          gap(12),
          TextField(controller: chapters, decoration: deco('الفصول الداخلة')),
          gap(12),
          TextField(controller: mistakes, decoration: deco('الأخطاء / نقاط الضعف'), maxLines: 3),
          gap(12),
          TextField(controller: notes, decoration: deco('ملاحظات'), maxLines: 2),
          gap(16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
        ]),
      );
}

// ====================== الإحصائيات ======================
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int range = 1; // 0 day,1 week,2 month
  @override
  Widget build(BuildContext c) {
    final st = Store.I;
    final now = DateTime.now();
    final today = dayStart(now);
    final to = today.add(const Duration(days: 1));
    final from = range == 0 ? today : range == 1 ? today.subtract(const Duration(days: 6)) : DateTime(today.year, today.month, 1);
    final ss = st.sessionsIn(from, to).toList();
    final study = ss.where((x) => st.isStudyKind(x.kind)).toList();
    final totalSecs = study.fold<int>(0, (a, x) => a + x.seconds);
    final avg = study.isEmpty ? 0 : totalSecs ~/ study.length;
    final done = st.tasks.where((t) => t.status == 2 && t.completedAt >= from.millisecondsSinceEpoch && t.completedAt < to.millisecondsSinceEpoch).toList();
    final hwDone = done.where((t) => t.homework).length;
    final perSubj = <int, int>{};
    for (final x in study) {
      perSubj[x.subjectId] = (perSubj[x.subjectId] ?? 0) + x.seconds;
    }
    final entries = perSubj.entries.where((e) => e.key > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final least = st.subjects.where((s) => !perSubj.containsKey(s.id)).map((s) => s.name).toList();
    final scored = st.exams.where((e) => e.pct >= 0).toList();
    final avgExam = scored.isEmpty ? '—' : '${(scored.fold<double>(0, (a, e) => a + e.pct) / scored.length).round()}%';
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final vals = [for (final d in days) st.studySecs(d, d.add(const Duration(days: 1))) / 60];
    final mx = vals.fold<double>(1, (a, b) => b > a ? b : a);
    final cmp = st.compliance(from, today);
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات والتقارير')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('يومي')), ButtonSegment(value: 1, label: Text('أسبوعي')), ButtonSegment(value: 2, label: Text('شهري'))], selected: {range}, onSelectionChanged: (s) => setState(() => range = s.first)),
        gap(12),
        panel(c, Wrap(alignment: WrapAlignment.spaceAround, runSpacing: 14, spacing: 18, children: [
          Stat(durStr(totalSecs), 'إجمالي المذاكرة'),
          Stat('${study.length}', 'جلسات التركيز'),
          Stat(durStr(avg), 'متوسط الجلسة'),
          Stat('${done.length}', 'مهام مكتملة'),
          Stat('${st.overdueTasks.length}', 'مهام متأخرة'),
          Stat('${(cmp * 100).round()}%', 'الالتزام بالجدول'),
          Stat(durStr(st.kindSecs('review', from, to)), 'وقت المراجعة'),
          Stat('$hwDone', 'واجبات مكتملة'),
          Stat('${st.exams.length}', 'عدد الاختبارات'),
          Stat(avgExam, 'متوسط الاختبارات'),
        ])),
        sectionTitle(c, 'آخر 7 أيام (دقائق مذاكرة)'),
        panel(
            c,
            SizedBox(
              height: 140,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                for (var i = 0; i < 7; i++)
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${vals[i].round()}', style: const TextStyle(fontSize: 11)),
                    Container(width: 26, height: 100 * (vals[i] / mx) + 2, decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(6))),
                    Text(dayShort[days[i].weekday]!, style: TextStyle(fontSize: 12, color: muted(c))),
                  ]),
              ]),
            )),
        sectionTitle(c, 'المواد (حسب وقت المذاكرة)'),
        if (entries.isEmpty) Text('لا توجد جلسات مرتبطة بمواد في هذه الفترة', style: TextStyle(color: muted(c))),
        for (final e in entries) panel(c, Row(children: [CircleAvatar(radius: 6, backgroundColor: Color(st.subjColor(e.key))), const SizedBox(width: 8), Expanded(child: Text(st.subjName(e.key))), Text(durStr(e.value))]), pad: const EdgeInsets.all(10)),
        if (entries.isNotEmpty) Text('الأكثر مذاكرة: ${st.subjName(entries.first.key)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (least.isNotEmpty) Text('بدون مذاكرة في الفترة: ${least.join('، ')}', style: TextStyle(color: muted(c))),
        sectionTitle(c, 'السجلات'),
        ExpansionTile(title: const Text('سجل جلسات المذاكرة'), children: [
          for (final x in st.sessions.reversed.take(30))
            ListTile(dense: true, title: Text('${x.label}${x.subjectId > 0 ? ' • ${st.subjName(x.subjectId)}' : ''}'), subtitle: Text(() {
              final d = DateTime.fromMillisecondsSinceEpoch(x.start);
              return '${dateStr(d)} ${fmtMin(d.hour * 60 + d.minute)}';
            }()), trailing: Text(durStr(x.seconds))),
          if (st.sessions.isEmpty) const ListTile(dense: true, title: Text('لا توجد جلسات')),
        ]),
        ExpansionTile(title: const Text('سجل المهام المكتملة'), children: [
          for (final t in (st.tasks.where((t) => t.status == 2).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt))).take(30))
            ListTile(dense: true, title: Text(t.title), subtitle: Text(dateStr(DateTime.fromMillisecondsSinceEpoch(t.completedAt))), trailing: Text('${t.actualMin} د')),
          if (st.tasks.every((t) => t.status != 2)) const ListTile(dense: true, title: Text('لا توجد مهام مكتملة')),
        ]),
        ExpansionTile(title: const Text('سجل المنبهات'), children: [
          for (final a in st.alarms) ListTile(dense: true, title: Text(a.title), subtitle: Text(fmtMin(a.hour * 60 + a.minute)), trailing: Text(a.enabled ? 'مفعّل' : 'متوقف')),
          if (st.alarms.isEmpty) const ListTile(dense: true, title: Text('لا توجد منبهات')),
        ]),
      ]),
    );
  }
}

// ====================== التقويم الشهري ======================
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext c) {
    final st = Store.I;
    final first = month;
    final dim = DateTime(month.year, month.month + 1, 0).day;
    final offset = (first.weekday + 1) % 7;
    final today = dayStart(DateTime.now());
    final cmp = st.compliance(first, DateTime(month.year, month.month, dim).isAfter(today) ? today : DateTime(month.year, month.month, dim));
    final cells = <Widget>[];
    for (final d in weekOrder) {
      cells.add(Center(child: Text(dayShort[d]!, style: TextStyle(color: muted(c), fontWeight: FontWeight.bold))));
    }
    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= dim; day++) {
      final d = DateTime(month.year, month.month, day);
      final ex = st.exams.where((e) => sameDay(e.date, d)).length;
      final tk = st.tasks.where((t) => sameDay(t.due, d) && t.status != 2).length;
      final evs = st.eventsOn(d.weekday).length;
      final hol = st.holidays.contains(d.weekday);
      final busy = evs + tk >= 6;
      cells.add(GestureDetector(
        onTap: () => _sheet(c, d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: d == today ? emerald.withOpacity(0.25) : hol ? muted(c).withOpacity(0.08) : cardColor(c), borderRadius: BorderRadius.circular(10), border: busy ? Border.all(color: Colors.orange) : null),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(fontWeight: d == today ? FontWeight.bold : FontWeight.normal)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (ex > 0) const Icon(Icons.circle, size: 7, color: Colors.redAccent),
              if (tk > 0) const Icon(Icons.circle, size: 7, color: Colors.amber),
            ]),
          ]),
        ),
      ));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الشهري')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_right)),
          Expanded(child: Center(child: Text('${monthNames[month.month - 1]} ${month.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_left)),
        ]),
        GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.95, children: cells),
        gap(8),
        Row(children: const [Icon(Icons.circle, size: 9, color: Colors.redAccent), Text(' اختبار   '), Icon(Icons.circle, size: 9, color: Colors.amber), Text(' موعد تسليم/مهمة   '), Text('إطار برتقالي = يوم مزدحم')]),
        gap(8),
        panel(c, Text('الالتزام بالجدول هذا الشهر (حتى اليوم): ${(cmp * 100).round()}%')),
      ]),
    );
  }

  void _sheet(BuildContext c, DateTime d) {
    final st = Store.I;
    final ex = st.exams.where((e) => sameDay(e.date, d)).toList();
    final tk = st.tasks.where((t) => sameDay(t.due, d)).toList();
    final ev = st.eventsOn(d.weekday);
    showModalBottomSheet(
        context: c,
        builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [
              Text(dateStr(d), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (st.holidays.contains(d.weekday)) const Text('إجازة'),
              if (ex.isNotEmpty) sectionTitle(c, 'اختبارات'),
              for (final e in ex) ListTile(dense: true, title: Text(e.title)),
              if (tk.isNotEmpty) sectionTitle(c, 'مهام / تسليم'),
              for (final t in tk) ListTile(dense: true, title: Text(t.title), trailing: Text(taskStatus[t.status])),
              if (ev.isNotEmpty) sectionTitle(c, 'مواعيد الجدول'),
              for (final e in ev) ListTile(dense: true, title: Text(e.title), trailing: Text(fmtMin(e.start))),
              if (ex.isEmpty && tk.isEmpty && ev.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا شيء في هذا اليوم')),
            ]));
  }
}

// ====================== النوم والراحة ======================
class SleepPage extends StatelessWidget {
  const SleepPage({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final wake = st.s.i('wake', 6 * 60), sleep = st.s.i('sleep', 22 * 60);
        final dur = (wake - sleep + 1440) % 1440;
        final today = dayStart(DateTime.now());
        final rest = st.kindSecs('rest', today, today.add(const Duration(days: 1)));
        final conflicts = st.events.where((e) => e.type != 10 && e.type != 11 && (sleep > wake ? (e.end > sleep || e.start < wake) : (e.start < wake && e.end > sleep))).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('النوم والراحة')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            panel(
                c,
                Column(children: [
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () async {
                              final m = await pickMin(c, sleep);
                              if (m != null) {
                                st.s.set('sleep', m);
                                await st.commit();
                              }
                            },
                            child: Text('وقت النوم: ${fmtMin(sleep)}'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () async {
                              final m = await pickMin(c, wake);
                              if (m != null) {
                                st.s.set('wake', m);
                                await st.commit();
                              }
                            },
                            child: Text('الاستيقاظ: ${fmtMin(wake)}'))),
                  ]),
                  gap(10),
                  Text('مدة النوم: ${dur ~/ 60} ساعة ${dur % 60 == 0 ? '' : 'و${dur % 60} دقيقة'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(dur < 7 * 60 ? 'أقل من 7 ساعات — حاول تبكّر في النوم' : 'مدة نوم جيدة 👍', style: TextStyle(color: muted(c))),
                ])),
            FilledButton.icon(
                onPressed: () {
                  Navigator.push(c, MaterialPageRoute(builder: (_) => AlarmEditor(type: 0, hour: wake ~/ 60, minute: wake % 60)));
                },
                icon: const Icon(Icons.alarm_add),
                label: const Text('إنشاء منبه استيقاظ')),
            gap(8),
            SwitchListTile(title: const Text('تذكير قبل النوم بـ 30 دقيقة'), value: st.s.b('sleepRem', false), onChanged: (v) {
              st.s.set('sleepRem', v);
              st.commit();
            }),
            if (conflicts.isNotEmpty) panel(c, Text('⚠ مواعيد تتعارض مع وقت النوم: ${conflicts.map((e) => '${e.title} (${dayNames[e.day]})').join('، ')}'), color: Colors.orange.withOpacity(0.15)),
            sectionTitle(c, 'الراحة اليوم'),
            panel(c, Row(children: [const Icon(Icons.coffee, color: emerald), const SizedBox(width: 8), Expanded(child: Text('وقت الراحة المسجّل: ${durStr(rest)}')), TextButton(onPressed: () async {
              final m = await askNumber(c, 'كم دقيقة استرحت؟', 15);
              if (m != null && m > 0) {
                st.sessions.add(Session(start: nowMs(), seconds: m * 60, kind: 'rest', label: 'راحة'));
                await st.commit(resched: false);
              }
            }, child: const Text('تسجيل'))])),
            Text('StudyX لا يلغي أوقات الراحة ولا يضع جدولًا يضغط عليك. جدول مواعيد الراحة والطعام من تبويب الجدول (نوع: راحة / تناول الطعام).', style: TextStyle(color: muted(c), fontSize: 12)),
          ]),
        );
      });
}

// ====================== مركز الإشعارات ======================
class NotifCenterPage extends StatefulWidget {
  const NotifCenterPage({super.key});
  @override
  State<NotifCenterPage> createState() => _NotifCenterPageState();
}

class _NotifCenterPageState extends State<NotifCenterPage> {
  late Future<List<dynamic>> fut = Notif.pending();
  Widget _sw(String label, String key, bool def) => SwitchListTile(
      title: Text(label),
      value: Store.I.s.b(key, def),
      onChanged: (v) async {
        Store.I.s.set(key, v);
        await Store.I.commit();
        setState(() => fut = Notif.pending());
      });

  @override
  Widget build(BuildContext c) {
    final st = Store.I;
    return Scaffold(
      appBar: AppBar(title: const Text('مركز الإشعارات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        sectionTitle(c, 'أنواع الإشعارات'),
        _sw('تذكير بالمواعيد قبل بدئها', 'nEvents', true),
        _sw('اقتراب تسليم الواجبات والمهام', 'nTasks', true),
        _sw('تذكير المراجعة اليومية', 'nReview', true),
        _sw('ملخص نهاية اليوم (9 م)', 'nSummary', true),
        _sw('تفعيل عدم الإزعاج للتذكيرات', 'dndOn', false),
        if (st.s.b('dndOn', false))
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async {
              final m = await pickMin(c, st.s.i('dndStart', 23 * 60));
              if (m != null) {
                st.s.set('dndStart', m);
                await st.commit();
              }
            }, child: Text('من ${fmtMin(st.s.i('dndStart', 23 * 60))}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () async {
              final m = await pickMin(c, st.s.i('dndEnd', 6 * 60));
              if (m != null) {
                st.s.set('dndEnd', m);
                await st.commit();
              }
            }, child: Text('إلى ${fmtMin(st.s.i('dndEnd', 6 * 60))}'))),
          ]),
        const Text('المنبهات والمؤقت لا تتأثر بعدم الإزعاج.', style: TextStyle(fontSize: 12)),
        sectionTitle(c, 'الإشعارات المجدولة حاليًا'),
        FutureBuilder<List<dynamic>>(
            future: fut,
            builder: (c, snap) {
              final l = (snap.data ?? []);
              if (l.isEmpty) return Text('لا توجد إشعارات مجدولة', style: TextStyle(color: muted(c)));
              return Column(children: [for (final p in l) ListTile(dense: true, leading: const Icon(Icons.notifications_active, size: 20), title: Text('${p.title ?? ''}'), subtitle: Text('${p.body ?? ''}'))]);
            }),
        TextButton.icon(onPressed: () => setState(() => fut = Notif.pending()), icon: const Icon(Icons.refresh), label: const Text('تحديث')),
      ]),
    );
  }
}

// ====================== النسخ الاحتياطي ======================
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final ctl = TextEditingController();
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('البيانات محفوظة محليًا على هاتفك ولا تُرفع لأي مكان. للنقل بين الأجهزة أو الحفظ الاحتياطي: انسخ النص وخزّنه (ملاحظات/واتساب لنفسك) ثم الصقه هنا للاستعادة.'),
          gap(12),
          FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: Store.I.exportJson()));
                if (c.mounted) toast(c, 'تم نسخ النسخة الاحتياطية إلى الحافظة');
              },
              icon: const Icon(Icons.copy),
              label: const Text('نسخ نسخة احتياطية (تصدير)')),
          gap(16),
          TextField(controller: ctl, maxLines: 6, decoration: deco('الصق النسخة الاحتياطية هنا')),
          gap(8),
          OutlinedButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) ctl.text = data!.text!;
              },
              icon: const Icon(Icons.paste),
              label: const Text('لصق من الحافظة')),
          gap(8),
          FilledButton.tonalIcon(
              onPressed: () async {
                if (ctl.text.trim().isEmpty) return;
                if (!await confirm(c, 'سيتم استبدال كل بياناتك الحالية بالنسخة الملصقة. متابعة؟')) return;
                final ok = await Store.I.importJson(ctl.text.trim());
                if (c.mounted) toast(c, ok ? 'تمت الاستعادة بنجاح' : 'النص غير صالح');
              },
              icon: const Icon(Icons.restore),
              label: const Text('استعادة (استيراد)')),
          gap(24),
          OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () async {
                if (await confirm(c, 'حذف كل بياناتك نهائيًا؟ لا يمكن التراجع.', ok: 'حذف الكل')) {
                  await Store.I.resetAll();
                  if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst);
                }
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('حذف كل البيانات')),
        ]),
      );
}

// ====================== الإعدادات ======================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _step(String label, String key, int def, int min, int max, {int step = 5, String unit = 'د'}) {
    final st = Store.I;
    final v = st.s.i(key, def);
    return ListTile(
      title: Text(label),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: v - step >= min ? () { st.s.set(key, v - step); st.commit(); } : null, icon: const Icon(Icons.remove_circle_outline)),
        Text('$v $unit'),
        IconButton(onPressed: v + step <= max ? () { st.s.set(key, v + step); st.commit(); } : null, icon: const Icon(Icons.add_circle_outline)),
      ]),
    );
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final hol = st.holidays;
        return Scaffold(
          appBar: AppBar(title: const Text('الإعدادات')),
          body: ListView(padding: const EdgeInsets.all(8), children: [
            sectionTitle(c, 'عام'),
            ListTile(title: const Text('الاسم'), subtitle: Text(st.s.s('name').isEmpty ? 'غير محدد' : st.s.s('name')), onTap: () async {
              final t = await askText(c, 'الاسم', initial: st.s.s('name'));
              if (t != null) {
                st.s.set('name', t);
                await st.commit(resched: false);
              }
            }),
            SwitchListTile(title: const Text('نظام 24 ساعة'), value: st.s.b('use24', false), onChanged: (v) {
              st.s.set('use24', v);
              st.commit();
            }),
            const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('المظهر')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SegmentedButton<int>(showSelectedIcon: false, segments: const [ButtonSegment(value: 0, label: Text('النظام')), ButtonSegment(value: 1, label: Text('فاتح')), ButtonSegment(value: 2, label: Text('داكن'))], selected: {st.s.i('theme', 2)}, onSelectionChanged: (s) {
              st.s.set('theme', s.first);
              st.commit(resched: false);
            })),
            ListTile(title: Text('حجم الخط (${(st.s.f('font', 1.0) * 100).round()}%)'), subtitle: Slider(min: 0.8, max: 1.5, divisions: 7, value: st.s.f('font', 1.0).clamp(0.8, 1.5), onChanged: (v) {
              st.s.set('font', double.parse(v.toStringAsFixed(2)));
              st.commit(resched: false);
            })),
            sectionTitle(c, 'الدراسة'),
            _step('مدة المذاكرة', 'studyMin', 50, 5, 180),
            _step('الراحة القصيرة', 'breakMin', 10, 1, 60, step: 1),
            _step('الراحة الطويلة', 'longMin', 30, 5, 90),
            _step('جلسات قبل الراحة الطويلة', 'cycles', 2, 1, 8, step: 1, unit: ''),
            _step('الحد الأدنى للمراجعة اليومية', 'minReview', 20, 5, 120),
            SwitchListTile(title: const Text('بدء الراحة تلقائيًا بعد المذاكرة'), value: st.s.b('autoBreak', true), onChanged: (v) {
              st.s.set('autoBreak', v);
              st.commit(resched: false);
            }),
            sectionTitle(c, 'أيام الإجازة (والجمعة قابلة للتخصيص)'),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 6, children: [
              for (final d in weekOrder)
                FilterChip(label: Text(dayNames[d]!), selected: hol.contains(d), onSelected: (v) {
                  final n = [...hol];
                  v ? n.add(d) : n.remove(d);
                  st.s.set('holidays', n);
                  st.commit();
                }),
            ])),
            SwitchListTile(title: const Text('إيقاف تنبيهات مواعيد الجدول في أيام الإجازة'), value: st.s.b('muteHol', false), onChanged: (v) {
              st.s.set('muteHol', v);
              st.commit();
            }),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('اليوم المحدد كإجازة لا يُفترض خلوّه من الدراسة: أنت من يضيف له مراجعة أو اختبارًا أسبوعيًا من الجدول.', style: TextStyle(fontSize: 12))),
            sectionTitle(c, 'المنبهات والصلاحيات'),
            ListTile(leading: const Icon(Icons.security), title: const Text('تفعيل صلاحيات الإشعارات والمنبهات'), onTap: () async {
              await Notif.requestPerms();
              final s = await Notif.status();
              if (c.mounted) toast(c, s['notif']! && s['exact']! ? 'الصلاحيات مفعّلة ✔' : 'ما زالت صلاحية ناقصة — فعّلها من إعدادات التطبيق');
            }),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('لأفضل موثوقية: من إعدادات الهاتف > التطبيقات > StudyX > البطارية اختر "غير مقيّد" (Unrestricted)، وفعّل "الإشعارات" و"المنبهات والتذكيرات".', style: TextStyle(fontSize: 12))),
            gap(24),
          ]),
        );
      });
}
