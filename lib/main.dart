// ════════════════════════════════════════════════════
// main.dart — точка входа
// Только инициализация + запуск приложения
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'notifications.dart' as notif;
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notif.initNotifications();
  await notif.scheduleNotifications();
  runApp(const MindfulDiaryApp());
}
