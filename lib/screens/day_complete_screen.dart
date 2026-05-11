// ════════════════════════════════════════════════════
// screens/day_complete_screen.dart — экран "День записан"
//
// Показывается 4 секунды после сохранения записи.
// Отображает мотивирующую цитату дня.
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../logic/daily_logic.dart';

class DayCompleteScreen extends StatefulWidget {
  final DateTime date;
  const DayCompleteScreen({super.key, required this.date});

  @override
  State<DayCompleteScreen> createState() => _DayCompleteScreenState();
}

class _DayCompleteScreenState extends State<DayCompleteScreen> {
  @override
  void initState() {
    super.initState();
    // Автозакрытие через 4 секунды
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent    = AppSettings.of(context).accent;
    final quote     = getDailyQuote(widget.date);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Заголовок ───────────────────────────────────────
              const Text('🔥', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              Text('День записан',
                  style: TextStyle(fontSize: 28,
                      fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text('Ты на пути.',
                  style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.5))),

              const Spacer(),

              // ── Цитата дня ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Text(
                    '"${quote['text']}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic,
                        color: textColor, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  if ((quote['author'] ?? '').isNotEmpty)
                    Text('— ${quote['author']}',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: accent)),
                ]),
              ),

              const Spacer(),

              // ── Кнопка закрыть ──────────────────────────────────
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('Закрыть',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
