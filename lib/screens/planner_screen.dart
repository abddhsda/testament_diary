// ════════════════════════════════════════════════════
// screens/planner_screen.dart — экран планировщика
//
// Свайп влево с HomeScreen → этот экран.
// Функционал: добавление планов, выбор времени,
//             уведомления, будильник (Android MethodChannel),
//             повторяющиеся напоминания, чекбоксы, удаление,
//             навигация по датам с точками на датах с планами.
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app.dart';
import 'package:mindful_diary/notifications.dart' as notif;

class PlannerScreen extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> allPlans;
  final Future<void> Function(String key, List<Map<String, dynamic>> plans) onSave;

  const PlannerScreen({
    super.key,
    required this.allPlans,
    required this.onSave,
  });

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  late Map<String, List<Map<String, dynamic>>> _allPlans;

  // Android: будильник
  static const _alarmChannel = MethodChannel('com.example.mindful_diary/alarm');

  @override
  void initState() {
    super.initState();
    _allPlans = Map.from(widget.allPlans);
  }

  // ─── Утилиты ──────────────────────────────────────────────────
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> get _selectedPlans =>
      _allPlans[_dateKey(_selectedDate)] ?? [];

  bool _hasPlans(DateTime d) =>
      (_allPlans[_dateKey(d)] ?? []).isNotEmpty;

  // ─── Добавление плана ─────────────────────────────────────────
  void _addPlan() {
    final textController = TextEditingController();
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Text('Новый план',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 16),

              // Поле текста
              TextField(
                controller: textController,
                autofocus: true,
                style: TextStyle(fontSize: 16,
                    color: Theme.of(ctx).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Что планируешь?',
                  hintStyle: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(ctx).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),

              // Выбор времени
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) setModalState(() => selectedTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.access_time,
                        color: selectedTime != null
                            ? AppSettings.of(context).accent
                            : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4),
                        size: 20),
                    const SizedBox(width: 10),
                    Text(
                      selectedTime != null
                          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:'
                            '${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Добавить время (необязательно)',
                      style: TextStyle(
                        fontSize: 15,
                        color: selectedTime != null
                            ? Theme.of(ctx).colorScheme.onSurface
                            : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    if (selectedTime != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setModalState(() => selectedTime = null),
                        child: Icon(Icons.close, size: 16,
                            color: Theme.of(ctx).colorScheme.onSurface
                                .withOpacity(0.4)),
                      ),
                    ],
                  ]),
                ),
              ),

              // Кнопка "добавить в будильник" (только если выбрано время)
              if (selectedTime != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    final text = textController.text.trim();
                    if (text.isNotEmpty && selectedTime != null) {
                      _setAlarm(text, selectedTime!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.alarm,
                          color: AppSettings.of(context).accent, size: 20),
                      const SizedBox(width: 10),
                      Text('Добавить в будильник',
                          style: TextStyle(fontSize: 15,
                              color: AppSettings.of(context).accent,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Кнопка сохранения
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final text = textController.text.trim();
                    if (text.isEmpty) return;
                    final plan = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'text': text,
                      'time': selectedTime != null
                          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:'
                            '${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : null,
                      'done': false,
                    };
                    final key = _dateKey(_selectedDate);
                    final plans =
                        List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
                    plans.add(plan);
                    setState(() => _allPlans[key] = plans);
                    widget.onSave(key, plans);
                    Navigator.pop(ctx);
                    _schedulePlanNotification(plan);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppSettings.of(context).accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Добавить',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Уведомление о плане ──────────────────────────────────────
  void _schedulePlanNotification(Map<String, dynamic> plan) async {
    if (plan['time'] == null) return;
    final parts = (plan['time'] as String).split(':');
    final hour   = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final scheduled = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
    await notif.schedulePlanReminder(
        plan['id'] as String, plan['text'] as String, scheduled);
  }

  // ─── Android будильник ────────────────────────────────────────
  Future<void> _setAlarm(String text, TimeOfDay time) async {
    try {
      await _alarmChannel.invokeMethod('setAlarm', {
        'hour': time.hour,
        'minute': time.minute,
        'message': text,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть будильник')),
        );
      }
    }
  }

  // ─── Чекбокс ─────────────────────────────────────────────────
  void _toggleDone(String key, int index) {
    final plans = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
    plans[index] = {...plans[index], 'done': !(plans[index]['done'] as bool)};
    setState(() => _allPlans[key] = plans);
    widget.onSave(key, plans);
  }

  // ─── Удаление ─────────────────────────────────────────────────
  void _deletePlan(String key, int index) {
    final plans = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
    plans.removeAt(index);
    setState(() => _allPlans[key] = plans);
    widget.onSave(key, plans);
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final isDark    = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final key       = _dateKey(_selectedDate);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          // ── Шапка ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back, color: textColor),
              ),
              const SizedBox(width: 16),
              Text('Планировщик',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w900, color: textColor)),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Горизонтальный выбор даты ─────────────────────────
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 14,
              itemBuilder: (_, i) {
                final day = DateTime.now()
                    .subtract(Duration(days: 3))
                    .add(Duration(days: i));
                final isSelected = _dateKey(day) == _dateKey(_selectedDate);
                final isToday    = _dateKey(day) == _dateKey(DateTime.now());
                final hasPlans   = _hasPlans(day);

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = day),
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: isToday && !isSelected
                          ? Border.all(color: accent.withOpacity(0.5))
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ['Пн','Вт','Ср','Чт','Пт','Сб','Вс']
                              [day.weekday - 1],
                          style: TextStyle(fontSize: 11,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.7)
                                  : textColor.withOpacity(0.5)),
                        ),
                        Text('${day.day}',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : textColor)),
                        // Точка если есть планы
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: hasPlans
                                ? (isSelected
                                    ? Colors.white.withOpacity(0.6)
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

          // ── Список планов ─────────────────────────────────────
          Expanded(
            child: _selectedPlans.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📋', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text('Планов нет',
                          style: TextStyle(fontSize: 18,
                              fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 8),
                      Text('Нажми + чтобы добавить',
                          style: TextStyle(color: textColor.withOpacity(0.4))),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _selectedPlans.length,
                    itemBuilder: (_, i) {
                      final plan = _selectedPlans[i];
                      final done = plan['done'] as bool? ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: done
                              ? Border.all(
                                  color: Colors.green.withOpacity(0.3))
                              : null,
                        ),
                        child: Row(children: [
                          // Чекбокс
                          GestureDetector(
                            onTap: () => _toggleDone(key, i),
                            child: Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: done ? Colors.green : Colors.transparent,
                                border: Border.all(
                                  color: done ? Colors.green
                                      : textColor.withOpacity(0.3),
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: done
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Текст + время
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan['text'] as String,
                                    style: TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: done
                                            ? textColor.withOpacity(0.4)
                                            : textColor,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null)),
                                if (plan['time'] != null) ...[
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Icon(Icons.access_time,
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

                          // Кнопки: повторяющееся уведомление + удалить
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ×3м (повторяющиеся напоминания)
                              if (plan['time'] != null) ...[
                                GestureDetector(
                                  onTap: () async {
                                    final isRepeating =
                                        plan['repeating'] as bool? ?? false;
                                    final plans = List<Map<String, dynamic>>
                                        .from(_allPlans[key] ?? []);
                                    plans[i] = {
                                      ...plans[i],
                                      'repeating': !isRepeating
                                    };
                                    setState(() => _allPlans[key] = plans);
                                    widget.onSave(key, plans);

                                    if (!isRepeating) {
                                      // Включаем: 20 уведомлений каждые 3 минуты
                                      final parts =
                                          (plan['time'] as String).split(':');
                                      final when = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        int.parse(parts[0]),
                                        int.parse(parts[1]),
                                      );
                                      for (int r = 0; r < 20; r++) {
                                        final fireTime =
                                            when.add(Duration(minutes: r * 3));
                                        if (fireTime.isAfter(DateTime.now())) {
                                          await notif.notifications.zonedSchedule(
                                            id: (plan['id'] as String)
                                                    .hashCode + 1000 + r,
                                            title: '📋 Modo — не забудь!',
                                            body: plan['text'] as String,
                                            scheduledDate: tz.TZDateTime
                                                .from(fireTime, tz.local),
                                            notificationDetails:
                                                const NotificationDetails(
                                              android:
                                                  AndroidNotificationDetails(
                                                'repeating_channel',
                                                'Настойчивые напоминания',
                                                channelDescription:
                                                    'Повторяющиеся уведомления',
                                                importance: Importance.high,
                                                priority: Priority.high,
                                              ),
                                            ),
                                            androidScheduleMode:
                                                AndroidScheduleMode
                                                    .exactAllowWhileIdle,
                                          );
                                        }
                                      }
                                    } else {
                                      // Выключаем: отменяем все 20
                                      for (int r = 0; r < 20; r++) {
                                        await notif.notifications.cancel(
                                            (plan['id'] as String).hashCode +
                                                1000 + r);
                                      }
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (plan['repeating'] as bool? ??
                                              false)
                                          ? accent.withOpacity(0.15)
                                          : textColor.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications_active_outlined,
                                          size: 14,
                                          color: (plan['repeating'] as bool? ??
                                                  false)
                                              ? accent
                                              : textColor.withOpacity(0.3),
                                        ),
                                        const SizedBox(width: 4),
                                        Text('×3м',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: (plan['repeating']
                                                          as bool? ??
                                                      false)
                                                  ? accent
                                                  : textColor.withOpacity(0.3),
                                              fontWeight: FontWeight.w600,
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // Удалить
                              GestureDetector(
                                onTap: () => _deletePlan(key, i),
                                child: Icon(Icons.delete_outline,
                                    size: 20,
                                    color: textColor.withOpacity(0.3)),
                              ),
                            ],
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
      // ── FAB: добавить план ──────────────────────────────────────
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
