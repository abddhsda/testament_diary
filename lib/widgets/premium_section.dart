// ════════════════════════════════════════════════════
// widgets/premium_section.dart — секция Premium
//
// Два состояния:
//   isPremium = true  → зелёная плашка "Premium активен"
//   isPremium = false → форма ввода промокода + кнопка
//
// Supabase API вызов: проверка кода → пометить как использованный
//
// ⚠️  TODO: вынести URL и ключ в отдельный config-файл или .env
//           чтобы не светить их в исходниках
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';

class PremiumSection extends StatefulWidget {
  const PremiumSection({super.key});

  @override
  State<PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends State<PremiumSection> {
  final _codeController = TextEditingController();
  bool _loading = false;

  // ─── Supabase credentials ─────────────────────────────────────
  // TODO: вынести в config/secrets (не хранить в исходниках)
  static const _supabaseUrl =
      'https://vfbjtqjpkjcjceodlzbt.supabase.co/rest/v1/promo_codes';
  static const _apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmYmp0cWpwa2pjamNlb2RsemJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNTg2NjIsImV4cCI6MjA5MzkzNDY2Mn0.pyJs02GZ6joGUzHE4FYD7EAwqlHvuOrEdg_B4ztUeaA';
  static const _headers = {
    'apikey': _apiKey,
    'Authorization': 'Bearer $_apiKey',
  };

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ─── Активация промокода ──────────────────────────────────────
  Future<void> _activate() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _loading = true);
    try {
      // 1. Проверяем код
      final checkResponse = await http.get(
        Uri.parse('$_supabaseUrl?code=eq.$code&is_used=eq.false'),
        headers: _headers,
      );
      final data = jsonDecode(checkResponse.body) as List;

      if (data.isEmpty) {
        _showSnack('Код недействителен или уже использован');
        setState(() => _loading = false);
        return;
      }

      // 2. Помечаем как использованный
      final id = data[0]['id'];
      await http.patch(
        Uri.parse('$_supabaseUrl?id=eq.$id'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'is_used': true,
          'used_at': DateTime.now().toIso8601String(),
        }),
      );

      // 3. Сохраняем Premium локально + обновляем AppSettings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPremium', true);

      if (mounted) {
        AppSettings.of(context).setIsPremium(true);
        _showSnack('🔥 Premium активирован!');
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Ошибка соединения. Проверь интернет.');
        setState(() => _loading = false);
      }
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final accent    = AppSettings.of(context).accent;
    final isPremium = AppSettings.of(context).isPremium;

    // ─── Уже Premium ─────────────────────────────────────────────
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.15), accent.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.4)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.15), shape: BoxShape.circle),
            child: const Text('🔥', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Premium активен',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 2),
              Text('Все записи доступны для редактирования',
                  style: TextStyle(fontSize: 12,
                      color: textColor.withOpacity(0.5))),
            ],
          ),
        ]),
      );
    }

    // ─── Форма ввода промокода ────────────────────────────────────
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.08), accent.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo Premium',
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 2),
                Text('Редактирование любой записи',
                    style: TextStyle(fontSize: 12,
                        color: textColor.withOpacity(0.5))),
              ],
            ),
          ]),

          const SizedBox(height: 16),

          // Что входит
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 14, color: accent),
              const SizedBox(width: 6),
              Text('Редактирование записей старше 3 дней',
                  style: TextStyle(fontSize: 12,
                      color: textColor.withOpacity(0.7))),
            ]),
          ),

          const SizedBox(height: 20),

          // Поле ввода + кнопка
          Row(children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(fontSize: 14, color: textColor,
                    fontWeight: FontWeight.w600, letterSpacing: 1),
                decoration: InputDecoration(
                  hintText: 'MODO-XXXX-XXXX-XXXX',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.25),
                      fontSize: 13, fontWeight: FontWeight.w400,
                      letterSpacing: 0),
                  filled: true,
                  fillColor: textColor.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _activate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Активировать',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
