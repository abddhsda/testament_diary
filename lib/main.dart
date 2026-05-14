// ════════════════════════════════════════════════════
// main.dart — точка входа
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/notifications.dart' as notif;
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: контент рисуется под статус-баром и навигацией
  // Flutter сам добавит padding через MediaQuery — bottom nav его учитывает
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  await notif.initNotifications();
  await notif.scheduleNotifications();
  runApp(const MindfulDiaryApp());
}
