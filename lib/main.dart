import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_shell.dart';
import 'notif.dart';
import 'onboarding.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.init();
  await Notif.init();
  runApp(const StudyXApp());
}

class StudyXApp extends StatefulWidget {
  const StudyXApp({super.key});
  @override
  State<StudyXApp> createState() => _StudyXAppState();
}

class _StudyXAppState extends State<StudyXApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.I.onResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Store.I.onResume();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.I,
        builder: (c, _) {
          final s = Store.I.s;
          final tm = s.i('theme', 2);
          return MaterialApp(
            title: 'StudyX',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(false),
            darkTheme: buildTheme(true),
            themeMode: tm == 0 ? ThemeMode.system : tm == 1 ? ThemeMode.light : ThemeMode.dark,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(s.f('font', 1.0))), child: child!),
            home: const Gate(),
          );
        },
      );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool splash = true;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (splash) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.auto_stories, size: 56, color: Colors.black),
            ),
            const SizedBox(height: 18),
            const Text('StudyX', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('نظّم وقتك، تابع إنجازك', style: TextStyle(color: Colors.white60)),
          ]),
        ),
      );
    }
    return Store.I.s.b('onboarded', false) ? const MainShell() : const OnboardingPage();
  }
}