// ════════════════════════════════════════════════════
// services/export_service.dart
//
// Экспорт: TXT (читаемый), JSON (бэкап), CSV (таблица)
// Импорт: JSON бэкап → восстановление всех данных
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ui_helpers.dart';

class ExportService {

  // ─── Экспорт TXT ─────────────────────────────────────────────
  static Future<void> exportTxt(BuildContext context) async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final entries    = jsonDecode(prefs.getString('entries') ?? '{}') as Map;
      final ratings    = jsonDecode(prefs.getString('ratings') ?? '{}') as Map;
      final notes      = jsonDecode(prefs.getString('notes')   ?? '{}') as Map;
      final goal       = prefs.getString('goal') ?? '';

      final buf = StringBuffer();
      buf.writeln('═══════════════════════════════');
      buf.writeln('  MODO — Дневник');
      buf.writeln('  ${DateTime.now().toString().substring(0, 10)}');
      buf.writeln('═══════════════════════════════');
      if (goal.isNotEmpty) { buf.writeln('Цель: $goal'); buf.writeln(); }

      final dates = entries.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final date in dates) {
        buf.writeln('───────────────────────────────');
        buf.writeln('📅 $date');
        buf.writeln();
        final answers = List<String>.from(entries[date] as List);
        for (int i = 0; i < answers.length; i++) {
          if (answers[i].isNotEmpty) buf.writeln('  ${i + 1}. ${answers[i]}');
        }
        if (ratings.containsKey(date)) {
          final r = ratings[date] as Map;
          buf.writeln();
          buf.writeln('  📊 Энергия ${r['energy']} | '
              'Продуктивность ${r['productivity']} | '
              'Настроение ${r['mood']} | '
              'Еда ${r['food']} | Сон ${r['sleep']}');
        }
        if (notes.containsKey(date) && (notes[date] as String).isNotEmpty) {
          buf.writeln();
          buf.writeln('  ✏️ ${notes[date]}');
        }
        buf.writeln();
      }

      await _shareText(buf.toString(), 'modo_diary.txt', 'text/plain');
      if (context.mounted) showAppSnack(context, 'Экспорт TXT готов');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Экспорт JSON (полный бэкап) ─────────────────────────────
  static Future<void> exportJson(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'version':      2,
        'exported_at':  DateTime.now().toIso8601String(),
        'app':          'modo',
        'goal':         prefs.getString('goal')         ?? '',
        'goalCategory': prefs.getString('goalCategory') ?? '',
        'isPremium':    prefs.getBool('isPremium')      ?? false,
        'accentIndex':  prefs.getInt('accentIndex')     ?? 0,
        'isDark':       prefs.getBool('isDark')         ?? false,
        'entries':      jsonDecode(prefs.getString('entries') ?? '{}'),
        'ratings':      jsonDecode(prefs.getString('ratings') ?? '{}'),
        'notes':        jsonDecode(prefs.getString('notes')   ?? '{}'),
        'plans':        jsonDecode(prefs.getString('flutter.plans') ?? '{}'),
      };
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      final date   = DateTime.now().toString().substring(0, 10);
      await _shareText(pretty, 'modo_backup_$date.json', 'application/json');
      if (context.mounted) showAppSnack(context, 'Бэкап JSON готов');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Экспорт CSV (таблица для Excel/Sheets) ───────────────────
  static Future<void> exportCsv(BuildContext context) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final entries = jsonDecode(prefs.getString('entries') ?? '{}') as Map;
      final ratings = jsonDecode(prefs.getString('ratings') ?? '{}') as Map;
      final notes   = jsonDecode(prefs.getString('notes')   ?? '{}') as Map;

      final buf = StringBuffer();
      // Заголовок
      buf.writeln('Дата,Энергия,Продуктивность,Настроение,Еда,Сон,Ответов,Заметка');

      final dates = entries.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final date in dates) {
        final r       = ratings[date] as Map? ?? {};
        final answers = List<String>.from(entries[date] as List);
        final filled  = answers.where((a) => a.isNotEmpty).length;
        final note    = (notes[date] as String? ?? '')
            .replaceAll('"', '""')   // экранируем " перед обёрткой в кавычки
            .replaceAll(',', ';')
            .replaceAll('\n', ' ');

        buf.writeln([
          date,
          r['energy']       ?? '',
          r['productivity']  ?? '',
          r['mood']          ?? '',
          r['food']          ?? '',
          r['sleep']         ?? '',
          filled,
          '"$note"',
        ].join(','));
      }

      final date = DateTime.now().toString().substring(0, 10);
      await _shareText(buf.toString(), 'modo_stats_$date.csv', 'text/csv');
      if (context.mounted) showAppSnack(context, 'Экспорт CSV готов');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Импорт JSON ─────────────────────────────────────────────
  static Future<void> importJson(
    BuildContext context, {
    /// Если передан — вызывается после успешного импорта для перезагрузки UI.
    /// Если не передан — показывается snack с просьбой перезапустить вручную.
    Future<void> Function()? onImported,
  }) async {
    try {
      // Выбор файла
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Выбери бэкап Modo',
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final data    = jsonDecode(content) as Map<String, dynamic>;

      // Проверка что это бэкап Modo
      if (data['app'] != 'modo' && !data.containsKey('entries')) {
        if (context.mounted) {
          showAppSnack(context, 'Это не бэкап Modo', isError: true);
        }
        return;
      }

      // Диалог подтверждения
      if (context.mounted) {
        final exportedAt = data['exported_at'] as String? ?? 'неизвестно';
        final date = exportedAt.length >= 10 ? exportedAt.substring(0, 10) : exportedAt;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text('Восстановить данные?',
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            content: Text(
              'Бэкап от $date будет загружен.\n\n'
              'Текущие данные будут заменены.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white, elevation: 0),
                child: const Text('Восстановить'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      // Записываем данные
      final prefs = await SharedPreferences.getInstance();
      final writes = <Future>[];

      if (data['entries'] != null) writes.add(
          prefs.setString('entries', jsonEncode(data['entries'])));
      if (data['ratings'] != null) writes.add(
          prefs.setString('ratings', jsonEncode(data['ratings'])));
      if (data['notes'] != null) writes.add(
          prefs.setString('notes', jsonEncode(data['notes'])));
      if (data['plans'] != null) writes.addAll([
          prefs.setString('flutter.plans', jsonEncode(data['plans'])),
          prefs.setString('plans', jsonEncode(data['plans'])),
        ]);
      if (data['goal'] != null) writes.add(
          prefs.setString('goal', data['goal'] as String));
      if (data['goalCategory'] != null) writes.add(
          prefs.setString('goalCategory', data['goalCategory'] as String));
      // Настройки — опционально (только если есть в бэкапе)
      if (data['isPremium'] != null) writes.add(
          prefs.setBool('isPremium', data['isPremium'] as bool));
      if (data['accentIndex'] != null) writes.add(
          prefs.setInt('accentIndex', data['accentIndex'] as int));
      if (data['isDark'] != null) writes.add(
          prefs.setBool('isDark', data['isDark'] as bool));

      await Future.wait(writes);

      if (context.mounted) {
        hapticSuccess();
        if (onImported != null) {
          await onImported();
          if (context.mounted) showAppSnack(context, '✅ Данные восстановлены');
        } else {
          showAppSnack(context, '✅ Данные восстановлены. Перезапусти приложение.');
        }
      }
    } on FileSystemException {
      if (context.mounted) showAppSnack(context, 'Не удалось прочитать файл', isError: true);
    } on FormatException {
      if (context.mounted) showAppSnack(context, 'Файл повреждён', isError: true);
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Вспомогательные ─────────────────────────────────────────
  static Future<void> _shareText(
      String content, String filename, String mimeType) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, encoding: utf8);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: 'Modo — $filename',
    );
  }
}
