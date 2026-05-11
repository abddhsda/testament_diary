// ════════════════════════════════════════════════════
// screens/home_screen.dart — главный экран
//
// Отображает: заголовок + стрик, выбор даты, карточку дня,
//             кнопку "Начать запись"
// Свайп влево → PlannerScreen
// Виджет Android → _checkWidgetTap()
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../app.dart';
import '../logic/daily_logic.dart';
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
  // ─── Состояние ────────────────────────────────────────────────
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
  bool _isPremium = false;

  // ─── Platform channels ────────────────────────────────────────
  // Android: виджет рабочего стола + будильник
  static const _widgetChannel  = MethodChannel('com.example.mindful_diary/widget');
  static const _alarmChannel   = MethodChannel('com.example.mindful_diary/alarm'); // используется в PlannerScreen

  // ─── Lifecycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
    _checkWidgetTap(); // Android: открыть плanner если тапнули виджет
  }

  // ─── Android widget tap ───────────────────────────────────────
  Future<void> _checkWidgetTap() async {
    try {
      final result = await _widgetChannel.invokeMethod<bool>('checkOpenPlanner');
      if (result == true && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.push(context, _slideRoute(_buildPlannerScreen()));
        }
      }
    } catch (_) {}
  }

  // ─── Загрузка данных из SharedPreferences ─────────────────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw         = prefs.getString('entries') ?? '{}';
    final ratingsRaw  = prefs.getString('ratings') ?? '{}';
    final notesRaw    = prefs.getString('notes')   ?? '{}';
    final plansRaw    = prefs.getString('plans')   ?? '{}';
    final goal        = prefs.getString('goal')    ?? '';
    final goalCategory = prefs.getString('goalCategory') ?? 'money';
    final isPremium   = prefs.getBool('isPremium') ?? false;
    final splashSeen  = prefs.getBool('splashSeen') ?? false;

    setState(() {
      _allEntries = _decodeEntries(raw);
      _allRatings = _decodeRatings(ratingsRaw);
      _allNotes   = Map<String, String>.from(jsonDecode(notesRaw) as Map);
      _allPlans   = _decodePlans(plansRaw);
      _streak     = _calcStreak();
      _goal       = goal;
      _goalCategory = goalCategory;
      _isPremium  = isPremium;
      _showOnboarding = goal.isEmpty;
      _showSplash = goal.isEmpty && !splashSeen;
      _loading    = false;
    });
  }

  // ─── Сохранение данных ────────────────────────────────────────
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', jsonEncode(_allEntries));
    await prefs.setString('ratings', jsonEncode(_allRatings));
    await prefs.setString('notes',   jsonEncode(_allNotes));
    await prefs.setString('plans',   jsonEncode(_allPlans));
    // Обновляем Android-виджет рабочего стола
    try { await _widgetChannel.invokeMethod('updateWidget'); } catch (_) {}
  }

  // ─── Сохранение цели (из онбординга и диалога редактирования) ─
  Future<void> _saveGoal(String goal, String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goal', goal);
    await prefs.setString('goalCategory', category);
    setState(() {
      _goal = goal;
      _goalCategory = category;
      _showOnboarding = false;
    });
  }

  // ─── Supabase: активация промокода ───────────────────────────
  // (вынесено в HomeScreen т.к. нужен setState для _isPremium)
  Future<void> _activateCode(String code) async {
    // TODO: вынести URL и ключ в отдельный config/secrets файл
    const supabaseUrl  = 'https://vfbjtqjpkjcjceodlzbt.supabase.co/rest/v1/promo_codes';
    const supabaseKey  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmYmp0cWpwa2pjamNlb2RsemJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNTg2NjIsImV4cCI6MjA5MzkzNDY2Mn0.pyJs02GZ6joGUzHE4FYD7EAwqlHvuOrEdg_B4ztUeaA';
    final headers = {
      'apikey': supabaseKey,
      'Authorization': 'Bearer $supabaseKey',
      'Content-Type': 'application/json',
    };

    try {
      final checkResponse = await _httpGet('$supabaseUrl?code=eq.$code&is_used=eq.false', headers);
      final data = jsonDecode(checkResponse) as List;
      if (data.isEmpty) {
        _showSnack('Код недействителен или уже использован');
        return;
      }
      final id = data[0]['id'];
      await _httpPatch('$supabaseUrl?id=eq.$id', headers,
          jsonEncode({'is_used': true, 'used_at': DateTime.now().toIso8601String()}));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPremium', true);
      setState(() => _isPremium = true);
      _showSnack('🔥 Premium активирован!');
    } catch (_) {
      _showSnack('Ошибка соединения. Проверь интернет.');
    }
  }

  // ─── Вспомогательные: HTTP ────────────────────────────────────
  // Используем стандартный http пакет (импортирован в pubspec)
  Future<String> _httpGet(String url, Map<String, String> headers) async {
    // ignore: avoid_relative_lib_imports — реальный импорт в pubspec
    final uri = Uri.parse(url);
    // Используем http пакет как в оригинальном коде
    // Этот метод — обёртка для читаемости
    throw UnimplementedError('Вставить import http и использовать http.get');
  }

  Future<void> _httpPatch(String url, Map<String, String> headers, String body) async {
    throw UnimplementedError('Вставить import http и использовать http.patch');
  }

  // ─── Snackbar helper ──────────────────────────────────────────
  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Стрик: кол-во последовательных дней с записью ───────────
  int _calcStreak() {
    int streak = 0;
    DateTime day = DateTime.now();
    while (true) {
      if (_allEntries.containsKey(_dateKey(day))) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // ─── Утилиты ──────────────────────────────────────────────────
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<String>? get _selectedEntries => _allEntries[_dateKey(_selectedDate)];

  bool _isToday(DateTime d) => _dateKey(d) == _dateKey(DateTime.now());

  bool _isFuture(DateTime d) {
    final today = DateTime.now();
    return d.year > today.year ||
        (d.year == today.year && d.month > today.month) ||
        (d.year == today.year && d.month == today.month && d.day > today.day);
  }

  // ─── Навигация к вопросам дня ─────────────────────────────────
  void _goToQuestions() async {
    final daysDiff = DateTime.now().difference(_selectedDate).inDays;
    // Premium gate: записи старше 3 дней только для Premium
    if (daysDiff > 3 && !AppSettings.of(context).isPremium) {
      _showPremiumDialog();
      return;
    }

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
            'energy':       r['energy'] as int,
            'productivity': r['productivity'] as int,
            'mood':         r['mood'] as int,
            'food':         r['food'] as int,
            'sleep':        r['sleep'] as int,
          };
        }
        _streak = _calcStreak();
      });
      await _save();
      await notif.scheduleNotifications();
      if (mounted) {
        await Navigator.push(context, _fadeRoute(DayCompleteScreen(date: _selectedDate)));
      }
    }
  }

  void _showPremiumDialog() {
    final accent = AppSettings.of(context).accent;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Premium',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
            'Редактирование записей старше 3 дней доступно только в Premium.\n\nВведи код активации в настройках.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Понял', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  // ─── Диалог редактирования цели ───────────────────────────────
  void _editGoal() {
    final controller = TextEditingController(text: _goal);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Изменить цель',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface),
          decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Твоя цель...',
              hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final goal = controller.text.trim();
              if (goal.isNotEmpty) { _saveGoal(goal, _goalCategory); Navigator.pop(context); }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white, elevation: 0),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // ─── Переходы (animations) ────────────────────────────────────
  PlannerScreen _buildPlannerScreen() => PlannerScreen(
    allPlans: _allPlans,
    onSave: (key, plans) async {
      setState(() => _allPlans[key] = plans);
      await _save();
    },
  );

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );

  PageRoute<Map<String, dynamic>> _slideUpRoute(Widget page) =>
      PageRouteBuilder<Map<String, dynamic>>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Состояния загрузки / онбординга
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
        // Свайп влево → Planner
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) {
            Navigator.push(context, _slideRoute(_buildPlannerScreen()));
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Заголовок: логотип + цель + стрик + иконки ──
                _buildHeader(accent, textColor),

                const SizedBox(height: 32),

                // ── Переключатель даты ───────────────────────────
                _buildDateSwitcher(accent),

                const SizedBox(height: 24),

                // ── Карточка дня (пустая / запись / будущее) ────
                Expanded(child: _buildDayCard(hasEntry, isToday, isFuture)),

                const SizedBox(height: 16),

                // ── Кнопка записи (не для будущего) ─────────────
                if (!isFuture) _buildActionButton(hasEntry, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Шапка ────────────────────────────────────────────────────
  Widget _buildHeader(Color accent, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Логотип + цель
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MODO',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                    color: textColor, letterSpacing: 2)),
            if (_goal.isNotEmpty)
              GestureDetector(
                onTap: _editGoal,
                child: Text('→ $_goal',
                    style: TextStyle(fontSize: 13, color: accent,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        // Правая часть: стрик + статистика + настройки
        Row(
          children: [
            _buildStreakBadge(accent, textColor),
            const SizedBox(width: 8),
            _buildIconBtn(Icons.bar_chart, textColor,
                () => Navigator.push(context,
                    _slideRoute(StatsScreen(allRatings: _allRatings)))),
            const SizedBox(width: 8),
            _buildIconBtn(Icons.more_vert, textColor,
                () => Navigator.push(context, _slideRoute(const SettingsScreen()))),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakBadge(Color accent, Color textColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _streak > 0 ? accent : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Text('🔥', style: TextStyle(fontSize: 14)),
      const SizedBox(width: 4),
      Text('$_streak',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );

  Widget _buildIconBtn(IconData icon, Color textColor, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: textColor, size: 20),
        ),
      );

  // ─── Выбор даты ───────────────────────────────────────────────
  Widget _buildDateSwitcher(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => setState(() =>
              _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          icon: Icon(Icons.chevron_left, size: 32, color: accent),
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2099),
              locale: const Locale('ru'),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Text(
            _isToday(_selectedDate)
                ? 'Сегодня'
                : '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          onPressed: _isFuture(_selectedDate.add(const Duration(days: 1)))
              ? null
              : () => setState(() =>
                  _selectedDate = _selectedDate.add(const Duration(days: 1))),
          icon: Icon(Icons.chevron_right, size: 32, color: accent),
        ),
      ],
    );
  }

  // ─── Карточка дня ─────────────────────────────────────────────
  Widget _buildDayCard(bool hasEntry, bool isToday, bool isFuture) {
    if (isFuture) return _FutureCard();
    if (!hasEntry) return _EmptyCard(isToday: isToday);

    return EntryCard(
      answers: _selectedEntries!,
      dailyQuestions: getDailyQuestions(_selectedDate, category: _goalCategory),
      surveyPack: getDailySurveyPack(_selectedDate, category: _goalCategory),
      isToday: isToday,
      note: _allNotes[_dateKey(_selectedDate)] ?? '',
      onNoteSaved: (text) async {
        setState(() => _allNotes[_dateKey(_selectedDate)] = text);
        await _save();
      },
    );
  }

  // ─── Кнопка действия ──────────────────────────────────────────
  Widget _buildActionButton(bool hasEntry, Color accent) => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: _goToQuestions,
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: Text(
        hasEntry ? '✏️ Редактировать' : '🔥 Начать запись дня',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );

  // ─── Декодирование JSON ───────────────────────────────────────
  static Map<String, List<String>> _decodeEntries(String raw) =>
      Map<String, List<String>>.from(
        (jsonDecode(raw) as Map).map((k, v) => MapEntry(k, List<String>.from(v))));

  static Map<String, Map<String, int>> _decodeRatings(String raw) =>
      Map<String, Map<String, int>>.from(
        (jsonDecode(raw) as Map).map((k, v) => MapEntry(k, Map<String, int>.from(v))));

  static Map<String, List<Map<String, dynamic>>> _decodePlans(String raw) =>
      Map<String, List<Map<String, dynamic>>>.from(
        (jsonDecode(raw) as Map).map((k, v) => MapEntry(
            k, List<Map<String, dynamic>>.from((v as List).map((e) => Map<String, dynamic>.from(e))))));

  // ─── Название месяца ──────────────────────────────────────────
  static String _monthName(int month) {
    const names = ['января','февраля','марта','апреля','мая','июня',
                   'июля','августа','сентября','октября','ноября','декабря'];
    return names[month - 1];
  }
}

// ════════════════════════════════════════════════════
// Маленькие карточки (используются только внутри HomeScreen)
// ════════════════════════════════════════════════════

class _FutureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24)),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('⏳', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text('Этот день ещё впереди',
              style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Сначала проживи его 💪',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final bool isToday;
  const _EmptyCard({required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        // Золотая рамка для сегодняшнего дня без записи
        border: isToday ? Border.all(color: const Color(0xFFFFD700), width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isToday ? '🔥' : '📭', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            isToday ? 'Как прошёл день?' : 'Запись не сделана',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            isToday ? 'Займёт меньше 3 минут' : 'Можешь заполнить задним числом',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
