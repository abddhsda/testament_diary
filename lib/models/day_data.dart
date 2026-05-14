// ════════════════════════════════════════════════════
// models/day_data.dart — данные одного дня дневника
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DayData {
  final List<String> answers;
  final Map<String, int> ratings;
  final String note;

  const DayData({
    this.answers = const [],
    this.ratings = const {},
    this.note = '',
  });

  DayData copyWith({
    List<String>? answers,
    Map<String, int>? ratings,
    String? note,
  }) =>
      DayData(
        answers: answers ?? this.answers,
        ratings: ratings ?? this.ratings,
        note: note ?? this.note,
      );

  // ─── Сериализация ─────────────────────────────────

  static Map<String, DayData> loadFromPrefs(SharedPreferences prefs) {
    final rawEntries = jsonDecode(prefs.getString('entries') ?? '{}') as Map;
    final rawRatings = jsonDecode(prefs.getString('ratings') ?? '{}') as Map;
    final rawNotes   = jsonDecode(prefs.getString('notes')   ?? '{}') as Map;

    final allKeys = {
      ...rawEntries.keys,
      ...rawRatings.keys,
      ...rawNotes.keys,
    }.cast<String>();

    return {
      for (final key in allKeys)
        key: DayData(
          answers: List<String>.from(rawEntries[key] as List? ?? []),
          ratings: Map<String, int>.from(rawRatings[key] as Map? ?? {}),
          note: rawNotes[key] as String? ?? '',
        ),
    };
  }

  static Future<void> saveToPrefs(
    SharedPreferences prefs,
    Map<String, DayData> diary,
  ) async {
    await Future.wait([
      prefs.setString('entries', jsonEncode({
        for (final e in diary.entries) e.key: e.value.answers,
      })),
      prefs.setString('ratings', jsonEncode({
        for (final e in diary.entries) e.key: e.value.ratings,
      })),
      prefs.setString('notes', jsonEncode({
        for (final e in diary.entries) e.key: e.value.note,
      })),
    ]);
  }
}
