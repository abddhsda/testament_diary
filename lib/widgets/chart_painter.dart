// ════════════════════════════════════════════════════
// widgets/chart_painter.dart — CustomPainter для графика метрик
//
// Рисует линии и точки по 5 метрикам за месяц.
// Если точки совпадают — рисует "пиццу" из секторов.
// Выбранная метрика рисуется поверх с большей толщиной.
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:math' as math;

class ChartPainter extends CustomPainter {
  final Map<String, Map<String, int>> allRatings;
  final int year;
  final int month;
  final int daysInMonth;
  final List<String> metrics;
  final List<Color> colors;
  final String? selectedMetric; // null = все
  final bool isDark;

  const ChartPainter({
    required this.allRatings,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.metrics,
    required this.colors,
    this.selectedMetric,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Невыбранные метрики отображаются серым
    final unselectedColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final effectiveColors = List.generate(metrics.length, (i) {
      if (selectedMetric == null) return colors[i];
      return metrics[i] == selectedMetric ? colors[i] : unselectedColor;
    });

    // ─── Сетка ─────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(isDark ? 0.15 : 0.25)
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i += 2) {
      final y = size.height - (i / 10) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ─── Точки по метрикам ─────────────────────────────────────
    final metricPoints = <int, List<Offset>>{};
    for (int mi = 0; mi < metrics.length; mi++) {
      final points = <Offset>[];
      for (int d = 1; d <= daysInMonth; d++) {
        final key =
            '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final rating = allRatings[key]?[metrics[mi]];
        if (rating != null) {
          final x = daysInMonth > 1
              ? (d - 1) / (daysInMonth - 1) * size.width
              : size.width / 2;
          final y = size.height - (rating / 10) * size.height;
          points.add(Offset(x, y));
        }
      }
      metricPoints[mi] = points;
    }

    // ─── Невыбранные линии (с учётом совпадения сегментов) ─────
    final segmentMetrics = <String, List<int>>{};
    for (int mi = 0; mi < metrics.length; mi++) {
      if (selectedMetric != null && metrics[mi] == selectedMetric) continue;
      final points = metricPoints[mi]!;
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final segKey =
            '${p1.dx.toStringAsFixed(1)}_${p1.dy.toStringAsFixed(1)}_${p2.dx.toStringAsFixed(1)}_${p2.dy.toStringAsFixed(1)}';
        segmentMetrics.putIfAbsent(segKey, () => []);
        segmentMetrics[segKey]!.add(mi);
      }
    }

    for (final entry in segmentMetrics.entries) {
      final parts = entry.key.split('_');
      final p1 = Offset(double.parse(parts[0]), double.parse(parts[1]));
      final p2 = Offset(double.parse(parts[2]), double.parse(parts[3]));
      final mis = entry.value;

      if (mis.length == 1) {
        // Одна метрика — простая линия
        canvas.drawLine(p1, p2, Paint()
          ..color = effectiveColors[mis[0]]
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
      } else {
        // Несколько метрик совпали — чередуем цвета по сегментам
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final steps = ((p2 - p1).distance / 6).ceil().clamp(1, 999);
        for (int s = 0; s < steps; s++) {
          final t1 = s / steps;
          final t2 = (s + 1) / steps;
          canvas.drawLine(
            Offset(p1.dx + dx * t1, p1.dy + dy * t1),
            Offset(p1.dx + dx * t2, p1.dy + dy * t2),
            Paint()
              ..color = effectiveColors[mis[s % mis.length]]
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }

    // ─── Выбранная линия поверх ─────────────────────────────────
    if (selectedMetric != null) {
      final selIdx = metrics.indexOf(selectedMetric!);
      if (selIdx >= 0) {
        final points = metricPoints[selIdx]!;
        if (points.length >= 2) {
          final path = Path()..moveTo(points[0].dx, points[0].dy);
          for (int i = 1; i < points.length; i++) {
            path.lineTo(points[i].dx, points[i].dy);
          }
          canvas.drawPath(path, Paint()
            ..color = effectiveColors[selIdx]
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke);
        }
      }
    }

    // ─── Точки (пицца если совпадают) ──────────────────────────
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (int mi = 0; mi < metrics.length; mi++) {
      for (final pt in metricPoints[mi]!) {
        final groupKey =
            '${pt.dx.toStringAsFixed(1)}_${pt.dy.toStringAsFixed(1)}';
        grouped.putIfAbsent(groupKey, () => []);
        grouped[groupKey]!.add(
            {'x': pt.dx, 'y': pt.dy, 'color': effectiveColors[mi], 'metric': metrics[mi]});
      }
    }

    const double radius = 4.0;
    for (final pts in grouped.values) {
      final hasSelected = selectedMetric != null &&
          pts.any((p) => p['metric'] == selectedMetric);
      if (hasSelected) continue;
      final x = pts[0]['x'] as double;
      final y = pts[0]['y'] as double;
      final center = Offset(x, y);

      if (pts.length == 1) {
        canvas.drawCircle(center, radius, Paint()..color = pts[0]['color'] as Color);
      } else {
        // Пицца — каждой метрике сектор
        final sweepAngle = 2 * math.pi / pts.length;
        for (int i = 0; i < pts.length; i++) {
          final startAngle = -math.pi / 2 + sweepAngle * i;
          final path = Path()
            ..moveTo(x, y)
            ..arcTo(Rect.fromCircle(center: center, radius: radius),
                startAngle, sweepAngle, false)
            ..close();
          canvas.drawPath(path,
              Paint()..color = pts[i]['color'] as Color..style = PaintingStyle.fill);
        }
        canvas.drawCircle(center, radius, Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
      }
    }

    // ─── Точки выбранной метрики поверх ────────────────────────
    if (selectedMetric != null) {
      final selIdx = metrics.indexOf(selectedMetric!);
      if (selIdx >= 0) {
        for (final pt in metricPoints[selIdx]!) {
          canvas.drawCircle(pt, 5, Paint()..color = effectiveColors[selIdx]);
          canvas.drawCircle(pt, 5, Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
