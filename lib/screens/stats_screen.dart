// ════════════════════════════════════════════════════
// screens/stats_screen.dart — экран статистики
//
// Показывает средние значения 5 метрик за выбранный месяц
// + линейный график с возможностью выделить одну метрику
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../widgets/chart_painter.dart';

class StatsScreen extends StatefulWidget {
  final Map<String, Map<String, int>> allRatings;
  const StatsScreen({super.key, required this.allRatings});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear  = DateTime.now().year;
  String? _selectedMetric; // null = все метрики

  // ─── Метаданные метрик (порядок совпадает с AppColors.metricColors) ─
  static const _metrics = ['energy', 'productivity', 'mood', 'food', 'sleep'];
  static const _labels  = ['Энергия', 'Продуктивность', 'Настроение', 'Еда', 'Сон'];
  static const _emojis  = ['😴', '🎯', '🧠', '🍎', '💤'];

  // ─── Средние за выбранный месяц ──────────────────────────────
  Map<String, double> _getMonthAverages() {
    final result = <String, double>{};
    for (final metric in _metrics) {
      final values = <int>[];
      widget.allRatings.forEach((dateKey, ratings) {
        final parts = dateKey.split('-');
        if (parts.length == 3) {
          final year  = int.tryParse(parts[0]) ?? 0;
          final month = int.tryParse(parts[1]) ?? 0;
          if (year == _selectedYear && month == _selectedMonth &&
              ratings.containsKey(metric)) {
            values.add(ratings[metric]!);
          }
        }
      });
      result[metric] = values.isEmpty
          ? 0
          : values.reduce((a, b) => a + b) / values.length;
    }
    return result;
  }

  static String _monthName(int month) {
    const names = ['Янв','Фев','Мар','Апр','Май','Июн',
                   'Июл','Авг','Сен','Окт','Ноя','Дек'];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final averages = _getMonthAverages();
    final hasData  = averages.values.any((v) => v > 0);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Шапка ──────────────────────────────────────────
              Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textColor)),
                const SizedBox(width: 16),
                Text('Статистика',
                    style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w900, color: textColor)),
              ]),

              const SizedBox(height: 24),

              // ── Переключатель месяца ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                      else _selectedMonth--;
                    }),
                    icon: Icon(Icons.chevron_left, color: textColor),
                  ),
                  Text('${_monthName(_selectedMonth)} $_selectedYear',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700, color: textColor)),
                  IconButton(
                    onPressed: () => setState(() {
                      if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                      else _selectedMonth++;
                    }),
                    icon: Icon(Icons.chevron_right, color: textColor),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Контент ─────────────────────────────────────────
              Expanded(
                child: !hasData
                    ? Center(child: Text('Нет данных за этот месяц',
                        style: TextStyle(color: textColor.withOpacity(0.4))))
                    : SingleChildScrollView(
                        child: Column(children: [
                          // Средние значения — плитки
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              ...List.generate(_metrics.length, (i) {
                                final avg = averages[_metrics[i]] ?? 0;
                                final color = AppColors.metricColors[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(children: [
                                    Text(_emojis[i],
                                        style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(_labels[i],
                                        style: TextStyle(fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textColor))),
                                    Text(avg == 0 ? '—' : avg.toStringAsFixed(1),
                                        style: TextStyle(fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: avg == 0
                                                ? textColor.withOpacity(0.3)
                                                : color)),
                                  ]),
                                );
                              }),
                            ]),
                          ),

                          const SizedBox(height: 16),

                          // График
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              // Легенда
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: List.generate(_metrics.length, (i) {
                                  final isSelected = _selectedMetric == _metrics[i];
                                  final isAny = _selectedMetric != null;
                                  final color = (!isAny || isSelected)
                                      ? AppColors.metricColors[i]
                                      : Colors.grey.shade600;
                                  return GestureDetector(
                                    onTap: () => setState(() =>
                                        _selectedMetric = _selectedMetric == _metrics[i]
                                            ? null : _metrics[i]),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.metricColors[i].withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: color.withOpacity(isSelected ? 1 : 0.4),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle)),
                                          const SizedBox(width: 5),
                                          Text(_labels[i],
                                              style: TextStyle(fontSize: 11,
                                                  color: color,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 16),

                              // Сам график
                              SizedBox(
                                height: 200,
                                child: _buildChart(),
                              ),
                            ]),
                          ),
                        ]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: daysInMonth * 20.0,
        child: Column(children: [
          Expanded(
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: CustomPaint(
                  painter: ChartPainter(
                    allRatings: widget.allRatings,
                    year: _selectedYear,
                    month: _selectedMonth,
                    daysInMonth: daysInMonth,
                    metrics: _metrics,
                    colors: AppColors.metricColors,
                    selectedMetric: _selectedMetric,
                    isDark: isDark,
                  ),
                  size: Size(daysInMonth * 20.0, double.infinity),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Числа дней по оси X
          Row(
            children: List.generate(daysInMonth, (i) {
              final day = i + 1;
              final show = day == 1 || day % 4 == 0;
              return SizedBox(
                width: 20,
                child: Text(show ? '$day' : '',
                    style: TextStyle(fontSize: 8,
                        color: textColor.withOpacity(0.5)),
                    textAlign: TextAlign.center),
              );
            }),
          ),
        ]),
      ),
    );
  }
}
