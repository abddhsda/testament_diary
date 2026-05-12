// ════════════════════════════════════════════════════
// screens/stats_screen.dart — экран статистики
//
// Новое:
//   - Тап на точку графика → тултип с датой и значением
//   - Чипы фильтрации: показ/скрытие отдельных метрик
//   - Прогресс-бар под средним значением
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';
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

  // null = все метрики показаны; строка = только эта выделена
  String? _highlightedMetric;

  // Скрытые метрики (чипы с крестиком)
  final Set<String> _hiddenMetrics = {};

  // Тултип: день и позиция
  int? _tooltipDay;
  double? _tooltipX;

  static const _metrics = ['energy', 'productivity', 'mood', 'food', 'sleep'];
  static const _labels  = ['Энергия', 'Продуктивность', 'Настроение', 'Еда', 'Сон'];
  static const _emojis  = ['😴', '🎯', '🧠', '🍎', '💤'];

  List<String> get _visibleMetrics =>
      _metrics.where((m) => !_hiddenMetrics.contains(m)).toList();

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
          ? 0 : values.reduce((a, b) => a + b) / values.length;
    }
    return result;
  }

  // Данные конкретного дня для тултипа
  Map<String, int>? _getDayRatings(int day) {
    final key =
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    return widget.allRatings[key];
  }

  static String _monthName(int month) {
    const names = ['Янв','Фев','Мар','Апр','Май','Июн',
                   'Июл','Авг','Сен','Окт','Ноя','Дек'];
    return names[month - 1];
  }

  void _onChartTap(TapDownDetails details, double chartWidth, int daysInMonth) {
    final x = details.localPosition.dx;
    final day = ((x / chartWidth) * daysInMonth).floor() + 1;
    final clampedDay = day.clamp(1, daysInMonth);
    final dayData = _getDayRatings(clampedDay);

    if (dayData == null || dayData.isEmpty) {
      setState(() { _tooltipDay = null; _tooltipX = null; });
      return;
    }

    hapticLight();
    setState(() {
      if (_tooltipDay == clampedDay) {
        _tooltipDay = null;
        _tooltipX   = null;
      } else {
        _tooltipDay = clampedDay;
        _tooltipX   = x;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final averages  = _getMonthAverages();
    final hasData   = averages.values.any((v) => v > 0);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final accent    = AppSettings.of(context).accent;

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
                GestureDetector(
                  onTap: () { hapticLight(); Navigator.pop(context); },
                  child: Icon(Icons.arrow_back, color: textColor)),
                const SizedBox(width: 16),
                Text('Статистика', style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w900, color: textColor)),
              ]),

              const SizedBox(height: 24),

              // ── Переключатель месяца ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      hapticLight();
                      setState(() {
                        _tooltipDay = null;
                        if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                        else _selectedMonth--;
                      });
                    },
                    icon: Icon(Icons.chevron_left, color: textColor),
                  ),
                  Text('${_monthName(_selectedMonth)} $_selectedYear',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700, color: textColor)),
                  IconButton(
                    onPressed: () {
                      hapticLight();
                      setState(() {
                        _tooltipDay = null;
                        if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                        else _selectedMonth++;
                      });
                    },
                    icon: Icon(Icons.chevron_right, color: textColor),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: !hasData
                    ? Center(child: Text('Нет данных за этот месяц',
                        style: TextStyle(color: textColor.withOpacity(0.4))))
                    : SingleChildScrollView(
                        child: Column(children: [
                          // ── Средние значения ──────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              ...List.generate(_metrics.length, (i) {
                                final avg   = averages[_metrics[i]] ?? 0;
                                final color = AppColors.metricColors[i];
                                final isHidden = _hiddenMetrics.contains(_metrics[i]);
                                return GestureDetector(
                                  onTap: () {
                                    hapticLight();
                                    setState(() {
                                      if (isHidden) {
                                        _hiddenMetrics.remove(_metrics[i]);
                                      } else if (_highlightedMetric == _metrics[i]) {
                                        _highlightedMetric = null;
                                      } else {
                                        _highlightedMetric = _metrics[i];
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Opacity(
                                      opacity: isHidden ? 0.35 : 1.0,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(_emojis[i],
                                                style: const TextStyle(fontSize: 18)),
                                            const SizedBox(width: 10),
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
                                          if (avg > 0) ...[
                                            const SizedBox(height: 6),
                                            // Прогресс-бар
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: avg / 10,
                                                backgroundColor: textColor.withOpacity(0.08),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                    _highlightedMetric == _metrics[i]
                                                        ? color
                                                        : color.withOpacity(0.6)),
                                                minHeight: 4,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ]),
                          ),

                          const SizedBox(height: 16),

                          // ── График ────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              // Чипы фильтрации
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: List.generate(_metrics.length, (i) {
                                  final isHidden     = _hiddenMetrics.contains(_metrics[i]);
                                  final isHighlighted = _highlightedMetric == _metrics[i];
                                  final color = isHidden
                                      ? Colors.grey.shade600
                                      : AppColors.metricColors[i];

                                  return GestureDetector(
                                    onTap: () {
                                      hapticLight();
                                      setState(() {
                                        _tooltipDay = null;
                                        if (isHidden) {
                                          _hiddenMetrics.remove(_metrics[i]);
                                        } else {
                                          _highlightedMetric =
                                              _highlightedMetric == _metrics[i]
                                                  ? null : _metrics[i];
                                        }
                                      });
                                    },
                                    onLongPress: () {
                                      hapticMedium();
                                      setState(() {
                                        _tooltipDay = null;
                                        if (isHidden) {
                                          _hiddenMetrics.remove(_metrics[i]);
                                        } else {
                                          _hiddenMetrics.add(_metrics[i]);
                                          if (_highlightedMetric == _metrics[i]) {
                                            _highlightedMetric = null;
                                          }
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isHighlighted
                                            ? AppColors.metricColors[i].withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: color.withOpacity(isHidden ? 0.3 : (isHighlighted ? 1.0 : 0.5)),
                                          width: isHighlighted ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Container(width: 8, height: 8,
                                            decoration: BoxDecoration(
                                                color: color, shape: BoxShape.circle)),
                                        const SizedBox(width: 5),
                                        Text(_labels[i], style: TextStyle(
                                            fontSize: 11, color: color,
                                            fontWeight: isHighlighted
                                                ? FontWeight.w700 : FontWeight.w500,
                                            decoration: isHidden
                                                ? TextDecoration.lineThrough : null)),
                                      ]),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 4),
                              Text('Тап — выделить • Долгий тап — скрыть',
                                  style: TextStyle(fontSize: 10,
                                      color: textColor.withOpacity(0.3))),

                              const SizedBox(height: 12),

                              // График с тултипом
                              SizedBox(
                                height: 220,
                                child: _buildChart(textColor),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 24),
                        ]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(Color textColor) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final chartWidth  = daysInMonth * 20.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: Column(children: [
          Expanded(
            child: Stack(children: [
              // ── График ────────────────────────────────────────
              GestureDetector(
                onTapDown: (d) => _onChartTap(d, chartWidth, daysInMonth),
                child: ClipRect(
                  child: CustomPaint(
                    painter: ChartPainter(
                      allRatings: widget.allRatings,
                      year: _selectedYear,
                      month: _selectedMonth,
                      daysInMonth: daysInMonth,
                      metrics: _visibleMetrics,
                      colors: _visibleMetrics
                          .map((m) => AppColors.metricColors[_metrics.indexOf(m)])
                          .toList(),
                      selectedMetric: _highlightedMetric,
                      isDark: isDark,
                    ),
                    size: Size(chartWidth, double.infinity),
                  ),
                ),
              ),

              // ── Тултип при тапе ───────────────────────────────
              if (_tooltipDay != null && _tooltipX != null)
                _buildTooltip(daysInMonth, chartWidth, isDark, textColor),
            ]),
          ),

          const SizedBox(height: 4),
          // Ось X — числа дней
          Row(
            children: List.generate(daysInMonth, (i) {
              final day  = i + 1;
              final show = day == 1 || day % 4 == 0;
              final isSelected = day == _tooltipDay;
              return SizedBox(
                width: 20,
                child: Text(show || isSelected ? '$day' : '',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected
                            ? AppSettings.of(context).accent
                            : textColor.withOpacity(0.5)),
                    textAlign: TextAlign.center),
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _buildTooltip(int daysInMonth, double chartWidth, bool isDark, Color textColor) {
    final dayData = _getDayRatings(_tooltipDay!);
    if (dayData == null) return const SizedBox();

    // Позиция тултипа — пузырь над точкой
    final x     = (_tooltipDay! - 1) / daysInMonth * chartWidth;
    final left  = (x - 70).clamp(0.0, chartWidth - 140);

    return Positioned(
      left: left,
      top: 0,
      child: GestureDetector(
        onTap: () => setState(() { _tooltipDay = null; _tooltipX = null; }),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
            border: Border.all(
                color: textColor.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Дата
              Text(
                '${_tooltipDay} ${_monthName(_selectedMonth)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: textColor.withOpacity(0.6)),
              ),
              const SizedBox(height: 6),
              // Значения метрик
              ..._visibleMetrics.map((m) {
                final i     = _metrics.indexOf(m);
                final value = dayData[m];
                if (value == null) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: AppColors.metricColors[i],
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(_labels[i],
                        style: TextStyle(fontSize: 10,
                            color: textColor.withOpacity(0.7))),
                    const Spacer(),
                    Text('$value',
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.metricColors[i])),
                  ]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
