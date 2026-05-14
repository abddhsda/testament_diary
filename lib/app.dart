// ════════════════════════════════════════════════════
// app.dart — корень приложения
// Содержит: MindfulDiaryApp (тема + локаль),
//           AppSettings (InheritedWidget — глобальное состояние)
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/colors.dart';
import 'screens/home_screen.dart';

// ─── ROOT WIDGET ──────────────────────────────────────────────
class MindfulDiaryApp extends StatefulWidget {
  const MindfulDiaryApp({super.key});

  @override
  State<MindfulDiaryApp> createState() => _MindfulDiaryAppState();
}

class _MindfulDiaryAppState extends State<MindfulDiaryApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accent = AppColors.accentOrange; // см. constants/colors.dart
  bool _isPremium = false;
  bool _settingsLoaded = false;

  // ─── Загрузка настроек из SharedPreferences ──────────────────
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeIndex') ?? 0; // 0=system,1=light,2=dark
    final isDark = prefs.getBool('isDark') ?? false; // legacy fallback
    final accentIndex = prefs.getInt('accentIndex') ?? 0;
    final isPremium = prefs.getBool('isPremium') ?? false;

    setState(() {
      _themeMode = themeIndex == 1 ? ThemeMode.light
                 : themeIndex == 2 ? ThemeMode.dark
                 : prefs.containsKey('isDark')
                     ? (isDark ? ThemeMode.dark : ThemeMode.light)
                     : ThemeMode.system;
      _accent = AppColors.accents[accentIndex]; // массив из colors.dart
      _isPremium = isPremium;
      _settingsLoaded = true;
    });
  }

  // ─── Сеттеры (вызываются из SettingsScreen через AppSettings) ─
  void _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    final idx = mode == ThemeMode.light ? 1 : mode == ThemeMode.dark ? 2 : 0;
    await prefs.setInt('themeIndex', idx);
  }

  void _setAccent(Color color) async {
    setState(() => _accent = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentIndex', AppColors.accents.indexOf(color));
  }

  void _setIsPremium(bool value) async {
    setState(() => _isPremium = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', value);
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Пока настройки не загружены — пустой экран (без flash)
    if (!_settingsLoaded) {
      return const MaterialApp(home: Scaffold(body: SizedBox()));
    }

    return AppSettings(
      themeMode: _themeMode,
      accent: _accent,
      isPremium: _isPremium,
      setTheme: _setTheme,
      setAccent: _setAccent,
      setIsPremium: _setIsPremium,
      child: MaterialApp(
        title: 'Modo',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: _buildTheme(_accent, Brightness.light),
        darkTheme: _buildTheme(_accent, Brightness.dark),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru')],
        home: const HomeScreen(),
      ),
    );
  }

  // ─── Построение темы ──────────────────────────────────────────
  // accent смешивается с базовым фоном чтобы тема чувствовалась живой
  ThemeData _buildTheme(Color accent, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Фон: тёмный/светлый + лёгкий оттенок акцента
    final bg = isDark
        ? Color.alphaBlend(accent.withOpacity(0.05), AppColors.darkBg)
        : Color.alphaBlend(accent.withOpacity(0.04), AppColors.lightBg);

    // Surface (карточки): чуть насыщеннее фона
    final surfaceColor = isDark
        ? Color.alphaBlend(accent.withOpacity(0.08), AppColors.darkSurface)
        : Color.alphaBlend(accent.withOpacity(0.08), AppColors.lightSurface);

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
      ).copyWith(surface: surfaceColor),
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
    );
  }
}

// ════════════════════════════════════════════════════
// AppSettings — InheritedWidget
// Даёт доступ к теме/акценту/isPremium из любого виджета:
//   final s = AppSettings.of(context);
//   s.accent / s.isPremium / s.setTheme(ThemeMode.dark)
// ════════════════════════════════════════════════════
class AppSettings extends InheritedWidget {
  final ThemeMode themeMode;
  final Color accent;
  final bool isPremium;
  final void Function(ThemeMode) setTheme;
  final void Function(Color) setAccent;
  final void Function(bool) setIsPremium;

  const AppSettings({
    super.key,
    required this.themeMode,
    required this.accent,
    required this.isPremium,
    required this.setTheme,
    required this.setAccent,
    required this.setIsPremium,
    required super.child,
  });

  // Быстрый доступ: AppSettings.of(context).accent
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettings>()!;

  @override
  bool updateShouldNotify(AppSettings old) =>
      themeMode != old.themeMode ||
      accent != old.accent ||
      isPremium != old.isPremium;
}
