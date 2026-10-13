import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ====== SIRF YE EK LINE BADLNI HAI ======
// Firebase Realtime Database ka URL (README dekhein)
const dbUrl = 'https://YOUR-PROJECT-default-rtdb.firebaseio.com/masjid.json';
// ========================================

const prayers = <(String, String)>[
  ('fajr', 'Fajr'),
  ('zuhr', 'Zuhr'),
  ('asr', 'Asr'),
  ('maghrib', 'Maghrib'),
  ('isha', 'Isha'),
  ('jumma', 'Jumma'),
];

const reminderMinutes = 15;
final notif = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {}
  await notif.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));
  final android = notif.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
  await android?.requestExactAlarmsPermission();
}

Future<void> scheduleAll(Map timings, SharedPreferences sp) async {
  for (var i = 0; i < prayers.length; i++) {
    final (key, label) = prayers[i];
    await notif.cancel(i);
    final t = timings[key] as String?;
    final enabled = sp.getBool('rem_$key') ?? true;
    if (t == null || !enabled || !t.contains(':')) continue;

    final p = t.split(':');
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day,
            int.parse(p[0]), int.parse(p[1]))
        .subtract(const Duration(minutes: reminderMinutes));
    final weekly = key == 'jumma';
    while (when.isBefore(now) || (weekly && when.weekday != DateTime.friday)) {
      when = when.add(const Duration(days: 1));
    }

    await notif.zonedSchedule(
      i,
      '$label ka waqt qareeb hai',
      '$reminderMinutes minute baad $label ki jamaat (${fmt12(t)})',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'namaz_reminder',
          'Namaz Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          weekly ? DateTimeComponents.dayOfWeekAndTime : DateTimeComponents.time,
    );
  }
}

String fmt12(String t) {
  final p = t.split(':');
  final h = int.tryParse(p[0]) ?? 0;
  final m = p.length > 1 ? p[1] : '00';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${h >= 12 ? 'PM' : 'AM'}';
}

Future<Map> loadData() async {
  final sp = await SharedPreferences.getInstance();
  try {
    final r = await http
        .get(Uri.parse(dbUrl))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200 && r.body != 'null') {
      await sp.setString('cache', r.body);
    }
  } catch (_) {}
  final c = sp.getString('cache');
  return c == null ? {} : (jsonDecode(c) as Map);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Masjid Namaz',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1B5E20),
          useMaterial3: true,
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map data = {};
  bool loading = true;
  int tab = 0;
  late SharedPreferences sp;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    sp = await SharedPreferences.getInstance();
    final d = await loadData();
    final timings = (d['timings'] as Map?) ?? {};
    await scheduleAll(timings, sp);
    if (mounted) setState(() { data = d; loading = false; });
  }

  Future<void> toggle(String key, bool v) async {
    await sp.setBool('rem_$key', v);
    await scheduleAll((data['timings'] as Map?) ?? {}, sp);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final name = (data['masjidName'] as String?) ?? 'Masjid';
    return Scaffold(
      appBar: AppBar(title: Text(name), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: refresh,
              child: tab == 0 ? timingsPage() : donationPage(),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time), label: 'Namaz'),
          NavigationDestination(
              icon: Icon(Icons.volunteer_activism), label: 'Donation'),
        ],
      ),
    );
  }

  Widget timingsPage() {
    final timings = (data['timings'] as Map?) ?? {};
    if (timings.isEmpty) {
      return ListView(children: const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Text('Timings abhi available nahi. Internet on karke neeche kheenchein.'),
        )
      ]);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (key, label) in prayers)
          if (timings[key] != null)
            Card(
              child: ListTile(
                title: Text(label,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600)),
                subtitle: Text(fmt12(timings[key]),
                    style: const TextStyle(fontSize: 18)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch(
                      value: sp.getBool('rem_$key') ?? true,
                      onChanged: (v) => toggle(key, v),
                    ),
                    const Text('Reminder', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Har namaz se 15 minute pehle reminder aayega. Switch se on/off karein.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget donationPage() {
    final d = (data['donation'] as Map?) ?? {};
    final raw = d['accounts'];
    final accounts = raw is List
        ? raw.whereType<Map>().toList()
        : raw is Map
            ? raw.values.whereType<Map>().toList()
            : <Map>[];
    final qr = (d['qrText'] as String?) ?? '';
    final note = (d['note'] as String?) ?? '';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Sadqa, Zakat aur Masjid Fund',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(note, textAlign: TextAlign.center),
          ),
        for (final a in accounts)
          Card(
            child: ListTile(
              title: Text('${a['title'] ?? ''}'),
              subtitle: Text('${a['name'] ?? ''}\n${a['number'] ?? ''}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${a['number'] ?? ''}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Number copy ho gaya')));
                },
              ),
            ),
          ),
        if (qr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: qr, size: 220),
              ),
            ),
          ),
        if (accounts.isEmpty && qr.isEmpty)
          const Center(child: Text('Donation details abhi available nahi.')),
      ],
    );
  }
}
