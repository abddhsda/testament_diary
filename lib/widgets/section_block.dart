// ════════════════════════════════════════════════════
// widgets/section_block.dart — коллапсируемый блок
//
// Используется в EntryCard для секций:
//   "Вопросы дня", "Опрос", "Заметки"
// Tap по заголовку → expand / collapse
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class SectionBlock extends StatefulWidget {
  final String emoji;
  final String title;
  final Color labelColor;
  final List<Widget> children;
  final bool initiallyExpanded;
  final void Function(bool)? onToggle;
  final String? emptyHint; // текст-превью в свёрнутом состоянии

  const SectionBlock({
    super.key,
    required this.emoji,
    required this.title,
    required this.labelColor,
    required this.children,
    this.initiallyExpanded = false,
    this.onToggle,
    this.emptyHint,
  });

  @override
  State<SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<SectionBlock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final surface  = Theme.of(context).colorScheme.surface;

    // Фон блока чуть светлее/темнее surface
    final bg = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.04), surface)
        : Color.alphaBlend(Colors.black.withOpacity(0.03), surface);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.labelColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок (тап = toggle) ──────────────────────────
          GestureDetector(
            onTap: () {
              setState(() => _expanded = !_expanded);
              widget.onToggle?.call(_expanded);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(widget.title,
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.labelColor)),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: widget.labelColor, size: 20,
                ),
              ]),
            ),
          ),

          // ── Превью в свёрнутом виде ───────────────────────────
          if (!_expanded && widget.emptyHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(widget.emptyHint!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: widget.labelColor.withOpacity(0.6),
                      height: 1.4)),
            ),

          // ── Содержимое (раскрытое состояние) ─────────────────
          if (_expanded) ...[
            Divider(height: 1, color: widget.labelColor.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
