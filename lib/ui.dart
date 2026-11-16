import 'dart:async';
import 'package:flutter/material.dart';
import 'store.dart';

const emerald = Color(0xFF10B981);
bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color cardColor(BuildContext c) => isDark(c) ? const Color(0xFF151515) : Colors.white;
Color muted(BuildContext c) => isDark(c) ? Colors.white60 : Colors.black54;

ThemeData buildTheme(bool dark) {
  final primary = dark ? emerald : const Color(0xFF047857);
  final cs = ColorScheme.fromSeed(seedColor: emerald, brightness: dark ? Brightness.dark : Brightness.light).copyWith(primary: primary, onPrimary: dark ? Colors.black : Colors.white);
  final bg = dark ? Colors.black : const Color(0xFFF3F6F5);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(backgroundColor: bg, elevation: 0, centerTitle: true),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: dark ? const Color(0xFF0E0E0E) : Colors.white, indicatorColor: primary.withOpacity(0.25)),
  );
}

InputDecoration deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: const OutlineInputBorder(), isDense: true);

Widget panel(BuildContext c, Widget child, {VoidCallback? onTap, EdgeInsets pad = const EdgeInsets.all(14), Color? color, EdgeInsets margin = const EdgeInsets.only(bottom: 10)}) => Container(
      margin: margin,
      decoration: BoxDecoration(color: color ?? cardColor(c), borderRadius: BorderRadius.circular(18)),
      child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: pad, child: child))),
    );

Widget gap([double h = 10]) => SizedBox(height: h);

Widget sectionTitle(BuildContext c, String t) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(c).colorScheme.primary)));

Widget dropField<T>(String label, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => InputDecorator(
      decoration: deco(label),
      child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, isExpanded: true, isDense: true, items: items, onChanged: onChanged)),
    );

List<DropdownMenuItem<int>> subjectItems({bool none = true}) => [
      if (none) const DropdownMenuItem(value: 0, child: Text('بدون مادة')),
      for (final s in Store.I.subjects) DropdownMenuItem(value: s.id, child: Text(s.name)),
    ];

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext c, String msg, {String ok = 'نعم'}) async {
  final r = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(content: Text(msg), actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
          ]));
  return r ?? false;
}

Future<String?> askText(BuildContext c, String title, {String initial = '', String? hint}) async {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
      context: c,
      builder: (ctx) => AlertDialog(title: Text(title), content: TextField(controller: ctl, autofocus: true, decoration: deco('', hint: hint)), actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('حفظ')),
          ]));
}

Future<int?> askNumber(BuildContext c, String title, int initial) async {
  final ctl = TextEditingController(text: '$initial');
  return showDialog<int>(
      context: c,
      builder: (ctx) => AlertDialog(title: Text(title), content: TextField(controller: ctl, autofocus: true, keyboardType: TextInputType.number, decoration: deco('')), actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())), child: const Text('حفظ')),
          ]));
}

Future<int?> pickMin(BuildContext c, int init) async {
  final t = await showTimePicker(context: c, initialTime: TimeOfDay(hour: (init ~/ 60) % 24, minute: init % 60));
  return t == null ? null : t.hour * 60 + t.minute;
}

Future<DateTime?> pickDate(BuildContext c, [DateTime? init]) => showDatePicker(context: c, initialDate: init ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));

class ClockText extends StatefulWidget {
  final double size;
  const ClockText({super.key, this.size = 40});
  @override
  State<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<ClockText> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final use24 = Store.I.s.b('use24', false);
    String txt;
    if (use24) {
      txt = '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
    } else {
      var h = n.hour % 12;
      if (h == 0) h = 12;
      txt = '$h:${two(n.minute)}:${two(n.second)} ${n.hour < 12 ? 'ص' : 'م'}';
    }
    return Directionality(textDirection: TextDirection.ltr, child: Text(txt, style: TextStyle(fontSize: widget.size, fontWeight: FontWeight.w700)));
  }
}

class Stat extends StatelessWidget {
  final String value;
  final String label;
  const Stat(this.value, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: muted(context)), textAlign: TextAlign.center),
      ]);
}

Color typeColor(int type) => Color(palette2[type % palette2.length]);
const palette2 = [0xFF3B82F6, 0xFF8B5CF6, 0xFFF59E0B, 0xFF10B981, 0xFF14B8A6, 0xFFEC4899, 0xFFEF4444, 0xFF84CC16, 0xFFF97316, 0xFF06B6D4, 0xFF6366F1, 0xFFEAB308, 0xFF64748B];
