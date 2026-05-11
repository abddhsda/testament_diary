// ════════════════════════════════════════════════════
// screens/ratings_screen.dart — оценка дня по 5 метрикам
// Возвращает Map {answers, ratings} через Navigator.pop
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';

class RatingsScreen extends StatefulWidget {
  final List<String> answers;
  const RatingsScreen({super.key, required this.answers});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  // Начальные значения всех метрик = 5
  double _energy       = 5;
  double _productivity = 5;
  double _mood         = 5;
  double _food         = 5;
  double _sleep        = 5;

  void _done() {
    Navigator.pop(context, {
      'answers': widget.answers,
      'ratings': {
        'energy':       _energy.round(),
        'productivity': _productivity.round(),
        'mood':         _mood.round(),
        'food':         _food.round(),
        'sleep':        _sleep.round(),
      },
    });
  }

  // ─── Универсальный слайдер ────────────────────────────────────
  Widget _slider(String emoji, String label, double value,
      ValueChanged<double> onChanged) {
    final isDark = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$emoji $label',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w600, color: textColor)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: textColor, borderRadius: BorderRadius.circular(12)),
              child: Text('${value.round()}',
                  style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: textColor,
            inactiveTrackColor: Colors.grey.shade800,
            thumbColor: textColor,
            overlayColor: textColor.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(
              value: value, min: 0, max: 10, divisions: 10, onChanged: onChanged),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Оцени день',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                      color: AppSettings.of(context).themeMode == ThemeMode.dark
                          ? Colors.white : const Color(0xFF1A1A1A))),
              const SizedBox(height: 4),
              const Text('По шкале от 0 до 10',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 32),
              // Метрики в том же порядке что и в StatsScreen / AppColors.metricColors
              _slider('😴', 'Энергия',       _energy,       (v) => setState(() => _energy = v)),
              _slider('🎯', 'Продуктивность', _productivity, (v) => setState(() => _productivity = v)),
              _slider('🧠', 'Настроение',    _mood,          (v) => setState(() => _mood = v)),
              _slider('🍎', 'Еда',           _food,          (v) => setState(() => _food = v)),
              _slider('💤', 'Сон',           _sleep,         (v) => setState(() => _sleep = v)),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('Сохранить день ✓',
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
