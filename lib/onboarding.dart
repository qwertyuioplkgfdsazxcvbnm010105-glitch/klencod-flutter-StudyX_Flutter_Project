import 'package:flutter/material.dart';
import 'models.dart';
import 'notif.dart';
import 'store.dart';
import 'ui.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;
  static const total = 7;
  final name = TextEditingController();
  final subjects = TextEditingController();
  String stage = 'ثانوي';
  Set<int> schoolDays = {6, 7, 1, 2, 3};
  bool hasSchool = true;
  int schoolStart = 8 * 60, schoolEnd = 14 * 60, transport = 30;
  int wake = 6 * 60, sleep = 22 * 60;
  int studyMin = 50, breakMin = 10;
  bool wakeAlarm = true;

  Future<void> _finish() async {
    final st = Store.I;
    final s = st.s;
    s.set('name', name.text.trim());
    s.set('stage', stage);
    s.set('wake', wake);
    s.set('sleep', sleep);
    s.set('studyMin', studyMin);
    s.set('breakMin', breakMin);
    final hol = [for (final d in weekOrder) if (!schoolDays.contains(d)) d];
    s.set('holidays', hol);
    // مواد
    for (final n in subjects.text.split(RegExp(r'[,،\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      st.subjects.add(Subject(id: st.newId(), name: n, color: palette[st.subjects.length % palette.length]));
    }
    // جدول مبدئي (من المدخلات فقط)
    for (final d in weekOrder) {
      st.events.add(Event(id: st.newId(), title: 'الاستيقاظ', type: 11, day: d, start: wake, end: wake + 30, remind: 0));
      if (hasSchool && schoolDays.contains(d)) {
        st.events.add(Event(id: st.newId(), title: 'المدرسة', type: 0, day: d, start: schoolStart, end: schoolEnd, remind: 30));
        if (transport > 0 && schoolStart - transport > wake + 30) {
          st.events.add(Event(id: st.newId(), title: 'المواصلات', type: 2, day: d, start: schoolStart - transport, end: schoolStart, remind: 0));
        }
      }
      if (sleep >= 18 * 60 && sleep < 1439) {
        st.events.add(Event(id: st.newId(), title: 'النوم', type: 10, day: d, start: sleep, end: 1439, remind: 30));
      }
    }
    if (wakeAlarm) {
      final a = Alarm(id: st.newId(), name: 'استيقاظ', type: 0, hour: wake ~/ 60, minute: wake % 60, days: hasSchool ? schoolDays.toList() : [1, 2, 3, 4, 5, 6, 7], message: 'صباح الخير! يوم جديد ✨');
      st.alarms.add(a);
    }
    s.set('onboarded', true);
    await st.commit();
  }

  Widget _timeBtn(String label, int v, ValueChanged<int> on) => OutlinedButton(
      onPressed: () async {
        final m = await pickMin(context, v);
        if (m != null) setState(() => on(m));
      },
      child: Text('$label: ${fmtMin(v)}'));

  Widget _body(BuildContext c) {
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('أهلًا بك في StudyX 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          gap(6),
          Text('خطوات بسيطة لتجهيز جدولك. كل شيء يمكن تعديله لاحقًا.', style: TextStyle(color: muted(c))),
          gap(20),
          TextField(controller: name, decoration: deco('الاسم الذي تريد ظهوره')),
          gap(16),
          const Text('المرحلة الدراسية'),
          Wrap(spacing: 8, children: [for (final s in ['ابتدائي', 'إعدادي', 'ثانوي', 'جامعي', 'أخرى']) ChoiceChip(label: Text(s), selected: stage == s, onSelected: (_) => setState(() => stage = s))]),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('أيام المدرسة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          gap(12),
          Wrap(spacing: 8, children: [for (final d in weekOrder) FilterChip(label: Text(dayNames[d]!), selected: schoolDays.contains(d), onSelected: (v) => setState(() => v ? schoolDays.add(d) : schoolDays.remove(d)))]),
          gap(8),
          Text('الأيام غير المحددة تُعتبر إجازة، ويمكنك إضافة مراجعة أو اختبار فيها متى شئت.', style: TextStyle(color: muted(c), fontSize: 12)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('لدي مواعيد مدرسة ثابتة'), value: hasSchool, onChanged: (v) => setState(() => hasSchool = v)),
          if (hasSchool) ...[
            Row(children: [Expanded(child: _timeBtn('بداية', schoolStart, (m) => schoolStart = m)), const SizedBox(width: 8), Expanded(child: _timeBtn('نهاية', schoolEnd, (m) => schoolEnd = m))]),
            gap(8),
            Row(children: [
              const Text('وقت المواصلات (دقائق):'),
              IconButton(onPressed: () => setState(() => transport = transport >= 5 ? transport - 5 : 0), icon: const Icon(Icons.remove_circle_outline)),
              Text('$transport'),
              IconButton(onPressed: () => setState(() => transport += 5), icon: const Icon(Icons.add_circle_outline)),
            ]),
            Text('الدروس الخصوصية تضيفها لاحقًا من تبويب الجدول.', style: TextStyle(color: muted(c), fontSize: 12)),
          ],
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('النوم والاستيقاظ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          gap(12),
          _timeBtn('وقت الاستيقاظ', wake, (m) => wake = m),
          gap(8),
          _timeBtn('وقت النوم', sleep, (m) => sleep = m),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('إنشاء منبه استيقاظ'), value: wakeAlarm, onChanged: (v) => setState(() => wakeAlarm = v)),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('المذاكرة والراحة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          gap(12),
          Row(children: [const Text('مدة المذاكرة:'), IconButton(onPressed: () => setState(() => studyMin = studyMin > 10 ? studyMin - 5 : studyMin), icon: const Icon(Icons.remove_circle_outline)), Text('$studyMin د'), IconButton(onPressed: () => setState(() => studyMin += 5), icon: const Icon(Icons.add_circle_outline))]),
          Row(children: [const Text('مدة الراحة:'), IconButton(onPressed: () => setState(() => breakMin = breakMin > 1 ? breakMin - 1 : breakMin), icon: const Icon(Icons.remove_circle_outline)), Text('$breakMin د'), IconButton(onPressed: () => setState(() => breakMin += 1), icon: const Icon(Icons.add_circle_outline))]),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('موادك الدراسية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          gap(12),
          TextField(controller: subjects, maxLines: 4, decoration: deco('اكتب أسماء المواد مفصولة بفاصلة', hint: 'رياضيات، فيزياء، لغة عربية')),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الإشعارات والمنبهات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          gap(12),
          const Text('لتعمل المنبهات والمؤقت والشاشة مقفولة، يحتاج StudyX صلاحية الإشعارات والمنبهات الدقيقة.'),
          gap(12),
          FilledButton.icon(onPressed: () async {
            await Notif.requestPerms();
            final s = await Notif.status();
            if (c.mounted) toast(c, s['notif']! && s['exact']! ? 'تم تفعيل الصلاحيات ✔' : 'بقيت صلاحية ناقصة — يمكنك تفعيلها لاحقًا من الإعدادات');
          }, icon: const Icon(Icons.security), label: const Text('تفعيل الصلاحيات')),
          gap(12),
          Text('نصيحة: اجعل بطارية التطبيق "غير مقيّد" من إعدادات الهاتف لضمان وصول المنبهات.', style: TextStyle(color: muted(c), fontSize: 12)),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('جاهز! 🎉', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          gap(12),
          const Text('سننشئ جدولًا مبدئيًا من المعلومات التي أدخلتها فقط (استيقاظ، مدرسة، مواصلات، نوم) دون فرض مواعيد أخرى، وكله قابل للتعديل.'),
        ]);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text('الإعداد ${step + 1}/$total')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              LinearProgressIndicator(value: (step + 1) / total, minHeight: 6, borderRadius: BorderRadius.circular(6)),
              gap(20),
              Expanded(child: SingleChildScrollView(child: _body(c))),
              Row(children: [
                if (step > 0) OutlinedButton(onPressed: () => setState(() => step--), child: const Text('السابق')),
                const Spacer(),
                FilledButton(
                    onPressed: () async {
                      if (step < total - 1) {
                        setState(() => step++);
                      } else {
                        await _finish();
                      }
                    },
                    child: Text(step < total - 1 ? 'التالي' : 'ابدأ')),
              ]),
            ]),
          ),
        ),
      );
}
