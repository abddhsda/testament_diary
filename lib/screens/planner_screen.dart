// ════════════════════════════════════════════════════
// screens/planner_screen.dart — планировщик
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app.dart';
import '../utils/ui_helpers.dart';
import '../utils/date_labels.dart';
import '../services/notifications.dart' as notif;

class PlannerScreen extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> allPlans;
  final Future<void> Function(String key, List<Map<String, dynamic>> plans) onSave;
  final bool openAddOnStart;
  final VoidCallback? onClose;

  const PlannerScreen({
    super.key,
    required this.allPlans,
    required this.onSave,
    this.openAddOnStart = false,
    this.onClose,
  });

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  late Map<String, List<Map<String, dynamic>>> _allPlans;
  late ScrollController _calendarController;

  static const _alarmChannel = MethodChannel('com.example.mindful_diary/alarm');

  @override
  void initState() {
    super.initState();
    _allPlans = Map.from(widget.allPlans);
    final now = DateTime.now();
    final daysFromEpoch = now.difference(DateTime(now.year - 5)).inDays;
    _calendarController = ScrollController(
        initialScrollOffset: (daysFromEpoch * 60.0) - 150);
    if (widget.openAddOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addPlan();
      });
    }
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _selectedPlans =>
      _allPlans[dateKey(_selectedDate)] ?? [];

  bool _hasPlans(DateTime d) => (_allPlans[dateKey(d)] ?? []).isNotEmpty;

  // ─── Создание плана ─────────────────────────────────────────
  Map<String, dynamic> _createPlan(String text, TimeOfDay? time) => {
    'id':   DateTime.now().millisecondsSinceEpoch.toString(),
    'text': text,
    'time': time != null
        ? '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}'
        : null,
    'done': false,
  };

  void _addPlan() {
    hapticLight();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddPlanSheet(
        accent: AppSettings.of(context).accent,
        onSetAlarm: _setAlarm,
        onSubmit: (text, time) {
          final plan  = _createPlan(text, time);
          final k     = dateKey(_selectedDate);
          final plans = List<Map<String, dynamic>>.from(_allPlans[k] ?? [])
            ..add(plan);
          setState(() => _allPlans[k] = plans);
          widget.onSave(k, plans);
          _schedulePlanNotification(plan);
        },
      ),
    );
  }

  void _schedulePlanNotification(Map<String, dynamic> plan) async {
    if (plan['time'] == null) return;
    final parts = (plan['time'] as String).split(':');
    final scheduled = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
    await notif.schedulePlanReminder(
        plan['id'] as String, plan['text'] as String, scheduled);
  }

  Future<void> _setAlarm(String text, TimeOfDay time) async {
    try {
      await _alarmChannel.invokeMethod('setAlarm', {
        'hour': time.hour, 'minute': time.minute, 'message': text,
      });
    } catch (_) {
      if (mounted) showAppSnack(context, 'Не удалось открыть будильник', isError: true);
    }
  }

  void _toggleDone(String key, int index) {
    final plans = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
    final wasDone = plans[index]['done'] as bool? ?? false;
    plans[index] = {...plans[index], 'done': !wasDone};
    if (wasDone) {
      hapticLight();
    } else {
      hapticSuccess(); // выполнено!
    }
    setState(() => _allPlans[key] = plans);
    widget.onSave(key, plans);
  }

  // Прокручиваем календарь к выбранной дате после свайпа
  void _scrollCalendarToSelected() {
    final now = DateTime.now();
    final daysFromEpoch =
        _selectedDate.difference(DateTime(now.year - 5)).inDays;
    final targetOffset = (daysFromEpoch * 60.0) - 150;
    _calendarController.animateTo(
      targetOffset.clamp(0.0, _calendarController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _deletePlan(String key, int index) {
    hapticMedium();
    final plans = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
    plans.removeAt(index);
    setState(() => _allPlans[key] = plans);
    widget.onSave(key, plans);
    showAppSnack(context, 'План удалён');
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final now       = DateTime.now();
    final key       = dateKey(_selectedDate);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300 && widget.onClose != null) {
            hapticLight();
            widget.onClose!();
          }
        },
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Шапка ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(children: [
                  Text('📋 Календарь',
                      style: TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w900, color: textColor)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { hapticLight(); widget.onClose?.call(); },
                    child: Icon(Icons.close, color: textColor.withOpacity(0.4)),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Календарь ──────────────────────────────────────
              SizedBox(
                height: 76,
                child: ListView.builder(
                  controller: _calendarController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 365 * 10,
                  itemBuilder: (_, i) {
                    final date = DateTime(now.year - 5).add(Duration(days: i));
                    final isSelected = dateKey(date) == dateKey(_selectedDate);
                    final isTodayItem = dateKey(date) == dateKey(now);
                    final hasPlans = _hasPlans(date);

                    return GestureDetector(
                      onTap: () {
                        hapticLight();
                        setState(() => _selectedDate = date);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          // Жёлтая обводка для сегодня — ВСЕГДА, выбран или нет
                          border: isTodayItem
                              ? Border.all(color: const Color(0xFFFFD700), width: 2)
                              : isSelected && !isTodayItem
                                  ? Border.all(color: accent, width: 2)
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekdayShort[date.weekday - 1],
                              style: TextStyle(fontSize: 10,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.7)
                                      : textColor.withOpacity(0.45)),
                            ),
                            const SizedBox(height: 3),
                            Text('${date.day}',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : textColor)),
                            Container(
                              width: 4, height: 4,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                color: hasPlans
                                    ? (isSelected
                                        ? Colors.white.withOpacity(0.7)
                                        : accent)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Список планов ─────────────────────────────────
              Expanded(
                child: GestureDetector(
                  // Свайп вправо = предыдущий день, влево = следующий
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v > 300) {
                      hapticLight();
                      setState(() => _selectedDate =
                          _selectedDate.subtract(const Duration(days: 1)));
                      _scrollCalendarToSelected();
                    } else if (v < -300) {
                      hapticLight();
                      setState(() => _selectedDate =
                          _selectedDate.add(const Duration(days: 1)));
                      _scrollCalendarToSelected();
                    }
                  },
                  child: _selectedPlans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📋', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text('Нет планов на этот день',
                                style: TextStyle(fontSize: 16,
                                    color: textColor.withOpacity(0.5))),
                            const SizedBox(height: 8),
                            Text('Нажми + чтобы добавить',
                                style: TextStyle(fontSize: 13,
                                    color: textColor.withOpacity(0.3))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _selectedPlans.length,
                        itemBuilder: (_, i) {
                          final plan = _selectedPlans[i];
                          final done = plan['done'] as bool? ?? false;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: done
                                  ? Border.all(
                                      color: accent.withOpacity(0.2))
                                  : null,
                            ),
                            child: Row(children: [
                              GestureDetector(
                                onTap: () => _toggleDone(key, i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: done ? accent : Colors.transparent,
                                    border: Border.all(
                                        color: done
                                            ? accent
                                            : textColor.withOpacity(0.3),
                                        width: 2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: done
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(plan['text'] as String,
                                        style: TextStyle(fontSize: 15,
                                            color: done
                                                ? textColor.withOpacity(0.35)
                                                : textColor,
                                            decoration: done
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor:
                                                textColor.withOpacity(0.35))),
                                    if (plan['time'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.access_time_rounded,
                                            size: 12,
                                            color: accent.withOpacity(0.7)),
                                        const SizedBox(width: 4),
                                        Text(plan['time'] as String,
                                            style: TextStyle(fontSize: 12,
                                                color: accent.withOpacity(0.7),
                                                fontWeight: FontWeight.w600)),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _deletePlan(key, i),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline_rounded,
                                      size: 20,
                                      color: textColor.withOpacity(0.25)),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
                  ), // GestureDetector
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPlan,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// _AddPlanSheet — модальный листок добавления плана
// ════════════════════════════════════════════════════
class _AddPlanSheet extends StatefulWidget {
  final Color accent;
  final Future<void> Function(String text, TimeOfDay time) onSetAlarm;
  final void Function(String text, TimeOfDay? time) onSubmit;

  const _AddPlanSheet({
    required this.accent,
    required this.onSetAlarm,
    required this.onSubmit,
  });

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _textController = TextEditingController();
  TimeOfDay? _time;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String? get _timeLabel => _time == null
      ? null
      : '${_time!.hour.toString().padLeft(2, '0')}:'
        '${_time!.minute.toString().padLeft(2, '0')}';

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    hapticMedium();
    Navigator.pop(context);
    widget.onSubmit(text, _time);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface   = Theme.of(context).colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Новый план',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: onSurface)),
          const SizedBox(height: 16),

          // ── Текст плана ───────────────────────────────
          TextField(
            controller: _textController,
            autofocus: true,
            style: TextStyle(fontSize: 16, color: onSurface),
            decoration: InputDecoration(
              hintText: 'Что планируешь?',
              hintStyle: TextStyle(color: onSurface.withOpacity(0.4)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),

          // ── Выбор времени ─────────────────────────────
          GestureDetector(
            onTap: () async {
              hapticLight();
              final picked = await showTimePicker(
                  context: context, initialTime: TimeOfDay.now());
              if (picked != null) {
                hapticMedium();
                setState(() => _time = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: surface, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.access_time,
                    color: _time != null
                        ? widget.accent
                        : onSurface.withOpacity(0.4),
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _timeLabel ?? 'Добавить время (необязательно)',
                    style: TextStyle(fontSize: 15,
                        color: _time != null
                            ? onSurface
                            : onSurface.withOpacity(0.4)),
                  ),
                ),
                if (_time != null)
                  GestureDetector(
                    onTap: () { hapticLight(); setState(() => _time = null); },
                    child: Icon(Icons.close, size: 16,
                        color: onSurface.withOpacity(0.4)),
                  ),
              ]),
            ),
          ),

          // ── Добавить в будильник (если время выбрано) ─
          if (_time != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  hapticMedium();
                  widget.onSetAlarm(text, _time!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.alarm, color: widget.accent, size: 20),
                  const SizedBox(width: 10),
                  Text('Добавить в будильник',
                      style: TextStyle(fontSize: 15,
                          color: widget.accent, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Кнопка добавить ───────────────────────────
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Добавить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
