// ════════════════════════════════════════════════════
// screens/settings_screen.dart — настройки
// Без стрелки назад — навигация через bottom nav
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';
import '../widgets/premium_section.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatelessWidget {
  /// Вызывается после успешного импорта JSON — перезагружает данные в HomeScreen.
  final Future<void> Function()? onImported;

  const SettingsScreen({super.key, this.onImported});

  @override
  Widget build(BuildContext context) {
    final settings  = AppSettings.of(context);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Заголовок (без стрелки) ────────────────────
                Text('⚙️ Настройки',
                    style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w900, color: textColor)),

                const SizedBox(height: 32),

                // ── Тема ──────────────────────────────────────
                _sectionLabel('Тема', textColor),
                const SizedBox(height: 12),
                _ThemeToggle(themeMode: settings.themeMode, settings: settings),

                const SizedBox(height: 32),

                // ── Акцентный цвет ────────────────────────────
                _sectionLabel('Акцентный цвет', textColor),
                const SizedBox(height: 12),
                ...List.generate(AppColors.accents.length, (i) =>
                    _AccentRow(
                      color: AppColors.accents[i],
                      name: AppColors.accentNames[i],
                      isSelected: settings.accent == AppColors.accents[i],
                      onTap: () {
                        hapticLight();
                        settings.setAccent(AppColors.accents[i]);
                      },
                    )),

                const SizedBox(height: 32),

                // ── Premium ───────────────────────────────────
                _sectionLabel('Premium', textColor),
                const SizedBox(height: 12),
                const PremiumSection(),

                const SizedBox(height: 32),

                // ── Экспорт ───────────────────────────────────
                _sectionLabel('Экспорт и импорт', textColor),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    _actionItem(
                      context: context,
                      icon: Icons.description_outlined,
                      label: 'Экспорт в TXT',
                      sublabel: 'Читаемый дневник',
                      textColor: textColor,
                      onTap: () { hapticLight(); ExportService.exportTxt(context); },
                    ),
                    Divider(height: 1, indent: 56, color: textColor.withOpacity(0.1)),
                    _actionItem(
                      context: context,
                      icon: Icons.table_chart_outlined,
                      label: 'Экспорт в CSV',
                      sublabel: 'Таблица для Excel / Sheets',
                      textColor: textColor,
                      onTap: () { hapticLight(); ExportService.exportCsv(context); },
                    ),
                    Divider(height: 1, indent: 56, color: textColor.withOpacity(0.1)),
                    _actionItem(
                      context: context,
                      icon: Icons.backup_outlined,
                      label: 'Резервная копия JSON',
                      sublabel: 'Полный бэкап всех данных',
                      textColor: textColor,
                      onTap: () { hapticLight(); ExportService.exportJson(context); },
                    ),
                    Divider(height: 1, indent: 56, color: textColor.withOpacity(0.1)),
                    _actionItem(
                      context: context,
                      icon: Icons.restore_outlined,
                      label: 'Импорт из JSON',
                      sublabel: 'Восстановить из бэкапа',
                      textColor: textColor,
                      iconColor: Colors.orange,
                      onTap: () { hapticLight(); ExportService.importJson(context, onImported: onImported); },
                    ),
                  ]),
                ),

                const SizedBox(height: 32),

                // ── Скоро ─────────────────────────────────────
                _sectionLabel('Скоро', textColor),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    _futureItem(Icons.notifications_outlined,
                        'Время уведомлений', textColor),
                    Divider(height: 1, indent: 56,
                        color: textColor.withOpacity(0.1)),
                    _futureItem(Icons.info_outline,
                        'О приложении', textColor),
                  ]),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color textColor) => Text(label,
      style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.5),
          fontWeight: FontWeight.w600, letterSpacing: 1));

  Widget _actionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color textColor,
    required VoidCallback onTap,
    Color? iconColor,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: iconColor ?? textColor.withOpacity(0.7), size: 22),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, color: textColor)),
                Text(sublabel, style: TextStyle(fontSize: 12,
                    color: textColor.withOpacity(0.4))),
              ],
            )),
            Icon(Icons.chevron_right, color: textColor.withOpacity(0.3)),
          ]),
        ),
      );

  Widget _futureItem(IconData icon, String label, Color textColor) => Padding(
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

class _ThemeToggle extends StatelessWidget {
  final ThemeMode themeMode;
  final AppSettings settings;
  const _ThemeToggle({required this.themeMode, required this.settings});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    Widget btn(String label, ThemeMode mode) {
      final isActive = themeMode == mode;
      return Expanded(child: GestureDetector(
        onTap: () { hapticLight(); settings.setTheme(mode); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? settings.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: Text(label,
              style: TextStyle(fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : textColor))),
        ),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        btn('☀️ Светлая',  ThemeMode.light),
        btn('🌙 Тёмная',   ThemeMode.dark),
        btn('⚙️ Авто',     ThemeMode.system),
      ]),
    );
  }
}

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
