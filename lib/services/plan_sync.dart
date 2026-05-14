// ════════════════════════════════════════════════════
// services/plan_sync.dart — синхронизация планов
//
// Проблема: AddPlanActivity (нативный) пишет план в
//   'flutter.plans' и 'plans' одновременно.
// Flutter при следующем _save() затирает 'flutter.plans'
//   своими данными, если не смёржил виджетные данные.
//
// Решение: при загрузке в HomeScreen вызвать mergePlans()
//   которая объединит данные из обоих ключей.
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Мёржит планы из 'plans' (нативный ключ виджета) в 'flutter.plans'.
/// Добавляет только те планы которых нет в Flutter по id.
/// Вызывать при старте приложения до _load().
Future<Map<String, List<Map<String, dynamic>>>> mergePlans(
    SharedPreferences prefs) async {
  final flutterRaw = prefs.getString('flutter.plans') ?? '{}';
  final nativeRaw  = prefs.getString('plans') ?? '{}';

  final flutterPlans = _decodePlans(flutterRaw);
  final nativePlans  = _decodePlans(nativeRaw);

  bool changed = false;

  // Для каждого дня из нативного хранилища
  for (final day in nativePlans.keys) {
    final nativeList  = nativePlans[day]!;
    final flutterList = flutterPlans[day] ?? [];

    // Существующие id в Flutter для этого дня
    final existingIds = flutterList.map((p) => p['id'] as String).toSet();

    for (final plan in nativeList) {
      final id = plan['id'] as String;
      if (!existingIds.contains(id)) {
        // Новый план от виджета — добавляем в Flutter
        flutterList.add(plan);
        existingIds.add(id);
        changed = true;
      } else {
        // Синхронизируем done — берём более новое состояние
        // (если виджет поставил галочку — обновляем Flutter)
        final idx = flutterList.indexWhere((p) => p['id'] == id);
        if (idx >= 0 && plan['done'] == true &&
            flutterList[idx]['done'] != true) {
          flutterList[idx] = {...flutterList[idx], 'done': true};
          changed = true;
        }
      }
    }

    flutterPlans[day] = flutterList;
  }

  if (changed) {
    await prefs.setString('flutter.plans', jsonEncode(flutterPlans));
  }

  return flutterPlans;
}

Map<String, List<Map<String, dynamic>>> _decodePlans(String raw) {
  try {
    return Map<String, List<Map<String, dynamic>>>.from(
      (jsonDecode(raw) as Map).map((k, v) => MapEntry(
          k,
          List<Map<String, dynamic>>.from(
              (v as List).map((e) => Map<String, dynamic>.from(e))))));
  } catch (_) {
    return {};
  }
}
