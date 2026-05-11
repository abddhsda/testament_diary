// ════════════════════════════════════════════════════
// screens/settings_screen.dart — экран настроек
//
// Секции: Тема (light/dark), Акцентный цвет (4 варианта),
//         Premium (ввод промокода), Скоро (заглушки)
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../widgets/premium_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings  = AppSettings.of(context);
    final isDark    = settings.themeMode == ThemeMode.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Шапка ──────────────────────────────────────────
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textColor),
                  ),
                  const SizedBox(width: 16),
                  Text('Настройки',
                      style: TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w900, color: textColor)),
                ]),

                const SizedBox(height: 32),

                // ── Тема ───────────────────────────────────────────
                _sectionLabel('Тема', textColor),
                const SizedBox(height: 12),
                _ThemeToggle(isDark: isDark, settings: settings),

                const SizedBox(height: 32),

                // ── Акцентный цвет ─────────────────────────────────
                _sectionLabel('Акцентный цвет', textColor),
                const SizedBox(height: 12),
                ...List.generate(AppColors.accents.length, (i) =>
                    _AccentRow(
                      color: AppColors.accents[i],
                      name: AppColors.accentNames[i],
                      isSelected: settings.accent == AppColors.accents[i],
                      onTap: () => settings.setAccent(AppColors.accents[i]),
                    )),

                const SizedBox(height: 32),

                // ── Premium ────────────────────────────────────────
                _sectionLabel('Premium', textColor),
                const SizedBox(height: 12),
                const PremiumSection(),

                const SizedBox(height: 32),

                // ── Скоро ──────────────────────────────────────────
                _sectionLabel('Скоро', textColor),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    _futureItem(context, Icons.notifications_outlined,
                        'Время уведомлений', textColor),
                    Divider(height: 1, indent: 56,
                        color: textColor.withOpacity(0.1)),
                    _futureItem(context, Icons.download_outlined,
                        'Экспорт данных', textColor),
                    Divider(height: 1, indent: 56,
                        color: textColor.withOpacity(0.1)),
                    _futureItem(context, Icons.info_outline,
                        'О приложении', textColor),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Заголовок секции ──────────────────────────────────────────
  Widget _sectionLabel(String label, Color textColor) =>
      Text(label, style: TextStyle(fontSize: 13,
          color: textColor.withOpacity(0.5),
          fontWeight: FontWeight.w600, letterSpacing: 1));

  // ─── Строка "скоро" ────────────────────────────────────────────
  Widget _futureItem(BuildContext ctx, IconData icon, String label, Color textColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: textColor.withOpacity(0.4), size: 22),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.4))),
          const Spacer(),
          Icon(Icons.chevron_right, color: textColor.withOpacity(0.2)),
        ]),
      );
}

// ─── Переключатель темы light / dark ──────────────────────────
class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final AppSettings settings;
  const _ThemeToggle({required this.isDark, required this.settings});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        // ☀️ Светлая
        Expanded(child: GestureDetector(
          onTap: () => settings.setTheme(ThemeMode.light),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: !isDark ? settings.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text('☀️ Светлая',
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: !isDark ? Colors.white : textColor))),
          ),
        )),
        // 🌙 Тёмная
        Expanded(child: GestureDetector(
          onTap: () => settings.setTheme(ThemeMode.dark),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? settings.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text('🌙 Тёмная',
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : textColor))),
          ),
        )),
      ]),
    );
  }
}

// ─── Строка акцентного цвета ──────────────────────────────────
class _AccentRow extends StatelessWidget {
  final Color color;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  const _AccentRow({required this.color, required this.name,
      required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(children: [
          // Цветной кружок
          Container(width: 24, height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Text(name, style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w600, color: textColor)),
          const Spacer(),
          if (isSelected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}
