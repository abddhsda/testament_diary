// ════════════════════════════════════════════════════
// screens/onboarding_screen.dart
//
// SplashOnboarding — 5 слайдов при первом запуске
// OnboardingScreen — выбор категории цели + ввод цели
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../services/notifications.dart' as notif;

// ════════════════════════════════════════════════════
// SplashOnboarding — слайды при первом запуске
// ════════════════════════════════════════════════════
class SplashOnboarding extends StatefulWidget {
  final VoidCallback onDone;
  const SplashOnboarding({super.key, required this.onDone});

  @override
  State<SplashOnboarding> createState() => _SplashOnboardingState();
}

class _SplashOnboardingState extends State<SplashOnboarding> {
  final _controller = PageController();
  int _page = 0;

  // ─── Слайды ───────────────────────────────────────────────────
  static const _slides = [
    {'emoji': '🧭', 'title': 'Modo — твой дневник',
     'sub': 'Каждый день — честный разговор с собой.\nНе для галочки. Для роста.'},
    {'emoji': '💬', 'title': 'Вопросы дня',
     'sub': 'Каждый день новые вопросы под твою цель.\nОтвечай честно — это только для тебя.'},
    {'emoji': '📋', 'title': 'Планировщик',
     'sub': 'Свайп влево с главного экрана.\nДобавляй планы на день, если выберешь время придёт уведомление.'},
    {'emoji': '📊', 'title': 'Статистика',
     'sub': 'Отслеживай энергию, настроение, продуктивность.\nВидь динамику по дням.'},
    {'emoji': '🎨', 'title': 'Твой стиль',
     'sub': 'В настройках меняй тему и акцентный цвет.\nСветлая, тёмная, 4 цвета на выбор.'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          // ── Прогресс-сегменты ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: List.generate(_slides.length, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: i <= _page ? accent : textColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),

          // ── Слайды ───────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              itemBuilder: (_, i) {
                final slide = _slides[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slide['emoji']!, style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 32),
                      Text(slide['title']!,
                          style: TextStyle(fontSize: 28,
                              fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 16),
                      Text(slide['sub']!,
                          style: TextStyle(fontSize: 16,
                              color: textColor.withOpacity(0.6), height: 1.6)),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Кнопки ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut),
                    child: Text('← Назад',
                        style: TextStyle(color: textColor.withOpacity(0.5))),
                  )
                else
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text('Пропустить',
                        style: TextStyle(color: textColor.withOpacity(0.4))),
                  ),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_page < _slides.length - 1) {
                        _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      } else {
                        await notif.initNotifications();
                        widget.onDone();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _page == _slides.length - 1 ? 'Начать →' : 'Далее →',
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// OnboardingScreen — выбор категории + ввод цели
// ════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(String goal, String category) onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = TextEditingController();
  String? _selectedCategory;

  // ─── Категории целей ─────────────────────────────────────────
  static const _categories = [
    {'emoji': '💰', 'title': 'Деньги и бизнес', 'key': 'money'},
    {'emoji': '💪', 'title': 'Здоровье и спорт', 'key': 'health'},
    {'emoji': '📚', 'title': 'Обучение и рост',  'key': 'learning'},
    {'emoji': '❤️', 'title': 'Отношения',         'key': 'relations'},
    {'emoji': '🎯', 'title': 'Карьера',           'key': 'career'},
    {'emoji': '🧘', 'title': 'Mindset',           'key': 'mindset'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent    = AppSettings.of(context).accent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('🧭', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('Добро пожаловать в Modo',
                  style: TextStyle(fontSize: 26,
                      fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text('Каждый день — честный разговор с собой.',
                  style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.5))),

              const SizedBox(height: 32),
              Text('Выбери направление цели',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 12),

              // ── Категории ──────────────────────────────────────
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat['key']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? accent : accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? accent : accent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Text('${cat['emoji']} ${cat['title']}',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : textColor)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),
              Text('Напиши свою цель',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 4),
              Text('Спорт, финансы, образование, что угодно',
                  style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.5))),
              const SizedBox(height: 12),

              // ── Поле ввода цели ─────────────────────────────────
              TextField(
                controller: _controller,
                autofocus: false,
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w700, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Моя цель...',
                  hintStyle: TextStyle(
                      color: textColor.withOpacity(0.3), fontSize: 18),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}), // для обновления кнопки
              ),

              const SizedBox(height: 28),

              // ── Кнопка ─────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _selectedCategory == null ||
                          _controller.text.trim().isEmpty
                      ? null
                      : () => widget.onDone(
                          _controller.text.trim(), _selectedCategory!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('Начать путь →',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
