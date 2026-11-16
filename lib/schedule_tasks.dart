import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'ui.dart';

// ====================== الجدول ======================
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  int wd = DateTime.now().weekday;

  Future<void> _copyDay(BuildContext c) async {
    final sel = <int>{};
    final ok = await showDialog<bool>(
        context: c,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                  title: const Text('نسخ جدول اليوم إلى'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final d in weekOrder.where((d) => d != wd))
                      CheckboxListTile(
                          value: sel.contains(d),
                          title: Text(dayNames[d]!),
                          onChanged: (v) => set(() {
                                if (v == true) {
                                  sel.add(d);
                                } else {
                                  sel.remove(d);
                                }
                              })),
                    const Text('تنبيه: سيُستبدل جدول الأيام المختارة.', style: TextStyle(fontSize: 12)),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نسخ')),
                  ],
                )));
    if (ok != true || sel.isEmpty) return;
    final st = Store.I;
    final src = st.eventsOn(wd);
    st.events.removeWhere((e) => sel.contains(e.day));
    for (final d in sel) {
      for (final e in src) {
        st.events.add(Event(id: st.newId(), title: e.title, type: e.type, subjectId: e.subjectId, day: d, start: e.start, end: e.end, place: e.place, notes: e.notes, remind: e.remind));
      }
    }
    await st.commit();
    if (c.mounted) toast(c, 'تم نسخ الجدول');
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        final list = st.eventsOn(wd);
        final date = st.dateOfWeekday(wd);
        final isHol = st.holidays.contains(wd);
        final children = <Widget>[];
        for (var i = 0; i < list.length; i++) {
          final e = list[i];
          if (i > 0) {
            final gapMin = e.start - list[i - 1].end;
            if (gapMin >= 15) children.add(Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text('وقت فارغ ${durStr(gapMin * 60)}', style: TextStyle(color: muted(c), fontSize: 12)))));
          }
          final col = Color(e.subjectId > 0 ? st.subjColor(e.subjectId) : typeColor(e.type).value);
          final conf = st.conflicts(e);
          children.add(panel(
              c,
              Row(children: [
                Container(width: 5, height: 48, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('${fmtMin(e.start)} - ${fmtMin(e.end)}  •  ${durStr((e.end - e.start) * 60)}', style: TextStyle(color: muted(c), fontSize: 12)),
                  Text([eventTypes[e.type], if (e.subjectId > 0) st.subjName(e.subjectId), if (e.place.isNotEmpty) e.place].join(' • '), style: TextStyle(color: muted(c), fontSize: 12)),
                  if (conf.isNotEmpty) Text('⚠ تعارض مع: ${conf.map((x) => x.title).join('، ')}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                ])),
                Checkbox(value: st.isDone(e, date), onChanged: (_) => st.toggleDone(e, date)),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      Navigator.push(c, MaterialPageRoute(builder: (_) => EventEditor(edit: e, day: wd)));
                    } else if (v == 'del') {
                      if (await confirm(c, 'حذف "${e.title}"؟')) {
                        st.events.remove(e);
                        await st.commit();
                      }
                    } else if (v == 'copy') {
                      st.events.add(Event(id: st.newId(), title: e.title, type: e.type, subjectId: e.subjectId, day: e.day, start: e.start, end: e.end, place: e.place, notes: e.notes, remind: e.remind));
                      await st.commit();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل / نقل لليوم آخر')),
                    PopupMenuItem(value: 'copy', child: Text('نسخ الموعد')),
                    PopupMenuItem(value: 'del', child: Text('حذف')),
                  ],
                ),
              ]),
              pad: const EdgeInsets.fromLTRB(12, 10, 4, 10)));
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EventEditor(day: wd))), icon: const Icon(Icons.add), label: const Text('موعد')),
          body: Column(children: [
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (final d in weekOrder)
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: ChoiceChip(label: Text(dayNames[d]! + (d == DateTime.now().weekday ? ' •' : '')), selected: wd == d, onSelected: (_) => setState(() => wd = d))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Text('${dateStr(date)}${isHol ? '  (إجازة)' : ''}', style: TextStyle(color: muted(c)))),
                TextButton.icon(onPressed: list.isEmpty ? null : () => _copyDay(c), icon: const Icon(Icons.copy_all, size: 18), label: const Text('نسخ اليوم')),
              ]),
            ),
            Expanded(
                child: list.isEmpty
                    ? Center(child: Text('لا توجد مواعيد في ${dayNames[wd]}.\nاضغط "موعد" لإضافة أول موعد.', textAlign: TextAlign.center, style: TextStyle(color: muted(c))))
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: children)),
          ]),
        );
      });
}

class EventEditor extends StatefulWidget {
  final Event? edit;
  final int day;
  const EventEditor({super.key, this.edit, required this.day});
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late TextEditingController title, place, notes;
  late int type, subjectId, day, start, end, remind;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    title = TextEditingController(text: e?.title ?? '');
    place = TextEditingController(text: e?.place ?? '');
    notes = TextEditingController(text: e?.notes ?? '');
    type = e?.type ?? 3;
    subjectId = e?.subjectId ?? 0;
    day = e?.day ?? widget.day;
    start = e?.start ?? 16 * 60;
    end = e?.end ?? 17 * 60;
    remind = e?.remind ?? 10;
    if (Store.I.subj(subjectId) == null) subjectId = 0;
  }

  Future<void> _save() async {
    final st = Store.I;
    if (title.text.trim().isEmpty) {
      toast(context, 'اكتب اسم الموعد');
      return;
    }
    if (end <= start) {
      toast(context, 'وقت النهاية يجب أن يكون بعد البداية');
      return;
    }
    final ev = Event(id: widget.edit?.id ?? st.newId(), title: title.text.trim(), type: type, subjectId: subjectId, day: day, start: start, end: end, place: place.text.trim(), notes: notes.text.trim(), remind: remind);
    final conf = st.conflicts(ev);
    if (conf.isNotEmpty) {
      final ok = await confirm(context, 'يتعارض مع: ${conf.map((x) => '${x.title} (${fmtMin(x.start)}-${fmtMin(x.end)})').join('، ')}\nهل تريد الحفظ رغم التعارض؟', ok: 'حفظ رغم ذلك');
      if (!ok) return;
    }
    if (widget.edit != null) {
      final i = st.events.indexWhere((x) => x.id == ev.id);
      if (i >= 0) st.events[i] = ev;
    } else {
      st.events.add(ev);
    }
    await st.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(widget.edit == null ? 'موعد جديد' : 'تعديل الموعد')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: title, decoration: deco('اسم المهمة / الموعد')),
          gap(12),
          dropField<int>('النوع', type, [for (var i = 0; i < eventTypes.length; i++) DropdownMenuItem(value: i, child: Text(eventTypes[i]))], (v) => setState(() => type = v ?? 3)),
          gap(12),
          dropField<int>('المادة الدراسية', subjectId, subjectItems(), (v) => setState(() => subjectId = v ?? 0)),
          gap(12),
          dropField<int>('اليوم', day, [for (final d in weekOrder) DropdownMenuItem(value: d, child: Text(dayNames[d]!))], (v) => setState(() => day = v ?? day)),
          gap(12),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () async {
                      final m = await pickMin(c, start);
                      if (m != null) setState(() => start = m);
                    },
                    child: Text('البداية: ${fmtMin(start)}'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    onPressed: () async {
                      final m = await pickMin(c, end);
                      if (m != null) setState(() => end = m);
                    },
                    child: Text('النهاية: ${fmtMin(end)}'))),
          ]),
          if (end > start) Padding(padding: const EdgeInsets.only(top: 6), child: Text('المدة: ${durStr((end - start) * 60)}', style: TextStyle(color: muted(c)))),
          gap(12),
          TextField(controller: place, decoration: deco('المكان (اختياري)')),
          gap(12),
          dropField<int>('التنبيه قبل الموعد', remind, [for (final m in [0, 5, 10, 15, 30, 60]) DropdownMenuItem(value: m, child: Text(m == 0 ? 'عند الموعد' : 'قبل $m دقيقة'))], (v) => setState(() => remind = v ?? 10)),
          gap(12),
          TextField(controller: notes, decoration: deco('ملاحظات'), maxLines: 3),
          gap(8),
          Text('الموعد يتكرر أسبوعيًا في نفس اليوم. للتكرار في أيام أخرى استخدم "نسخ".', style: TextStyle(color: muted(c), fontSize: 12)),
          gap(16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
        ]),
      );
}

// ====================== المهام ======================
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int filter = 0; // 0 all,1 overdue,2 doing,3 done,4 postponed
  static const filters = ['الكل', 'متأخرة', 'قيد التنفيذ', 'مكتملة', 'مؤجلة'];

  Future<void> _resched(BuildContext c, Task t, bool postpone) async {
    final d = await pickDate(c, t.due > 0 ? DateTime.fromMillisecondsSinceEpoch(t.due) : DateTime.now());
    if (d == null || !c.mounted) return;
    final old = t.due > 0 ? DateTime.fromMillisecondsSinceEpoch(t.due) : DateTime(d.year, d.month, d.day, 17);
    var m = old.hour * 60 + old.minute;
    if (!postpone) {
      final p = await pickMin(c, m);
      if (p != null) m = p;
    }
    t.due = DateTime(d.year, d.month, d.day, m ~/ 60, m % 60).millisecondsSinceEpoch;
    t.status = postpone ? 3 : (t.status == 3 ? 0 : t.status);
    await Store.I.commit();
  }

  Future<void> _complete(BuildContext c, Task t) async {
    final min = await askNumber(c, 'كم دقيقة استغرقت فعليًا؟', t.actualMin > 0 ? t.actualMin : t.estMin);
    if (min == null) return;
    await Store.I.completeTask(t, min);
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Store.I,
      builder: (c, _) {
        final st = Store.I;
        var list = st.tasks.where((t) {
          switch (filter) {
            case 1:
              return t.overdue;
            case 2:
              return t.status == 1;
            case 3:
              return t.status == 2;
            case 4:
              return t.status == 3;
            default:
              return true;
          }
        }).toList();
        list.sort((a, b) {
          if ((a.status == 2) != (b.status == 2)) return a.status == 2 ? 1 : -1;
          if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
          if (a.priority != b.priority) return a.priority.compareTo(b.priority);
          return (a.due == 0 ? 1 << 60 : a.due).compareTo(b.due == 0 ? 1 << 60 : b.due);
        });
        final pc = [Colors.redAccent, Colors.orange, Colors.blue, Colors.grey];
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TaskEditor())), icon: const Icon(Icons.add), label: const Text('مهمة')),
          body: Column(children: [
            SizedBox(
                height: 52,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                  for (var i = 0; i < filters.length; i++)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: ChoiceChip(label: Text(filters[i]), selected: filter == i, onSelected: (_) => setState(() => filter = i))),
                ])),
            Expanded(
                child: list.isEmpty
                    ? Center(child: Text('لا توجد مهام هنا', style: TextStyle(color: muted(c))))
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
                        for (final t in list)
                          panel(
                              c,
                              Row(children: [
                                Checkbox(value: t.status == 2, onChanged: (v) async {
                                  if (v == true) {
                                    await _complete(c, t);
                                  } else {
                                    t.status = 0;
                                    t.completedAt = 0;
                                    await st.commit();
                                  }
                                }),
                                Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(t.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, decoration: t.status == 2 ? TextDecoration.lineThrough : null)),
                                  Wrap(spacing: 8, children: [
                                    Text(t.overdue ? 'متأخرة' : taskStatus[t.status], style: TextStyle(fontSize: 12, color: t.overdue ? Colors.redAccent : muted(c))),
                                    Text(priorities[t.priority], style: TextStyle(fontSize: 12, color: pc[t.priority])),
                                    if (t.subjectId > 0) Text(st.subjName(t.subjectId), style: TextStyle(fontSize: 12, color: Color(st.subjColor(t.subjectId)))),
                                    if (t.homework) Text('واجب', style: TextStyle(fontSize: 12, color: muted(c))),
                                  ]),
                                  if (t.due > 0)
                                    Text(() {
                                      final d = DateTime.fromMillisecondsSinceEpoch(t.due);
                                      return 'الاستحقاق: ${dateStr(d)} ${fmtMin(d.hour * 60 + d.minute)}';
                                    }(), style: TextStyle(fontSize: 12, color: muted(c))),
                                  if (t.actualMin > 0) Text('الوقت الفعلي: ${t.actualMin} د', style: TextStyle(fontSize: 12, color: muted(c))),
                                ])),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      Navigator.push(c, MaterialPageRoute(builder: (_) => TaskEditor(edit: t)));
                                    } else if (v == 'doing') {
                                      t.status = 1;
                                      await st.commit();
                                    } else if (v == 'post') {
                                      await _resched(c, t, true);
                                    } else if (v == 'resched') {
                                      await _resched(c, t, false);
                                    } else if (v == 'done') {
                                      await _complete(c, t);
                                    } else if (v == 'del') {
                                      if (await confirm(c, 'حذف المهمة؟')) {
                                        st.tasks.remove(t);
                                        await st.commit();
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'done', child: Text('المهمة انتهت')),
                                    PopupMenuItem(value: 'doing', child: Text('قيد التنفيذ')),
                                    PopupMenuItem(value: 'post', child: Text('تأجيل المهمة')),
                                    PopupMenuItem(value: 'resched', child: Text('إعادة جدولة')),
                                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                    PopupMenuItem(value: 'del', child: Text('حذف')),
                                  ],
                                ),
                              ]),
                              pad: const EdgeInsets.fromLTRB(4, 8, 4, 8)),
                      ])),
          ]),
        );
      });
}

class TaskEditor extends StatefulWidget {
  final Task? edit;
  const TaskEditor({super.key, this.edit});
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late TextEditingController title, desc;
  int subjectId = 0, priority = 2, est = 30, status = 0;
  bool homework = false;
  DateTime? dueDate;
  int dueMin = 17 * 60;

  @override
  void initState() {
    super.initState();
    final t = widget.edit;
    title = TextEditingController(text: t?.title ?? '');
    desc = TextEditingController(text: t?.desc ?? '');
    if (t != null) {
      subjectId = t.subjectId;
      priority = t.priority;
      est = t.estMin;
      status = t.status;
      homework = t.homework;
      if (t.due > 0) {
        final d = DateTime.fromMillisecondsSinceEpoch(t.due);
        dueDate = DateTime(d.year, d.month, d.day);
        dueMin = d.hour * 60 + d.minute;
      }
    }
    if (Store.I.subj(subjectId) == null) subjectId = 0;
  }

  Future<void> _save() async {
    final st = Store.I;
    if (title.text.trim().isEmpty) {
      toast(context, 'اكتب اسم المهمة');
      return;
    }
    final due = dueDate == null ? 0 : DateTime(dueDate!.year, dueDate!.month, dueDate!.day, dueMin ~/ 60, dueMin % 60).millisecondsSinceEpoch;
    final t = widget.edit;
    if (t != null) {
      t.title = title.text.trim();
      t.desc = desc.text.trim();
      t.subjectId = subjectId;
      t.priority = priority;
      t.estMin = est;
      t.status = status;
      t.homework = homework;
      t.due = due;
      if (status == 2 && t.completedAt == 0) t.completedAt = nowMs();
    } else {
      st.tasks.add(Task(id: st.newId(), title: title.text.trim(), desc: desc.text.trim(), subjectId: subjectId, priority: priority, estMin: est, homework: homework, due: due, created: nowMs()));
    }
    await st.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(widget.edit == null ? 'مهمة جديدة' : 'تعديل المهمة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: title, decoration: deco('اسم المهمة')),
          gap(12),
          TextField(controller: desc, decoration: deco('الوصف'), maxLines: 2),
          gap(12),
          dropField<int>('المادة', subjectId, subjectItems(), (v) => setState(() => subjectId = v ?? 0)),
          gap(12),
          dropField<int>('الأولوية', priority, [for (var i = 0; i < 4; i++) DropdownMenuItem(value: i, child: Text(priorities[i]))], (v) => setState(() => priority = v ?? 2)),
          gap(12),
          if (widget.edit != null) ...[dropField<int>('الحالة', status, [for (var i = 0; i < 4; i++) DropdownMenuItem(value: i, child: Text(taskStatus[i]))], (v) => setState(() => status = v ?? 0)), gap(12)],
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () async {
                      final d = await pickDate(c, dueDate);
                      if (d != null) setState(() => dueDate = d);
                    },
                    child: Text(dueDate == null ? 'تاريخ الاستحقاق' : dateStr(dueDate!)))),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: () async {
                  final m = await pickMin(c, dueMin);
                  if (m != null) setState(() => dueMin = m);
                },
                child: Text(fmtMin(dueMin))),
            if (dueDate != null) IconButton(onPressed: () => setState(() => dueDate = null), icon: const Icon(Icons.clear)),
          ]),
          gap(12),
          Row(children: [
            const Text('الوقت المتوقع (دقائق):'),
            IconButton(onPressed: () => setState(() => est = est > 5 ? est - 5 : est), icon: const Icon(Icons.remove_circle_outline)),
            Text('$est'),
            IconButton(onPressed: () => setState(() => est += 5), icon: const Icon(Icons.add_circle_outline)),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('هذه مهمة واجب مدرسي'), value: homework, onChanged: (v) => setState(() => homework = v)),
          gap(8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
        ]),
      );
}
