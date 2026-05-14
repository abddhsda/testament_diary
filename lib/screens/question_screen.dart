// ════════════════════════════════════════════════════
// screens/question_screen.dart — экран ввода ответов
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../utils/ui_helpers.dart';
import 'ratings_screen.dart';

class QuestionScreen extends StatefulWidget {
  final List<String>? existing;
  final List<Map<String, String>> questions;
  final Map<String, dynamic> surveyPack;

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

  int get _totalSteps  => widget.questions.length + _surveyQuestions.length;
  bool get _inSurvey   => _current >= widget.questions.length;
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
    if (_current < _totalSteps - 1) {
      hapticLight(); // ← смена вопроса
      setState(() => _current++);
    } else {
      hapticMedium(); // ← финальный шаг → рейтинги
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
    if (_current > 0) {
      hapticLight(); // ← назад
      setState(() => _current--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent    = AppSettings.of(context).accent;
    final controller = _inSurvey
        ? _surveyControllers[_surveyIndex]
        : _textControllers[_current];
    final isLast = _current == _totalSteps - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Прогресс ────────────────────────────────────────
              Row(
                children: List.generate(_totalSteps, (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= _current
                          ? accent
                          : textColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 16),

              // ── Лейбл пака ──────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _inSurvey
                    ? Container(
                        key: const ValueKey('survey_label'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.surveyPack['emoji']} ${widget.surveyPack['title']}',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: accent),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty_label')),
              ),
              const SizedBox(height: 24),

              // ── Вопрос ──────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 0.04), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
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
                  style: TextStyle(fontSize: 18, color: textColor, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Пиши честно...',
                    hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // ── Навигация ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_current > 0)
                    TextButton(
                      onPressed: _prev,
                      child: Text('← Назад',
                          style: TextStyle(color: textColor.withOpacity(0.4),
                              fontSize: 15)),
                    )
                  else
                    const SizedBox(),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLast ? accent : const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      isLast ? 'Готово ✓' : 'Далее →',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
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
