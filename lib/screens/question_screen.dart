// ════════════════════════════════════════════════════
// screens/question_screen.dart — экран ввода ответов
//
// Последовательный ввод: сначала 6 вопросов дня,
// потом 5 вопросов surveyPack → RatingsScreen → pop с результатом
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import 'ratings_screen.dart';
import 'package:mindful_diary/notifications.dart' as notif;

class QuestionScreen extends StatefulWidget {
  final List<String>? existing;      // существующие ответы (режим редактирования)
  final List<Map<String, String>> questions; // 6 вопросов дня
  final Map<String, dynamic> surveyPack;     // пак с 5 вопросами

  const QuestionScreen({
    super.key,
    this.existing,
    required this.questions,
    required this.surveyPack,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int _current = 0;
  late List<TextEditingController> _textControllers;
  late List<TextEditingController> _surveyControllers;

  List<String> get _surveyQuestions =>
      List<String>.from(widget.surveyPack['questions'] as List);

  int get _totalSteps => widget.questions.length + _surveyQuestions.length;
  bool get _inSurvey  => _current >= widget.questions.length;
  int  get _surveyIndex => _current - widget.questions.length;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing ?? [];
    _textControllers = List.generate(widget.questions.length,
        (i) => TextEditingController(text: i < existing.length ? existing[i] : ''));
    _surveyControllers = List.generate(_surveyQuestions.length, (i) {
      final idx = widget.questions.length + i;
      return TextEditingController(text: idx < existing.length ? existing[idx] : '');
    });
  }

  @override
  void dispose() {
    for (final c in _textControllers) c.dispose();
    for (final c in _surveyControllers) c.dispose();
    super.dispose();
  }

  void _next() async {
    // При первом шаге инициализируем notifications (запрос разрешений iOS)
    if (_current == 0) await notif.initNotifications();

    if (_current < _totalSteps - 1) {
      setState(() => _current++);
    } else {
      // Все вопросы пройдены → RatingsScreen
      final allAnswers = [
        ..._textControllers.map((c) => c.text),
        ..._surveyControllers.map((c) => c.text),
      ];
      final ratings = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => RatingsScreen(answers: allAnswers)),
      );
      if (context.mounted) Navigator.pop(context, ratings);
    }
  }

  void _prev() {
    if (_current > 0) setState(() => _current--);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent = AppSettings.of(context).accent;
    final controller = _inSurvey
        ? _surveyControllers[_surveyIndex]
        : _textControllers[_current];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Прогресс-бар (сегменты по шагам) ───────────────
              Row(
                children: List.generate(_totalSteps, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= _current ? accent : textColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 16),

              // ── Лейбл опросного блока ───────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _inSurvey
                    ? Container(
                        key: const ValueKey('survey_label'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.surveyPack['emoji']} ${widget.surveyPack['title']}',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: textColor),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty_label')),
              ),
              const SizedBox(height: 24),

              // ── Вопрос (анимированная смена) ────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_current),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_inSurvey) ...[
                      Text(widget.questions[_current]['emoji']!,
                          style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      _inSurvey
                          ? _surveyQuestions[_surveyIndex]
                          : widget.questions[_current]['q']!,
                      style: TextStyle(fontSize: 22,
                          fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Поле ввода ──────────────────────────────────────
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  style: TextStyle(fontSize: 18, color: textColor),
                  decoration: const InputDecoration(
                    hintText: 'Пиши честно...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // ── Навигация назад/вперёд ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_current > 0)
                    TextButton(onPressed: _prev,
                        child: const Text('← Назад',
                            style: TextStyle(color: Colors.grey)))
                  else const SizedBox(),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(_current == _totalSteps - 1 ? 'Готово ✓' : 'Далее →'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
