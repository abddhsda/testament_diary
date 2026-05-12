// ════════════════════════════════════════════════════
// screens/home_screen.dart — главный экран
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../app.dart';
import '../logic/daily_logic.dart';
import '../utils/ui_helpers.dart';
import '../widgets/entry_card.dart';
import 'question_screen.dart';
import 'planner_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import 'day_complete_screen.dart';
import 'package:mindful_diary/notifications.dart' as notif;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streak = 0;
  DateTime _selectedDate = DateTime.now();
  Map<String, List<String>> _allEntries = {};
  Map<String, Map<String, int>> _allRatings = {};
  Map<String, String> _allNotes = {};
  Map<String, List<Map<String, dynamic>>> _allPlans = {};
  String _goal = '';
  String _goalCategory = 'money';
  bool _loading = true;
  bool _showOnboarding = false;
  bool _showSplash = false;

  static const _widgetChannel = MethodChannel('com.example.mindful_diary/widget');

  @override
  void initState() {
    super.initState();
    _load();
    _checkWidgetTap();
  }

  Future<void> _checkWidgetTap() async {
  try {
    final open = await _widgetChannel.invokeMethod<bool>('checkOpenPlanner') ?? false;
    final add  = await _widgetChannel.invokeMethod<bool>('checkAddPlan') ?? false;
    if ((open || add) && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final planner = _buildPlannerScreen();
        await Navigator.push(context, _slideRoute(planner));
        // Если пришли с add=true — планировщик сам откроет bottomsheet
        // (передаётся через PlannerScreen.openAddOnStart)
      }
    }
  } catch (_) {}
}

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allEntries = Map<String, List<String>>.from(
        (jsonDecode(prefs.getString('entries') ?? '{}') as Map)
            .map((k, v) => MapEntry(k, List<String>.from(v))));
      _allRatings = Map<String, Map<String, int>>.from(
        (jsonDecode(prefs.getString('ratings') ?? '{}') as Map)
            .map((k, v) => MapEntry(k, Map<String, int>.from(v))));
      _allNotes = Map<String, String>.from(
          jsonDecode(prefs.getString('notes') ?? '{}') as Map);
      _allPlans = Map<String, List<Map<String, dynamic>>>.from(
        (jsonDecode(prefs.getString('plans') ?? '{}') as Map).map((k, v) =>
            MapEntry(k, List<Map<String, dynamic>>.from(
                (v as List).map((e) => Map<String, dynamic>.from(e))))));
      _streak = _calcStreak();
      _goal = prefs.getString('goal') ?? '';
      _goalCategory = prefs.getString('goalCategory') ?? 'money';
      final splashSeen = prefs.getBool('splashSeen') ?? false;
      _showOnboarding = _goal.isEmpty;
      _showSplash = _goal.isEmpty && !splashSeen;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', jsonEncode(_allEntries));
    await prefs.setString('ratings', jsonEncode(_allRatings));
    await prefs.setString('notes', jsonEncode(_allNotes));
    await prefs.setString('plans', jsonEncode(_allPlans));
    try { await _widgetChannel.invokeMethod('updateWidget'); } catch (_) {}
  }

  Future<void> _saveGoal(String goal, String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goal', goal);
    await prefs.setString('goalCategory', category);
    setState(() { _goal = goal; _goalCategory = category; _showOnboarding = false; });
  }

  int _calcStreak() {
    int streak = 0;
    DateTime day = DateTime.now();
    while (_allEntries.containsKey(_dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<String>? get _selectedEntries => _allEntries[_dateKey(_selectedDate)];
  bool _isToday(DateTime d) => _dateKey(d) == _dateKey(DateTime.now());
  bool _isFuture(DateTime d) {
    final t = DateTime.now();
    return d.year > t.year || (d.year == t.year && d.month > t.month) ||
        (d.year == t.year && d.month == t.month && d.day > t.day);
  }

  void _goToQuestions() async {
    final daysDiff = DateTime.now().difference(_selectedDate).inDays;
    if (daysDiff > 3 && !AppSettings.of(context).isPremium) {
      hapticMedium();
      _showPremiumDialog();
      return;
    }
    hapticMedium(); // нажатие кнопки "Начать запись"
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      _slideUpRoute(QuestionScreen(
        existing: _selectedEntries,
        questions: getDailyQuestions(_selectedDate, category: _goalCategory),
        surveyPack: getDailySurveyPack(_selectedDate, category: _goalCategory),
      )),
    );
    if (result != null) {
      setState(() {
        _allEntries[_dateKey(_selectedDate)] = result['answers'];
        if (result['ratings'] != null) {
          final r = result['ratings'] as Map<String, dynamic>;
          _allRatings[_dateKey(_selectedDate)] = {
            'energy': r['energy'] as int, 'productivity': r['productivity'] as int,
            'mood': r['mood'] as int, 'food': r['food'] as int, 'sleep': r['sleep'] as int,
          };
        }
        _streak = _calcStreak();
      });
      await _save();
      await notif.scheduleNotifications();
      hapticSuccess(); // успешное сохранение
      if (mounted) await Navigator.push(context, _fadeRoute(DayCompleteScreen(date: _selectedDate)));
    }
  }

  void _showPremiumDialog() {
    final accent = AppSettings.of(context).accent;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Premium', style: TextStyle(fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Редактирование записей старше 3 дней доступно только в Premium.\n\nВведи код активации в настройках.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Понял', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  void _editGoal() {
    hapticLight(); // открытие диалога
    final controller = TextEditingController(text: _goal);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Изменить цель', style: TextStyle(fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller, autofocus: true,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface),
          decoration: const InputDecoration(border: InputBorder.none,
              hintText: 'Твоя цель...', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final goal = controller.text.trim();
              if (goal.isNotEmpty) {
                hapticMedium(); // сохранение цели
                _saveGoal(goal, _goalCategory);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white, elevation: 0),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  PlannerScreen _buildPlannerScreen() => PlannerScreen(
    allPlans: _allPlans,
    onSave: (key, plans) async { setState(() => _allPlans[key] = plans); await _save(); },
  );

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  );

  PageRoute<Map<String, dynamic>> _slideUpRoute(Widget page) =>
      PageRouteBuilder<Map<String, dynamic>>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  );

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_showSplash) return SplashOnboarding(onDone: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('splashSeen', true);
      setState(() => _showSplash = false);
    });
    if (_showOnboarding) return OnboardingScreen(onDone: _saveGoal);

    final hasEntry = _selectedEntries != null;
    final isToday  = _isToday(_selectedDate);
    final isFuture = _isFuture(_selectedDate);
    final accent   = AppSettings.of(context).accent;
    final isDark   = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
            hapticLight(); // свайп влево → Planner
            Navigator.push(context, _slideRoute(_buildPlannerScreen()));
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('MODO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                          color: textColor, letterSpacing: 2)),
                      if (_goal.isNotEmpty)
                        GestureDetector(onTap: _editGoal,
                          child: Text('→ $_goal', style: TextStyle(fontSize: 13,
                              color: accent, fontWeight: FontWeight.w600))),
                    ]),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _streak > 0 ? accent : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_streak', style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          hapticLight(); // переход в статистику
                          Navigator.push(context, _slideRoute(StatsScreen(allRatings: _allRatings)));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: textColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.bar_chart, color: textColor, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          hapticLight(); // переход в настройки
                          Navigator.push(context, _slideRoute(const SettingsScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: textColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.more_vert, color: textColor, size: 20),
                        ),
                      ),
                    ]),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Date switcher ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        hapticLight(); // смена даты назад
                        setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                      },
                      icon: Icon(Icons.chevron_left, size: 32, color: accent),
                    ),
                    GestureDetector(
                      onTap: () async {
                        hapticLight(); // открытие датапикера
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020), lastDate: DateTime(2099),
                          locale: const Locale('ru'),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFFE8927C), onPrimary: Colors.white,
                                surface: Color(0xFFFDF6F0))),
                            child: child!),
                        );
                        if (picked != null) {
                          hapticMedium(); // выбор даты
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isToday ? const Color(0xFFFFD700) : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isToday
                              ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]
                              : [],
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today, size: 16,
                              color: isToday ? const Color(0xFF1A1A1A) : accent),
                          const SizedBox(width: 8),
                          Text(
                            '${['Пн','Вт','Ср','Чт','Пт','Сб','Вс'][_selectedDate.weekday - 1]}, '
                            '${_selectedDate.day} '
                            '${['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'][_selectedDate.month - 1]} '
                            '${_selectedDate.year}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                color: isToday ? const Color(0xFF1A1A1A) : Theme.of(context).colorScheme.onSurface),
                          ),
                          if (hasEntry) ...[
                            const SizedBox(width: 8),
                            Container(width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: isToday ? const Color(0xFF1A1A1A) : accent,
                                    shape: BoxShape.circle)),
                          ],
                        ]),
                      ),
                    ),
                    IconButton(
                      onPressed: !isFuture ? () {
                        hapticLight(); // смена даты вперёд
                        setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                      } : null,
                      icon: Icon(Icons.chevron_right, size: 32,
                          color: !isFuture ? accent : Colors.grey.shade300),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Entry card ──
                Expanded(
                  child: isFuture
                      ? _FutureCard()
                      : hasEntry
                          ? EntryCard(
                              answers: _selectedEntries!,
                              dailyQuestions: getDailyQuestions(_selectedDate, category: _goalCategory),
                              surveyPack: getDailySurveyPack(_selectedDate, category: _goalCategory),
                              isToday: isToday,
                              note: _allNotes[_dateKey(_selectedDate)] ?? '',
                              onNoteSaved: (text) async {
                                setState(() => _allNotes[_dateKey(_selectedDate)] = text);
                                await _save();
                              },
                            )
                          : _EmptyCard(isToday: isToday),
                ),

                const SizedBox(height: 20),

                if (!isFuture)
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _goToQuestions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0),
                      child: Text(hasEntry ? '✏️ Редактировать' : '🔥 Начать запись дня',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FutureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24)),
    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('⏳', style: TextStyle(fontSize: 48)),
      SizedBox(height: 16),
      Text('Этот день ещё впереди', style: TextStyle(fontSize: 18)),
      SizedBox(height: 8),
      Text('Сначала проживи его 💪', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final bool isToday;
  const _EmptyCard({required this.isToday});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: isToday ? Border.all(color: const Color(0xFFFFD700), width: 2) : null),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(isToday ? '🔥' : '📭', style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text(isToday ? 'Как прошёл день?' : 'Запись не сделана',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 8),
      Text(isToday ? 'Займёт меньше 3 минут' : 'Можешь заполнить задним числом',
          style: const TextStyle(color: Colors.grey)),
    ]),
  );
}
