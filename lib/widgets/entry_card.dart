// ════════════════════════════════════════════════════
// widgets/entry_card.dart — карточка с записью дня
// Блоки: Вопросы / Опрос / Оценки дня / Заметки
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';
import 'section_block.dart';

class EntryCard extends StatefulWidget {
  final List<String> answers;
  final List<Map<String, String>> dailyQuestions;
  final Map<String, dynamic> surveyPack;
  final bool isToday;
  final String note;
  final Map<String, int>? ratings;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(Map<String, int>) onRatingsSaved;

  const EntryCard({
    super.key,
    required this.answers,
    required this.dailyQuestions,
    required this.surveyPack,
    required this.isToday,
    required this.note,
    this.ratings,
    required this.onNoteSaved,
    required this.onRatingsSaved,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  late TextEditingController _noteController;

  // Локальные значения слайдеров
  late double _energy;
  late double _productivity;
  late double _mood;
  late double _food;
  late double _sleep;

  // Для haptic при смене деления
  late Map<String, int> _prevRounded;

  static const _metricKeys   = ['energy', 'productivity', 'mood', 'food', 'sleep'];
  static const _metricLabels = ['Энергия', 'Продуктивность', 'Настроение', 'Еда', 'Сон'];
  static const _metricEmojis = ['😴', '🎯', '🧠', '🍎', '💤'];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.note);
    _initRatings();
  }

  void _initRatings() {
    final r = widget.ratings;
    _energy       = (r?['energy']       ?? 5).toDouble();
    _productivity = (r?['productivity'] ?? 5).toDouble();
    _mood         = (r?['mood']         ?? 5).toDouble();
    _food         = (r?['food']         ?? 5).toDouble();
    _sleep        = (r?['sleep']        ?? 5).toDouble();
    _prevRounded  = {for (final k in _metricKeys) k: _currentValue(k).round()};
  }

  double _currentValue(String key) {
    switch (key) {
      case 'energy':       return _energy;
      case 'productivity': return _productivity;
      case 'mood':         return _mood;
      case 'food':         return _food;
      case 'sleep':        return _sleep;
      default:             return 5;
    }
  }

  void _setRating(String key, double value) {
    setState(() {
      switch (key) {
        case 'energy':       _energy       = value;
        case 'productivity': _productivity = value;
        case 'mood':         _mood         = value;
        case 'food':         _food         = value;
        case 'sleep':        _sleep        = value;
      }
    });
    // Haptic при смене деления
    final rounded = value.round();
    if (rounded != _prevRounded[key]) {
      hapticLight();
      _prevRounded[key] = rounded;
    }
    // Сохраняем
    widget.onRatingsSaved({
      'energy':       _energy.round(),
      'productivity': _productivity.round(),
      'mood':         _mood.round(),
      'food':         _food.round(),
      'sleep':        _sleep.round(),
    });
  }

  @override
  void didUpdateWidget(EntryCard old) {
    super.didUpdateWidget(old);
    if (old.note != widget.note && _noteController.text != widget.note) {
      _noteController.text = widget.note;
    }
    // Обновляем рейтинги если сменилась дата (пришли новые данные)
    if (old.ratings != widget.ratings) _initRatings();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1A1A1A);
    final labelColor = isDark ? Colors.white.withOpacity(0.45) : Colors.grey.shade600;
    final accent     = AppSettings.of(context).accent;

    final qCount        = widget.dailyQuestions.length;
    final textAnswers   = widget.answers.length > qCount
        ? widget.answers.sublist(0, qCount) : widget.answers;
    final surveyAnswers = widget.answers.length > qCount
        ? widget.answers.sublist(qCount) : <String>[];
    final surveyQuestions =
        List<String>.from(widget.surveyPack['questions'] as List);

    final totalQ = qCount + surveyQuestions.length;
    final filled = widget.answers.where((a) => a.isNotEmpty).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: widget.isToday
            ? Border.all(color: const Color(0xFFFFD700), width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Прогресс-бар
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LinearProgressIndicator(
              value: totalQ > 0 ? filled / totalQ : 0,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(accent.withOpacity(0.6)),
              minHeight: 3,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── 1. Вопросы дня ──────────────────────────
                  SectionBlock(
                    emoji: '💬',
                    title: 'Вопросы дня',
                    labelColor: labelColor,
                    initiallyExpanded: true,
                    children: List.generate(textAnswers.length, (i) {
                      if (i >= widget.dailyQuestions.length ||
                          textAnswers[i].isEmpty) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.dailyQuestions[i]['emoji']} '
                              '${widget.dailyQuestions[i]['q']}',
                              style: TextStyle(fontSize: 12,
                                  color: labelColor, height: 1.4),
                            ),
                            const SizedBox(height: 6),
                            Text(textAnswers[i],
                                style: TextStyle(fontSize: 15,
                                    color: textColor, height: 1.5)),
                          ],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 10),

                  // ── 2. Опрос дня ────────────────────────────
                  if (surveyAnswers.isNotEmpty &&
                      surveyAnswers.any((a) => a.isNotEmpty)) ...[
                    SectionBlock(
                      emoji: widget.surveyPack['emoji'] as String,
                      title: widget.surveyPack['title'] as String,
                      labelColor: labelColor,
                      initiallyExpanded: true,
                      children: List.generate(surveyAnswers.length, (i) {
                        if (i >= surveyQuestions.length ||
                            surveyAnswers[i].isEmpty) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(surveyQuestions[i],
                                  style: TextStyle(fontSize: 12,
                                      color: labelColor, height: 1.4)),
                              const SizedBox(height: 4),
                              Text(surveyAnswers[i],
                                  style: TextStyle(fontSize: 15,
                                      color: textColor, height: 1.5)),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── 3. Оценки дня ───────────────────────────
                  SectionBlock(
                    emoji: '📊',
                    title: 'Оценки дня',
                    labelColor: labelColor,
                    initiallyExpanded: true,
                    children: List.generate(_metricKeys.length, (i) {
                      final key   = _metricKeys[i];
                      final value = _currentValue(key);
                      final color = AppColors.metricColors[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Text(_metricEmojis[i],
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(_metricLabels[i],
                                      style: TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textColor)),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${value.round()}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: color,
                                inactiveTrackColor: color.withOpacity(0.15),
                                thumbColor: color,
                                overlayColor: color.withOpacity(0.12),
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                              ),
                              child: Slider(
                                value: value,
                                min: 0, max: 10, divisions: 10,
                                onChanged: (v) => _setRating(key, v),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 10),

                  // ── 4. Заметки ──────────────────────────────
                  SectionBlock(
                    emoji: '✏️',
                    title: 'Заметки по дню',
                    labelColor: labelColor,
                    initiallyExpanded: true,
                    emptyHint: widget.note.isEmpty
                        ? 'О чём ты думаешь прямо сейчас...'
                        : (widget.note.length > 80
                            ? '${widget.note.substring(0, 80)}...'
                            : widget.note),
                    children: [
                      TextField(
                        controller: _noteController,
                        maxLines: null,
                        autofocus: false,
                        style: TextStyle(fontSize: 15,
                            color: textColor, height: 1.5),
                        decoration: InputDecoration(
                          hintText: 'О чём ты думаешь прямо сейчас...',
                          hintStyle:
                              TextStyle(color: labelColor, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: widget.onNoteSaved,
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
