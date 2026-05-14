// ════════════════════════════════════════════════════
// screens/home_screen.dart
// IndexedStack — bottom nav виден на всех вкладках
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../app.dart';
import '../models/day_data.dart';
import '../logic/daily_logic.dart';
import '../utils/ui_helpers.dart';
import '../utils/date_labels.dart';
import '../services/plan_sync.dart';
import '../widgets/entry_card.dart';
import 'question_screen.dart';
import 'planner_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import 'day_complete_screen.dart';
import '../services/notifications.dart' as notif;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;
  int _streak = 0;
  DateTime _selectedDate = DateTime.now();
  Map<String, DayData> _diary = {};
  Map<String, List<Map<String, dynamic>>> _allPlans = {};
  String _goal = '';
  String _goalCategory = 'money';
  bool _loading = true;
  bool _showOnboarding = false;
  bool _showSplash = false;

  SharedPreferences? _prefs;

  static const _widgetChannel = MethodChannel('com.example.mindful_diary/widget');

  @override
  void initState() {
    super.initState();
    _load();
    _checkWidgetTap();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try { _widgetChannel.invokeMethod('updateWidget'); } catch (_) {}
    }
  }

  Future<void> _checkWidgetTap() async {
    try {
      final open = await _widgetChannel.invokeMethod<bool>('checkOpenPlanner') ?? false;
      final add  = await _widgetChannel.invokeMethod<bool>('checkAddPlan') ?? false;
      if ((open || add) && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _navIndex = 2);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final mergedPlans = await mergePlans(prefs);
    setState(() {
      _diary = DayData.loadFromPrefs(prefs);
      _allPlans = mergedPlans;
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
    // Защита: _prefs инициализируется асинхронно в _load(),
    // поэтому не используем force-unwrap (!)
    final prefs = _prefs;
    if (prefs == null) return;
    await DayData.saveToPrefs(prefs, _diary);
    await prefs.setString('flutter.plans', jsonEncode(_allPlans));
    try { await _widgetChannel.invokeMethod('updateWidget'); } catch (_) {}
  }

  Future<void> _saveGoal(String goal, String category) async {
    final prefs = _prefs!;
    await prefs.setString('goal', goal);
    await prefs.setString('goalCategory', category);
    setState(() { _goal = goal; _goalCategory = category; _showOnboarding = false; });
  }

  int _calcStreak() {
    int streak = 0;
    DateTime day = DateTime.now();
    // Если сегодня ещё не заполнено — считаем серию с вчера
    if (!_diary.containsKey(dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_diary.containsKey(dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DayData? get _selectedDay => _diary[dateKey(_selectedDate)];
  bool _isToday(DateTime d) => dateKey(d) == dateKey(DateTime.now());

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    hapticLight();
    setState(() => _navIndex = index);
  }

  void _goToQuestions() async {
    final daysDiff = DateTime.now().difference(_selectedDate).inDays;
    if (daysDiff > 3 && !AppSettings.of(context).isPremium) {
      hapticMedium();
      _showPremiumDialog();
      return;
    }
    hapticMedium();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder<Map<String, dynamic>>(
        pageBuilder: (_, __, ___) => QuestionScreen(
          existing: _selectedDay?.answers,
          questions: getDailyQuestions(_selectedDate, category: _goalCategory),
          surveyPack: getDailySurveyPack(_selectedDate, category: _goalCategory),
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child),
      ),
    );
    if (result != null) {
      setState(() {
        final key = dateKey(_selectedDate);
        final existing = _diary[key] ?? const DayData();
        final r = result['ratings'] as Map<String, dynamic>?;
        _diary[key] = existing.copyWith(
          answers: result['answers'] as List<String>,
          ratings: r == null ? null : {
            'energy': r['energy'] as int,
            'productivity': r['productivity'] as int,
            'mood': r['mood'] as int,
            'food': r['food'] as int,
            'sleep': r['sleep'] as int,
          },
        );
        _streak = _calcStreak();
      });
      await _save();
      await notif.scheduleNotifications();
      hapticSuccess();
      if (mounted) {
        await Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => DayCompleteScreen(date: _selectedDate),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ));
      }
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
        content: Text('Редактирование записей старше 3 дней доступно только в Premium.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Понял', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); setState(() => _navIndex = 3); },
            style: ElevatedButton.styleFrom(backgroundColor: accent,
                foregroundColor: Colors.white, elevation: 0),
            child: const Text('Настройки'),
          ),
        ],
      ),
    );
  }

  void _editGoal() {
    hapticLight();
    final controller = TextEditingController(text: _goal);
    final accent = AppSettings.of(context).accent;
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
              if (goal.isNotEmpty) { hapticMedium(); _saveGoal(goal, _goalCategory); Navigator.pop(context); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent,
                foregroundColor: Colors.white, elevation: 0),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // Полная перезагрузка данных — вызывается после импорта JSON
  Future<void> _reload() async {
    setState(() => _loading = true);
    await _load();
  }

  PlannerScreen _buildPlannerScreen() => PlannerScreen(
    allPlans: _allPlans,
    onSave: (key, plans) async {
      setState(() => _allPlans[key] = plans);
      await _save();
    },
    onClose: () => setState(() => _navIndex = 0),
  );

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_showSplash) return SplashOnboarding(onDone: () async {
      await _prefs!.setBool('splashSeen', true);
      setState(() => _showSplash = false);
    });
    if (_showOnboarding) return OnboardingScreen(onDone: _saveGoal);

    final accent = AppSettings.of(context).accent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _navIndex,
              children: [

                // ══ 0 — ГЛАВНАЯ ════════════════════
                _HomeTab(
                  goal: _goal,
                  streak: _streak,
                  selectedDate: _selectedDate,
                  selectedDay: _selectedDay,
                  goalCategory: _goalCategory,
                  onEditGoal: _editGoal,
                  onDateChanged: (d) => setState(() => _selectedDate = d),
                  onOpenQuestions: _goToQuestions,
                  onNoteSaved: (text) async {
                    final k = dateKey(_selectedDate);
                    setState(() => _diary[k] =
                        (_diary[k] ?? const DayData()).copyWith(note: text));
                    await _save();
                  },
                  onRatingsSaved: (r) async {
                    final k = dateKey(_selectedDate);
                    setState(() => _diary[k] =
                        (_diary[k] ?? const DayData()).copyWith(ratings: r));
                    await _save();
                  },
                ),

                // ══ 1 — СТАТИСТИКА ═══════════════════════════════════
                StatsScreen(allRatings: {
                  for (final e in _diary.entries) e.key: e.value.ratings,
                }),

                // ══ 2 — ПЛАНИРОВЩИК ══════════════════════════════════
                _buildPlannerScreen(),

                // ══ 3 — НАСТРОЙКИ ════════════════════════════════════
                SettingsScreen(onImported: _reload),

              ],
            ),
          ),

          // Bottom Nav
          _BottomNav(currentIndex: _navIndex, accent: accent, onTap: _onNavTap),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════

// ════════════════════════════════════════════════════
// _HomeTab — вкладка 0: главная страница
// ════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  final String goal;
  final int streak;
  final DateTime selectedDate;
  final DayData? selectedDay;
  final String goalCategory;
  final VoidCallback onEditGoal;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onOpenQuestions;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(Map<String, int>) onRatingsSaved;

  const _HomeTab({
    required this.goal,
    required this.streak,
    required this.selectedDate,
    required this.selectedDay,
    required this.goalCategory,
    required this.onEditGoal,
    required this.onDateChanged,
    required this.onOpenQuestions,
    required this.onNoteSaved,
    required this.onRatingsSaved,
  });

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final isDark    = AppSettings.of(context).themeMode == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final isToday   = _isToday(selectedDate);
    final isFuture  = isFutureDate(selectedDate);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(
              goal: goal, streak: streak,
              accent: accent, textColor: textColor,
              onEditGoal: onEditGoal,
            ),
            const SizedBox(height: 24),
            _DateNavigator(
              selectedDate: selectedDate,
              hasEntry: selectedDay != null,
              accent: accent,
              onChanged: onDateChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _DayCardArea(
                selectedDate: selectedDate,
                selectedDay: selectedDay,
                goalCategory: goalCategory,
                isToday: isToday,
                isFuture: isFuture,
                onOpenQuestions: onOpenQuestions,
                onDateChanged: onDateChanged,
                onNoteSaved: onNoteSaved,
                onRatingsSaved: onRatingsSaved,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  final String goal;
  final int streak;
  final Color accent;
  final Color textColor;
  final VoidCallback onEditGoal;

  const _HomeHeader({
    required this.goal, required this.streak,
    required this.accent, required this.textColor,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) =>
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MODO', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, color: textColor, letterSpacing: 2)),
          if (goal.isNotEmpty)
            GestureDetector(
              onTap: onEditGoal,
              child: Text('→ $goal', style: TextStyle(fontSize: 13,
                  color: accent, fontWeight: FontWeight.w600)),
            ),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: streak > 0 ? accent : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('$streak', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
      ],
    );
}

// ────────────────────────────────────────────────────
class _DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final bool hasEntry;
  final Color accent;
  final ValueChanged<DateTime> onChanged;

  const _DateNavigator({
    required this.selectedDate, required this.hasEntry,
    required this.accent, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isToday  = dateKey(selectedDate) == dateKey(DateTime.now());
    final isFuture = isFutureDate(selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            hapticLight();
            onChanged(selectedDate.subtract(const Duration(days: 1)));
          },
          icon: Icon(Icons.chevron_left, size: 32, color: accent),
        ),
        GestureDetector(
          onTap: () async {
            hapticLight();
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020), lastDate: DateTime(2099),
              locale: const Locale('ru'),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.fromSeed(seedColor: accent)),
                child: child!),
            );
            if (picked != null) { hapticMedium(); onChanged(picked); }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFFFFD700)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isToday
                  ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4),
                      blurRadius: 12, spreadRadius: 2)]
                  : [],
            ),
            child: Row(children: [
              Icon(Icons.calendar_today, size: 16,
                  color: isToday ? const Color(0xFF1A1A1A) : accent),
              const SizedBox(width: 8),
              Text(
                '${weekdayShort[selectedDate.weekday - 1]}, '
                '${selectedDate.day} '
                '${monthShort[selectedDate.month - 1]} '
                '${selectedDate.year}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: isToday ? const Color(0xFF1A1A1A)
                        : Theme.of(context).colorScheme.onSurface),
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
            hapticLight();
            onChanged(selectedDate.add(const Duration(days: 1)));
          } : null,
          icon: Icon(Icons.chevron_right, size: 32,
              color: !isFuture ? accent : Colors.grey.shade300),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────
class _DayCardArea extends StatelessWidget {
  final DateTime selectedDate;
  final DayData? selectedDay;
  final String goalCategory;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onOpenQuestions;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(Map<String, int>) onRatingsSaved;

  const _DayCardArea({
    required this.selectedDate, required this.selectedDay,
    required this.goalCategory, required this.isToday,
    required this.isFuture, required this.onOpenQuestions,
    required this.onDateChanged, required this.onNoteSaved,
    required this.onRatingsSaved,
  });

  @override
  Widget build(BuildContext context) {
    final accent   = AppSettings.of(context).accent;
    final hasEntry = selectedDay != null;

    return GestureDetector(
      onTap: isFuture ? null : () { hapticMedium(); onOpenQuestions(); },
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 300) {
          hapticLight();
          onDateChanged(selectedDate.subtract(const Duration(days: 1)));
        } else if (v < -300) {
          final next = selectedDate.add(const Duration(days: 1));
          if (!isFutureDate(next)) { hapticLight(); onDateChanged(next); }
        }
      },
      child: isFuture
          ? _FutureCard()
          : hasEntry
              ? EntryCard(
                  answers: selectedDay!.answers,
                  dailyQuestions: getDailyQuestions(selectedDate, category: goalCategory),
                  surveyPack: getDailySurveyPack(selectedDate, category: goalCategory),
                  isToday: isToday,
                  note: selectedDay!.note,
                  ratings: selectedDay!.ratings.isEmpty ? null : selectedDay!.ratings,
                  onNoteSaved: onNoteSaved,
                  onRatingsSaved: onRatingsSaved,
                )
              : _EmptyCard(isToday: isToday, accent: accent),
    );
  }
}

// Bottom Navigation Bar
// ════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Color accent;
  final void Function(int) onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bg          = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor   = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final items = [
      (Icons.home_rounded,       'Главная'),
      (Icons.bar_chart_rounded,  'Статистика'),
      (Icons.calendar_month,     'Планы'),
      (Icons.settings_rounded,   'Настройки'),
    ];

    return Container(
      height: 64 + bottomPadding,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: textColor.withOpacity(0.08), width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          children: List.generate(items.length, (i) {
            final isActive = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: isActive
                        ? const Border(top: BorderSide(color: Color(0xFFFFD700), width: 2.5))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, size: 24,
                          color: isActive ? accent : textColor.withOpacity(0.35)),
                      const SizedBox(height: 3),
                      Text(items[i].$2,
                          style: TextStyle(fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive ? accent : textColor.withOpacity(0.35))),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Карточки
// ════════════════════════════════════════════════════
class _FutureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24)),
    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('⏳', style: TextStyle(fontSize: 56)),
      SizedBox(height: 16),
      Text('Этот день ещё впереди',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      SizedBox(height: 8),
      Text('Сначала проживи его 💪', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final bool isToday;
  final Color accent;
  const _EmptyCard({required this.isToday, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: isToday ? Border.all(color: const Color(0xFFFFD700), width: 2) : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(isToday ? '🔥' : '📭', style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(isToday ? 'Как прошёл день?' : 'Запись не сделана',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 8),
        Text(isToday ? 'Нажми чтобы начать' : 'Нажми чтобы заполнить',
            style: TextStyle(color: textColor.withOpacity(0.45), fontSize: 14)),
        const SizedBox(height: 24),
        if (isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Text('Займёт меньше 3 минут',
                style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}
