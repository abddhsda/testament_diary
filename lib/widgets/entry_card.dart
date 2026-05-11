// ════════════════════════════════════════════════════
// widgets/entry_card.dart — карточка с записью дня
//
// Показывает: вопросы + ответы, опрос + ответы,
//             заметки по дню (редактируемые)
// Использует SectionBlock для коллапсируемых блоков
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import 'section_block.dart';

class EntryCard extends StatefulWidget {
  final List<String> answers;
  final List<Map<String, String>> dailyQuestions;
  final Map<String, dynamic> surveyPack;
  final bool isToday;
  final String note;
  final Future<void> Function(String) onNoteSaved;

  const EntryCard({
    super.key,
    required this.answers,
    required this.dailyQuestions,
    required this.surveyPack,
    required this.isToday,
    required this.note,
    required this.onNoteSaved,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  bool _noteExpanded = false;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textColor   = isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1A1A1A);
    final labelColor  = isDark ? Colors.white.withOpacity(0.5) : Colors.grey;
    final accent      = AppSettings.of(context).accent;

    // Первые 3 ответа — на вопросы дня, остальные — на surveyPack
    final textAnswers   = widget.answers.length > 3
        ? widget.answers.sublist(0, 3)
        : widget.answers;
    final surveyAnswers = widget.answers.length > 3
        ? widget.answers.sublist(3)
        : <String>[];
    final surveyQuestions =
        List<String>.from(widget.surveyPack['questions'] as List);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        // Золотая рамка для сегодня
        border: widget.isToday
            ? Border.all(color: const Color(0xFFFFD700), width: 2)
            : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Вопросы дня ────────────────────────────────────
            SectionBlock(
              emoji: '💬',
              title: 'Вопросы дня',
              labelColor: labelColor,
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
                        style: TextStyle(fontSize: 13, color: labelColor),
                      ),
                      const SizedBox(height: 6),
                      Text(textAnswers[i],
                          style: TextStyle(fontSize: 16, color: textColor)),
                    ],
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),

            // ── Опрос дня ──────────────────────────────────────
            if (surveyAnswers.isNotEmpty)
              SectionBlock(
                emoji: widget.surveyPack['emoji'] as String,
                title: widget.surveyPack['title'] as String,
                labelColor: labelColor,
                children: List.generate(surveyAnswers.length, (i) {
                  if (i >= surveyQuestions.length ||
                      surveyAnswers[i].isEmpty) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(surveyQuestions[i],
                            style: TextStyle(fontSize: 13, color: labelColor)),
                        const SizedBox(height: 4),
                        Text(surveyAnswers[i],
                            style: TextStyle(fontSize: 16, color: textColor)),
                      ],
                    ),
                  );
                }),
              ),

            const SizedBox(height: 12),

            // ── Заметки по дню (редактируемые) ─────────────────
            SectionBlock(
              emoji: '✏️',
              title: 'Заметки по дню',
              labelColor: labelColor,
              initiallyExpanded: _noteExpanded,
              onToggle: (val) => setState(() => _noteExpanded = val),
              // В свёрнутом виде показываем превью текста
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
                  style: TextStyle(
                      fontSize: 15, color: textColor, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'О чём ты думаешь прямо сейчас...',
                    hintStyle:
                        TextStyle(color: labelColor, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (text) => widget.onNoteSaved(text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
